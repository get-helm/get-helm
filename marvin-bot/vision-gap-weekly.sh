#!/bin/bash
# vision-gap-weekly.sh — Monday 8am weekly decision digest
# Posts open decisions + PM recommendations to #helm-improvements

set -euo pipefail

HELM_IMPROVEMENTS="{{USER_CHANNEL_HELM_IMPROVEMENTS}}"
LOG="$HOME/helm-workspace/logs/vision-gap-weekly.log"
DISCORD_POST="$HOME/marvin-bot/discord-post.sh"
QUEUE_FILE="$HOME/helm-workspace/engineer-queue.md"
DECISIONS_LOG="$HOME/helm-workspace/decisions-log.md"
FRICTION_LOG="$HOME/helm-workspace/friction-log.md"
VISION_DOC="$HOME/helm-workspace/vision-doc.md"

mkdir -p "$(dirname "$LOG")"
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] vision-gap-weekly starting" >> "$LOG"

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

# Find claude binary
CLAUDE_BIN=""
for candidate in "$HOME/.local/bin/claude" /opt/homebrew/bin/claude /usr/local/bin/claude "$HOME/.claude/claude"; do
  [[ -x "$candidate" ]] && { CLAUDE_BIN="$candidate"; break; }
done
if [[ -z "$CLAUDE_BIN" ]]; then
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] ERROR: claude not found" >> "$LOG"
  exit 1
fi

# Collect context
QUEUE_SUMMARY=""
if [ -f "$QUEUE_FILE" ]; then
  QUEUE_SUMMARY=$(python3 - "$QUEUE_FILE" << 'PYEOF'
import re, sys
content = open(sys.argv[1]).read()
blocks = content.split('---')
pending, done_recent = [], []
for block in blocks:
    block = block.strip()
    if not block or block.startswith('<!--'):
        continue
    if 'status: pending' in block or 'status: in_progress' in block:
        lines = block.splitlines()
        id_line = next((l for l in lines if l.startswith('id:')), '')
        desc_line = next((l for l in lines if l.startswith('description:')), '')
        priority_line = next((l for l in lines if l.startswith('priority:')), '')
        pending.append(f"PENDING [{priority_line.replace('priority:','').strip()}] {id_line.replace('id:','').strip()}: {desc_line.replace('description:','').strip()[:80]}")
    elif 'status: done' in block:
        lines = block.splitlines()
        id_line = next((l for l in lines if l.startswith('id:')), '')
        completed_line = next((l for l in lines if l.startswith('completed_at:')), '')
        if id_line:
            done_recent.append(f"DONE {id_line.replace('id:','').strip()} {completed_line.replace('completed_at:','').strip()[:10]}")
out = []
if pending:
    out.append("PENDING ITEMS:\n" + '\n'.join(pending[:8]))
if done_recent:
    out.append("RECENTLY COMPLETED:\n" + '\n'.join(done_recent[-5:]))
print('\n\n'.join(out) if out else 'Queue empty')
PYEOF
  )
fi

RECENT_DECISIONS=""
if [ -f "$DECISIONS_LOG" ]; then
  RECENT_DECISIONS=$(tail -150 "$DECISIONS_LOG" | head -100)
fi

FRICTION_PATTERNS=""
if [ -f "$FRICTION_LOG" ]; then
  FRICTION_PATTERNS=$(python3 - "$FRICTION_LOG" << 'PYEOF'
import sys, re
from collections import Counter
content = open(sys.argv[1]).read()
behaviors = re.findall(r'behavior:\s*([^\n]+)', content)
counts = Counter(behaviors)
if counts:
    lines = [f"- {b}: {c} violations" for b, c in counts.most_common(5)]
    print("Top friction patterns this week:\n" + '\n'.join(lines))
PYEOF
  )
fi

PROMPT_FILE=$(mktemp /tmp/vision-weekly-XXXXXX.txt)
trap 'rm -f "${PROMPT_FILE:-}"' EXIT

cat > "$PROMPT_FILE" << HEADER
WEEKLY DECISION DIGEST

You are PAP's CPO. Today is Monday $(date '+%B %d, %Y'). {{USER_JERRY}} is coming into the week.

Your job: post the weekly decision digest. Not a status report — a decision-forcing document.

Rules:
1. Open decisions: what decisions are pending that {{USER_JERRY}} needs to make? Max 3.
2. Your recommendation for each. Specific. Don't hedge.
3. What the system accomplished last week. 2-3 bullets, concrete.
4. One systemic pattern if friction log shows recurring issues.
5. Mobile-first. Bullets. No walls of text. Under 200 words total.

Output format (exactly):
**Weekly digest — $(date '+%b %d')**

**Open decisions:**
1. [Decision {{USER_JERRY}} needs to make] → My recommendation: [specific]
2. [Decision] → My recommendation: [specific]
[max 3; if none: "No decisions pending — system executing autonomously"]

**Shipped last week:**
• [item]
• [item]

**Pattern:** [one-sentence systemic observation, or omit if nothing meaningful]

Source material:
=== QUEUE STATE ===
$QUEUE_SUMMARY

=== RECENT DECISIONS ===
$RECENT_DECISIONS

=== FRICTION PATTERNS ===
$FRICTION_PATTERNS
HEADER

RESULT=$("$CLAUDE_BIN" -p "$(cat "$PROMPT_FILE")" 2>/dev/null || echo "")

if [ -z "$RESULT" ]; then
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] vision-weekly: claude returned empty" >> "$LOG"
  exit 0
fi

"$DISCORD_POST" "$HELM_IMPROVEMENTS" "$RESULT" || {
  curl -s -X POST \
    -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"content\": $(echo "$RESULT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')}" \
    "https://discord.com/api/v10/channels/${HELM_IMPROVEMENTS}/messages" || true
}

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] vision-weekly posted" >> "$LOG"
