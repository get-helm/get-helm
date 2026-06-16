#!/bin/bash
# synthesizer-nightly.sh — Nightly second-brain synthesis pass
# Runs at 11 PM PT via launchd. Reads second-brain captures, posts synthesis to Discord.
#
# FIX 2026-06-12: prompt was 2MB/524K tokens — exceeded ARG_MAX shell limit causing
# silent empty returns. Fixed by: (1) stdin piping instead of arg expansion,
# (2) limiting to 100 most-recent captures to stay within context window.

set -euo pipefail

SECOND_BRAIN="$HOME/helm-workspace/second-brain"
PAP_IMPROVEMENTS_CHANNEL="{{USER_CHANNEL_HELM_IMPROVEMENTS}}"
LOG="$HOME/helm-workspace/synthesizer.log"
DISCORD_POST="$HOME/marvin-bot/discord-post.sh"
MAX_CAPTURES=100

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Synthesizer nightly starting" >> "$LOG"

# Cooldown gate: skip if a successful run completed within the last 60 min.
# Prevents duplicate API calls when launchd fires multiple times in the same window.
LAST_RUN_LINE=$(grep "Appended to synthesizer-findings.md\|posted: yes" "$LOG" 2>/dev/null | tail -1 || true)
if [ -n "$LAST_RUN_LINE" ]; then
  LAST_TS=$(echo "$LAST_RUN_LINE" | grep -o '^\[20[0-9-]*T[0-9:]*Z\]' | tr -d '[]' || true)
  if [ -n "$LAST_TS" ]; then
    LAST_EPOCH=$(python3 -c "from datetime import datetime, timezone; print(int(datetime.fromisoformat('${LAST_TS}'.replace('Z','+00:00')).timestamp()))" 2>/dev/null || echo 0)
    NOW_EPOCH=$(date -u +%s)
    AGE_MIN=$(( (NOW_EPOCH - LAST_EPOCH) / 60 ))
    if [ "$AGE_MIN" -lt 60 ]; then
      echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Cooldown: last successful run ${AGE_MIN}m ago — skipping duplicate" >> "$LOG"
      exit 0
    fi
  fi
fi

# Load token from env or vault
if [ -f "$HOME/marvin-bot/.env" ]; then
  source "$HOME/marvin-bot/.env"
fi

if [ -z "${DISCORD_BOT_TOKEN:-}" ]; then
  DISCORD_BOT_TOKEN=$(op item get "Marvin Discord Bot" --vault "PAP Vault" --fields password --reveal 2>/dev/null || echo "")
fi

if [ -z "${DISCORD_BOT_TOKEN:-}" ]; then
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] ERROR: no Discord token, aborting" >> "$LOG"
  exit 1
fi

export DISCORD_BOT_TOKEN

# Count total captures
CAPTURE_COUNT=$(find "$SECOND_BRAIN" \( -name "*.md" -o -name "*.txt" \) -type f 2>/dev/null | wc -l | tr -d ' ')

if [ "$CAPTURE_COUNT" -eq 0 ]; then
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] No captures found, skipping" >> "$LOG"
  exit 0
fi

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Running synthesis on $CAPTURE_COUNT total captures (reading $MAX_CAPTURES most recent)" >> "$LOG"

# === GAP 3 PRE-FLIGHT: Determine mention threshold based on recent filtering rate ===
METRICS_FILE="$HOME/helm-workspace/system/synthesizer-metrics.json"
mkdir -p "$(dirname "$METRICS_FILE")"
MENTION_THRESHOLD=3
if [ -f "$METRICS_FILE" ]; then
  MENTION_THRESHOLD=$(python3 << THRESHOLD_CHECK
import json, os, datetime
mf = '$METRICS_FILE'
if not os.path.exists(mf):
    print("3")
    exit(0)
with open(mf) as f: data = json.load(f)
cutoff = (datetime.datetime.utcnow() - datetime.timedelta(days=7)).replace(tzinfo=datetime.timezone.utc)
recent = [e for e in data.get('runs', []) if datetime.datetime.fromisoformat(e['ts'].replace('Z','+00:00')) >= cutoff]
if recent:
    suppressed = sum(1 for r in recent if r.get('posted') == 'NO')
    suppression_rate = (suppressed / len(recent)) * 100 if recent else 0
    print("2" if suppression_rate > 30 else "3")
else:
    print("3")
THRESHOLD_CHECK
  )
  [ "$MENTION_THRESHOLD" = "2" ] && echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Threshold adjusted to 2 (suppression >30% in last 7 days)" >> "$LOG"
fi

# Clean up stale temp files from prior runs that didn't exit cleanly
rm -f /tmp/pap-synth-*

# Build prompt file — limit to MAX_CAPTURES most-recently-modified files
# This keeps the prompt under ~30K tokens (well within context window)
# Note: macOS mktemp requires X's at the END of the template (no suffix after X's)
PROMPT_FILE=""
PROMPT_FILE=$(mktemp /tmp/pap-synth-XXXXXX)
trap 'rm -f "${PROMPT_FILE:-}"' EXIT

cat > "$PROMPT_FILE" << PROMPT_HEADER
SCHEDULED SYNTHESIS RUN

You are PAP's synthesizer. Read the following recent second-brain captures (${MAX_CAPTURES} most recent of ${CAPTURE_COUNT} total) and run the SCHEDULED SYNTHESIS path:

1. Look for: recurring themes across ${MENTION_THRESHOLD}+ captures, ⭐-flagged captures, new patterns not mentioned before.
2. Decision gate: ONLY output a Discord message if you find a genuine pattern across ${MENTION_THRESHOLD}+ captures, a ⭐-flagged item, or something surprising. Most nights, silence is correct.
3. If posting: output exactly this format (nothing else):
   POST_TO_DISCORD: YES
   MESSAGE: [your message here — max 10 bullets, cite capture filenames, Opinionated format]
4. If not posting: output exactly:
   POST_TO_DISCORD: NO
   REASON: [one sentence]

Always produce one of the two formats above. No other output.

Captures (${MAX_CAPTURES} most recent by modification time):
PROMPT_HEADER

# Find + sort by mtime (most recent first), take top MAX_CAPTURES
# || true: prevents set -o pipefail from aborting when head closes stdin early (SIGPIPE to xargs)
find "$SECOND_BRAIN" \( -name "*.md" -o -name "*.txt" \) -type f -print0 \
  | xargs -0 ls -t 2>/dev/null \
  | head -"$MAX_CAPTURES" | while IFS= read -r f; do
  [ -f "$f" ] || continue
  fname=$(basename "$f")
  printf '\n\n=== %s ===\n' "$fname" >> "$PROMPT_FILE"
  head -50 "$f" >> "$PROMPT_FILE"
done || true

# Run synthesis via claude — use stdin piping (not arg expansion) to avoid ARG_MAX limits
CLAUDE_BIN=""
for candidate in "$HOME/.local/bin/claude" /opt/homebrew/bin/claude /usr/local/bin/claude "$HOME/.claude/claude"; do
  [[ -x "$candidate" ]] && { CLAUDE_BIN="$candidate"; break; }
done

if [[ -z "$CLAUDE_BIN" ]]; then
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] ERROR: claude not found" >> "$LOG"
  exit 0
fi

# Run synthesis with retry (up to 3 attempts, 10s backoff) — intermittent empty returns
# observed ~80% of runs on 2026-06-12 before this fix (SYNTH-RETRY-001)
SYNTHESIS=""
MAX_RETRIES=3
for attempt in $(seq 1 $MAX_RETRIES); do
  SYNTHESIS=$(cat "$PROMPT_FILE" | "$CLAUDE_BIN" -p 2>&1 || echo "")
  if [ -n "$SYNTHESIS" ]; then
    [ "$attempt" -gt 1 ] && echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] RETRY $attempt succeeded" >> "$LOG"
    break
  fi
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] RETRY attempt $attempt/$MAX_RETRIES returned empty, waiting 10s" >> "$LOG"
  [ "$attempt" -lt "$MAX_RETRIES" ] && sleep 10
done
# PROMPT_FILE cleanup handled by EXIT trap

if [ -z "$SYNTHESIS" ]; then
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Synthesis returned empty after $MAX_RETRIES attempts, skipping Discord post" >> "$LOG"
  exit 0
fi

# Parse decision gate output using python3 for multi-line MESSAGE support
PARSE_RESULT=$(echo "$SYNTHESIS" | python3 -c "
import sys
text = sys.stdin.read()
lines = text.splitlines()
should_post = 'NO'
message_lines = []
reason = 'none'
in_message = False
for line in lines:
    if line.startswith('POST_TO_DISCORD:'):
        should_post = line.split(':', 1)[1].strip()
    elif line.startswith('MESSAGE:'):
        in_message = True
        rest = line.split(':', 1)[1].strip()
        if rest:
            message_lines.append(rest)
    elif line.startswith('REASON:'):
        in_message = False
        reason = line.split(':', 1)[1].strip()
    elif in_message:
        message_lines.append(line)
print('SHOULD_POST=' + should_post)
print('REASON=' + reason)
print('---MESSAGE_START---')
print('\n'.join(message_lines))
" 2>/dev/null)

SHOULD_POST=$(echo "$PARSE_RESULT" | grep "^SHOULD_POST=" | head -1 | cut -d= -f2)
REASON_LINE=$(echo "$PARSE_RESULT" | grep "^REASON=" | head -1 | cut -d= -f2-)
DISCORD_MSG=$(echo "$PARSE_RESULT" | python3 -c "import sys; lines=sys.stdin.read().splitlines(); start=next((i for i,l in enumerate(lines) if l=='---MESSAGE_START---'), None); print('\n'.join(lines[start+1:]) if start is not None else '')")

if [ "$SHOULD_POST" != "YES" ]; then
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Scheduled run — $CAPTURE_COUNT captures total, $MAX_CAPTURES read, posted: no (gate: ${REASON_LINE:-threshold not met})" >> "$LOG"

  # NEW: Still write findings to file even if Discord gate filtered them
  # PM reads synthesizer-findings.md during sweep — this ensures findings surface even when gate suppresses Discord
  FINDINGS_FILE="$HOME/helm-workspace/synthesizer-findings.md"
  if [ -n "$DISCORD_MSG" ]; then
    {
      printf -- '---\n'
      printf '%s | %s captures (not posted to Discord — threshold not met)\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$CAPTURE_COUNT"
      printf '%s\n' "$DISCORD_MSG"
    } >> "$FINDINGS_FILE"
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Findings written to synthesizer-findings.md (Discord post suppressed by gate)" >> "$LOG"
  fi
  exit 0
fi

if [ -z "$DISCORD_MSG" ]; then
  # Fallback: use raw synthesis output if parser failed to extract MESSAGE block
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Parser failed to extract MESSAGE — falling back to raw (first 3 lines): $(echo "$SYNTHESIS" | head -3 | tr '\n' '|')" >> "$LOG"
  DISCORD_MSG=$(echo "$SYNTHESIS" | grep -v "^POST_TO_DISCORD:" | grep -v "^MESSAGE:" | grep -v "^REASON:" | head -15)
  if [ -z "$DISCORD_MSG" ]; then
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] No fallback content, skipping post" >> "$LOG"
    exit 0
  fi
fi

# Post to #helm-improvements
FULL_MSG="📚 **Nightly synthesis — $(date '+%b %d')** ($CAPTURE_COUNT captures total, $MAX_CAPTURES read)\n\n$DISCORD_MSG"

"$DISCORD_POST" "$PAP_IMPROVEMENTS_CHANNEL" "$FULL_MSG" || {
  curl -s -X POST \
    -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"content\": $(echo "$FULL_MSG" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')}" \
    "https://discord.com/api/v10/channels/${PAP_IMPROVEMENTS_CHANNEL}/messages" || true
}

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Scheduled run — $CAPTURE_COUNT captures total, $MAX_CAPTURES read, posted: yes, Discord message sent" >> "$LOG"

# Append to synthesizer-findings.md for weekly digest consumption
FINDINGS_FILE="$HOME/helm-workspace/synthesizer-findings.md"
{
  printf -- '---\n'
  printf '%s | %s captures\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$CAPTURE_COUNT"
  printf '%s\n' "$DISCORD_MSG"
} >> "$FINDINGS_FILE"
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Appended to synthesizer-findings.md" >> "$LOG"

# === GAP 2 + 3 METRICS LOGGING: Update metrics with this run's result ===
METRICS_FILE="$HOME/helm-workspace/system/synthesizer-metrics.json"
mkdir -p "$(dirname "$METRICS_FILE")"
python3 << METRICS_UPDATE
import json, os, datetime
mf = '$METRICS_FILE'
if not os.path.exists(mf):
    data = {"runs": []}
else:
    with open(mf) as f:
        data = json.load(f)

# Record this run: posted (YES/NO) and timestamp
run = {
    "ts": datetime.datetime.utcnow().isoformat() + "Z",
    "posted": "$SHOULD_POST",
    "threshold": int($MENTION_THRESHOLD)
}
data.setdefault("runs", []).append(run)

# Keep only last 30 runs (7 days at ~4-5 runs/day)
data["runs"] = data["runs"][-30:]

# Calculate 7-day suppression rate
cutoff = (datetime.datetime.utcnow() - datetime.timedelta(days=7)).replace(tzinfo=datetime.timezone.utc)
recent = [r for r in data["runs"] if datetime.datetime.fromisoformat(r['ts'].replace('Z', '+00:00')) >= cutoff]
if recent:
    suppressed = sum(1 for r in recent if r['posted'] == 'NO')
    suppression_rate = (suppressed / len(recent)) * 100
    data["suppression_rate_pct"] = round(suppression_rate, 1)

with open(mf, 'w') as f:
    json.dump(data, f, indent=2)
METRICS_UPDATE

# === GAP 2 FIX: TTL cleanup — archive findings >14 days old ===
FINDINGS_FILE="$HOME/helm-workspace/synthesizer-findings.md"
if [ -f "$FINDINGS_FILE" ]; then
  python3 << 'TTL_CLEANUP'
import os, json, datetime
findings_file = os.path.expanduser("~/helm-workspace/synthesizer-findings.md")
if not os.path.exists(findings_file):
    exit(0)
cutoff = (datetime.datetime.utcnow() - datetime.timedelta(days=14)).replace(tzinfo=datetime.timezone.utc)
with open(findings_file, 'r') as f:
    lines = f.readlines()
output = []
i = 0
while i < len(lines):
    if lines[i].startswith('---'):
        i += 1
        if i < len(lines):
            ts_line = lines[i].strip()
            try:
                ts_str = ts_line.split('|')[0].strip()
                ts = datetime.datetime.fromisoformat(ts_str.replace('Z', '+00:00'))
                if ts >= cutoff:
                    output.append('---\n')
                    output.append(ts_line + '\n')
                    i += 1
                    while i < len(lines) and not lines[i].startswith('---'):
                        output.append(lines[i])
                        i += 1
                else:
                    i += 1
                    while i < len(lines) and not lines[i].startswith('---'):
                        i += 1
            except:
                output.append('---\n')
                output.append(ts_line + '\n')
                i += 1
    else:
        i += 1
with open(findings_file, 'w') as f:
    f.writelines(output)
TTL_CLEANUP
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] TTL cleanup complete — archived findings >14 days old" >> "$LOG"
fi

# Notify VPS watchdog that synthesizer ran successfully
curl -s -o /dev/null -m 5 -X POST "http://{{USER_VPS_TAILSCALE_IP}}:9876/synthesizer" || true
