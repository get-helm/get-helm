#!/bin/bash
# vision-gap-daily.sh — Daily 8am vision gap post
# Reads vision-doc.md + engineer-queue.md + friction-log.md
# Posts "here's the gap today" to #helm-improvements without {{USER_JERRY}} asking

set -euo pipefail

HELM_IMPROVEMENTS="{{USER_CHANNEL_HELM_IMPROVEMENTS}}"
LOG="$HOME/helm-workspace/logs/vision-gap-daily.log"
DISCORD_POST="$HOME/marvin-bot/discord-post.sh"
VISION_DOC="$HOME/helm-workspace/vision-doc.md"
QUEUE_FILE="$HOME/helm-workspace/engineer-queue.md"
FRICTION_LOG="$HOME/helm-workspace/friction-log.md"

mkdir -p "$(dirname "$LOG")"
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] vision-gap-daily starting" >> "$LOG"

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
VISION_CONTENT=""
[ -f "$VISION_DOC" ] && VISION_CONTENT=$(cat "$VISION_DOC" | head -200)

QUEUE_PENDING=""
if [ -f "$QUEUE_FILE" ]; then
  QUEUE_PENDING=$(python3 - "$QUEUE_FILE" << 'PYEOF'
import re, sys
content = open(sys.argv[1]).read()
blocks = content.split('---')
pending = []
for block in blocks:
    block = block.strip()
    if not block or block.startswith('<!--'):
        continue
    if 'status: pending' in block or 'status: in_progress' in block:
        lines = block.splitlines()
        id_line = next((l for l in lines if l.startswith('id:')), '')
        desc_line = next((l for l in lines if l.startswith('description:')), '')
        if id_line:
            pending.append(f"- {id_line.replace('id:','').strip()}: {desc_line.replace('description:','').strip()[:80]}")
print('\n'.join(pending[:10]) if pending else 'None')
PYEOF
  )
fi

FRICTION_SUMMARY=""
if [ -f "$FRICTION_LOG" ]; then
  # Get last 3 days of friction entries
  FRICTION_SUMMARY=$(tail -100 "$FRICTION_LOG" | grep -E "^\[|behavior:|violation:" | head -20 || echo "")
fi

PROMPT_FILE=$(mktemp /tmp/vision-gap-XXXXXX.txt)
trap 'rm -f "${PROMPT_FILE:-}"' EXIT

cat > "$PROMPT_FILE" << HEADER
DAILY VISION GAP ANALYSIS

You are PAP's proactive monitor. Today's date: $(date '+%A, %B %d %Y').

Your job: answer "what's the gap between current PAP state and the vision?" — so {{USER_JERRY}} doesn't have to ask.

Rules:
1. Lead with the most critical gap (not necessarily the biggest, but the one that blocks the most).
2. Max 3 gaps. Each gap: one line, concrete, specific.
3. For each gap: one concrete next action (what specifically should happen next).
4. If queue already covers a gap, say so (don't re-raise what's already being fixed).
5. Mobile-readable. Bullets only. No walls of text.

Output format (exactly):
**Vision gap — $(date '+%b %d')**
🔴 [Most critical gap: specific description] → [next action]
🟡 [Second gap] → [next action]
🟢 [Third gap or "No third gap — system tracking well on this front"]

If no meaningful gaps: output exactly:
NO_GAP
REASON: [one sentence]

Source material:
=== VISION (excerpt) ===
$VISION_CONTENT

=== PENDING ENGINEER QUEUE ===
$QUEUE_PENDING

=== RECENT FRICTION LOG ===
$FRICTION_SUMMARY
HEADER

RESULT=$("$CLAUDE_BIN" -p "$(cat "$PROMPT_FILE")" 2>/dev/null || echo "")

if [ -z "$RESULT" ]; then
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] vision-gap: claude returned empty" >> "$LOG"
  exit 0
fi

if echo "$RESULT" | grep -q "^NO_GAP"; then
  REASON=$(echo "$RESULT" | grep "^REASON:" | cut -d: -f2-)
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] vision-gap: no gap today —${REASON}" >> "$LOG"
  exit 0
fi

"$DISCORD_POST" "$HELM_IMPROVEMENTS" "$RESULT" || {
  curl -s -X POST \
    -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"content\": $(echo "$RESULT" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')}" \
    "https://discord.com/api/v10/channels/${HELM_IMPROVEMENTS}/messages" || true
}

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] vision-gap posted" >> "$LOG"
