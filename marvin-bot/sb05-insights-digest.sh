#!/bin/bash
# sb05-insights-digest.sh — SB-05: Weekly second brain insights digest
# Runs Monday 2:30 AM PT via launchd (after nightly restart at 2am).
# Reads synthesizer-findings.md + runs qmd queries → posts ≤5 insights to pap-improvements.

set -euo pipefail

LOG="$HOME/helm-workspace/synthesizer.log"
PAP_IMPROVEMENTS_CHANNEL="{{USER_CHANNEL_HELM_IMPROVEMENTS}}"
DISCORD_POST="$HOME/marvin-bot/discord-post.sh"
FINDINGS="$HOME/helm-workspace/synthesizer-findings.md"
PM_SCRATCH="$HOME/helm-workspace/pm-scratch.md"
QMD_QUERY="$HOME/marvin-bot/qmd-query.sh"

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] SB-05 insights digest starting" >> "$LOG"

# Load env
if [ -f "$HOME/marvin-bot/.env" ]; then
  source "$HOME/marvin-bot/.env"
fi

# Skip if already ran today (or in last 6 days)
LAST_DATE=$(grep 'last_sb05_digest_date:' "$PM_SCRATCH" 2>/dev/null | tail -1 | sed 's/.*last_sb05_digest_date: //' || true)
TODAY=$(date +%Y-%m-%d)
if [ -n "$LAST_DATE" ] && [ "$LAST_DATE" = "$TODAY" ]; then
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] SB-05 already ran today ($LAST_DATE) — skipping" >> "$LOG"
  exit 0
fi

# Build insights from two sources:
# 1. Recent synthesizer findings (last 7 days)
# 2. qmd queries on recurring themes

INSIGHTS=""
FINDING_COUNT=0

# --- Source 1: synthesizer-findings.md ---
if [ -f "$FINDINGS" ] && [ -s "$FINDINGS" ]; then
  # Extract last 7 days of findings
  CUTOFF=$(date -u -v-7d +%Y-%m-%dT 2>/dev/null || date -u --date='7 days ago' +%Y-%m-%dT 2>/dev/null || echo "2000-01-01T")
  RECENT_FINDINGS=$(python3 - "$FINDINGS" "$CUTOFF" << 'PYEOF'
import sys, re

findings_file = sys.argv[1]
cutoff = sys.argv[2]

with open(findings_file) as f:
    content = f.read()

# Check if file has a timestamp in range (file may start with ---)
# The file format: starts with ---, then timestamp line, then bullet points
ts_match = re.search(r'(\d{4}-\d{2}-\d{2}T\d{2}:\d{2})', content)
if not ts_match or ts_match.group(1) < cutoff:
    sys.exit(0)

# Extract bullet lines (🔴/🟡 prefix) — these are the actual insights
bullets = [l.strip() for l in content.splitlines() if l.strip().startswith(('🔴', '🟡', '🟢'))]

# Return up to 3 bullets, each truncated to 280 chars
output = [b[:280] for b in bullets[:3]]
print('\n'.join(output))
PYEOF
)

  if [ -n "$RECENT_FINDINGS" ]; then
    FINDING_COUNT=$(echo "$RECENT_FINDINGS" | grep -c '.' || true)
    INSIGHTS="${RECENT_FINDINGS}"
  fi
fi

# --- Source 2: qmd queries ---
QMD_INSIGHTS=""
if [ -x "$QMD_QUERY" ]; then
  # Query for recent patterns and key topics
  for QUERY in "PAP automation patterns this week" "recurring friction or errors" "goals decisions plans"; do
    RESULT=$("$QMD_QUERY" "$QUERY" 3 --min-relevance 0.3 2>/dev/null || echo '[]')
    # Extract top hit summary
    SUMMARY=$(echo "$RESULT" | python3 -c "
import json, sys
try:
    items = json.load(sys.stdin)
    if items:
        top = items[0]
        print(f\"{top.get('title','')}: {top.get('summary','')[:150]}\")
except:
    pass
" 2>/dev/null || true)
    if [ -n "$SUMMARY" ]; then
      QMD_INSIGHTS="${QMD_INSIGHTS}\n• From second brain: ${SUMMARY}"
    fi
  done
fi

# Combine and format final message
if [ -z "$INSIGHTS" ] && [ -z "$QMD_INSIGHTS" ]; then
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] SB-05 — no insights found (synthesizer-findings.md empty/missing, qmd returned nothing)" >> "$LOG"
  # Still update tracking date so we don't spam on empty weeks
  python3 - "$PM_SCRATCH" "$TODAY" << 'PYEOF'
import sys, re
scratch = sys.argv[1]
today = sys.argv[2]
try:
    with open(scratch) as f:
        content = f.read()
    if 'last_sb05_digest_date:' in content:
        content = re.sub(r'- last_sb05_digest_date: \S+', f'- last_sb05_digest_date: {today}', content)
    else:
        content += f'\n- last_sb05_digest_date: {today}'
    with open(scratch, 'w') as f:
        f.write(content)
except Exception as e:
    print(f'Warning: could not update pm-scratch.md: {e}', file=sys.stderr)
PYEOF
  exit 0
fi

# Build bullet list (max 5 bullets total)
ALL_BULLETS=""
if [ -n "$INSIGHTS" ]; then
  # Convert synthesizer findings to bullets
  SYNTH_BULLETS=$(echo "$INSIGHTS" | python3 - << 'PYEOF'
import sys
lines = [l.strip() for l in sys.stdin.read().splitlines() if l.strip()]
# Take up to 3 lines as bullets
bullets = []
for line in lines[:3]:
    if not line.startswith('•') and not line.startswith('-'):
        line = '• ' + line
    bullets.append(line[:200])
print('\n'.join(bullets))
PYEOF
)
  ALL_BULLETS="${SYNTH_BULLETS}"
fi

if [ -n "$QMD_INSIGHTS" ]; then
  # Add up to 2 qmd bullets
  QMD_BULLETS=$(printf '%b' "$QMD_INSIGHTS" | head -2)
  ALL_BULLETS="${ALL_BULLETS}\n${QMD_BULLETS}"
fi

# Trim to 5 bullets
FINAL_BULLETS=$(printf '%b' "$ALL_BULLETS" | grep -v '^$' | head -5)

WEEK=$(date '+%b %d')
MSG="📚 **Weekly second brain digest — ${WEEK}**

${FINAL_BULLETS}

_From synthesizer findings + second brain search_"

"$DISCORD_POST" "$PAP_IMPROVEMENTS_CHANNEL" "$MSG" || {
  curl -s -X POST \
    -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"content\": $(echo "$MSG" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')}" \
    "https://discord.com/api/v10/channels/${PAP_IMPROVEMENTS_CHANNEL}/messages" || true
}

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] SB-05 digest posted — ${FINDING_COUNT} synthesizer findings, qmd queries run" >> "$LOG"

# Update pm-scratch.md with last run date
python3 - "$PM_SCRATCH" "$TODAY" << 'PYEOF'
import sys, re
scratch = sys.argv[1]
today = sys.argv[2]
try:
    with open(scratch) as f:
        content = f.read()
    if 'last_sb05_digest_date:' in content:
        content = re.sub(r'- last_sb05_digest_date: \S+', f'- last_sb05_digest_date: {today}', content)
    else:
        content += f'\n- last_sb05_digest_date: {today}'
    with open(scratch, 'w') as f:
        f.write(content)
except Exception as e:
    print(f'Warning: could not update pm-scratch.md: {e}', file=sys.stderr)
PYEOF
