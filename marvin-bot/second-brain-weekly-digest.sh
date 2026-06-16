#!/bin/bash
# second-brain-weekly-digest.sh — Weekly second brain insights digest
# Runs Monday 2am PT via launchd. Reads synthesizer-findings.md + QMD queries,
# synthesizes 3-5 key patterns, posts to #pap-improvements.

set -euo pipefail

PAP_IMPROVEMENTS_CHANNEL="{{USER_CHANNEL_HELM_IMPROVEMENTS}}"
LOG="$HOME/helm-workspace/synthesizer.log"
DISCORD_POST="$HOME/marvin-bot/discord-post.sh"
FINDINGS_FILE="$HOME/helm-workspace/synthesizer-findings.md"
QMD_QUERY="$HOME/marvin-bot/qmd-query.sh"

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Weekly digest starting" >> "$LOG"

# Load token
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

# Collect synthesizer findings from the past 7 days
FINDINGS_SECTION=""
if [ -f "$FINDINGS_FILE" ]; then
  CUTOFF=$(date -u -v-7d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "7 days ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")
  if [ -n "$CUTOFF" ]; then
    FINDINGS_SECTION=$(python3 - "$FINDINGS_FILE" "$CUTOFF" << 'PYEOF'
import sys, re
findings_file = sys.argv[1]
cutoff = sys.argv[2]
with open(findings_file, 'r') as f:
    raw = f.read()
blocks = raw.split('---')
recent = []
for block in blocks:
    block = block.strip()
    if not block:
        continue
    # First line: timestamp | N captures
    first_line = block.splitlines()[0] if block.splitlines() else ''
    ts_match = re.match(r'^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z)', first_line)
    if ts_match and ts_match.group(1) >= cutoff:
        recent.append(block)
if recent:
    print('\n\n'.join(recent))
PYEOF
  )
  fi
fi

# QMD queries for additional context
QMD_RESULTS=""
if [ -x "$QMD_QUERY" ]; then
  R1=$("$QMD_QUERY" "PAP recurring decisions patterns last week" 5 2>/dev/null || echo "[]")
  R2=$("$QMD_QUERY" "active workspace progress blockers" 3 2>/dev/null || echo "[]")
  R3=$("$QMD_QUERY" "user preferences feedback changes" 3 2>/dev/null || echo "[]")
  QMD_RESULTS=$(python3 - "$R1" "$R2" "$R3" << 'PYEOF'
import sys, json
raw1, raw2, raw3 = sys.argv[1], sys.argv[2], sys.argv[3]
results = []
for raw in [raw1, raw2, raw3]:
    try:
        items = json.loads(raw)
        for item in items:
            if float(item.get('relevance', 0)) >= 0.6:
                results.append(f"[{item.get('date','')[:10]}] {item.get('title','untitled')}: {item.get('summary','')[:200]}")
    except Exception:
        pass
if results:
    print('\n'.join(results[:8]))
PYEOF
  )
fi

# Bail if nothing to synthesize
if [ -z "$FINDINGS_SECTION" ] && [ -z "$QMD_RESULTS" ]; then
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] No findings or QMD results for this week — skipping digest" >> "$LOG"
  exit 0
fi

# Find claude binary
CLAUDE_BIN=""
for candidate in "$HOME/.local/bin/claude" /opt/homebrew/bin/claude /usr/local/bin/claude "$HOME/.claude/claude"; do
  [[ -x "$candidate" ]] && { CLAUDE_BIN="$candidate"; break; }
done
if [[ -z "$CLAUDE_BIN" ]]; then
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] ERROR: claude not found" >> "$LOG"
  exit 0
fi

# Build prompt
PROMPT_FILE=$(mktemp /tmp/pap-weekly-XXXXXX.txt)
trap 'rm -f "${PROMPT_FILE:-}"' EXIT

cat > "$PROMPT_FILE" << 'HEADER'
WEEKLY SECOND BRAIN DIGEST

You are PAP's weekly synthesizer. Produce a Monday morning digest for {{USER_JERRY}} — 3-5 key insights
from this week's second-brain captures and QMD patterns. Rules:
1. Be concrete and specific. "Japan planning has come up 4 times" beats "Japan planning is recurring."
2. Prioritize actionable patterns. What should {{USER_JERRY}} do or decide?
3. Mobile-readable — bullets only, max 10 words per bullet, no walls of text.
4. Only include real patterns — no padding or generic observations.

Output format (exactly):
DIGEST: YES
INSIGHTS:
• [insight 1]
• [insight 2]
• [insight 3]
[optional 4th and 5th]

If nothing worth surfacing: output exactly:
DIGEST: NO
REASON: [one sentence]

Source material follows.
HEADER

if [ -n "$FINDINGS_SECTION" ]; then
  printf '\n=== NIGHTLY SYNTHESIS FINDINGS (LAST 7 DAYS) ===\n' >> "$PROMPT_FILE"
  printf '%s\n' "$FINDINGS_SECTION" >> "$PROMPT_FILE"
fi
if [ -n "$QMD_RESULTS" ]; then
  printf '\n=== QMD SECOND BRAIN QUERIES ===\n' >> "$PROMPT_FILE"
  printf '%s\n' "$QMD_RESULTS" >> "$PROMPT_FILE"
fi

SYNTHESIS=$(timeout 120 "$CLAUDE_BIN" -p "$(cat "$PROMPT_FILE")" 2>/dev/null || echo "")

if [ -z "$SYNTHESIS" ]; then
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Weekly digest: synthesis returned empty" >> "$LOG"
  exit 0
fi

# Parse output
SHOULD_POST=$(echo "$SYNTHESIS" | grep "^DIGEST:" | head -1 | cut -d: -f2 | tr -d ' ')
INSIGHTS=$(echo "$SYNTHESIS" | python3 -c "
import sys
lines = sys.stdin.read().splitlines()
in_insights = False
out = []
for line in lines:
    if line.strip() == 'INSIGHTS:':
        in_insights = True
        continue
    if line.startswith('DIGEST:') or line.startswith('REASON:'):
        in_insights = False
        continue
    if in_insights and line.strip():
        out.append(line.strip())
print('\n'.join(out))
" 2>/dev/null)

if [ "$SHOULD_POST" != "YES" ] || [ -z "$INSIGHTS" ]; then
  REASON=$(echo "$SYNTHESIS" | grep "^REASON:" | head -1 | cut -d: -f2-)
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Weekly digest: no insights to post — ${REASON:-empty}" >> "$LOG"
  exit 0
fi

WEEK=$(date '+%b %d')
FULL_MSG="🧠 **Weekly second brain digest — ${WEEK}**\n\n${INSIGHTS}"

"$DISCORD_POST" "$PAP_IMPROVEMENTS_CHANNEL" "$FULL_MSG" || {
  curl -s -X POST \
    -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"content\": $(echo "$FULL_MSG" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')}" \
    "https://discord.com/api/v10/channels/${PAP_IMPROVEMENTS_CHANNEL}/messages" || true
}

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Weekly digest posted to #pap-improvements" >> "$LOG"
