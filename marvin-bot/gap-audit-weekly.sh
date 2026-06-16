#!/usr/bin/env bash
# gap-audit-weekly.sh — Weekly gap audit: scans the past 7 days of Discord messages
# for work agreed upon but not implemented. Posts to #helm-improvements and pings {{USER_JERRY}}.
# Runs Monday at 9am PT (after vision-gap-weekly digest at 8am).

set -euo pipefail

QUEUE_FILE="$HOME/helm-workspace/engineer-queue.md"
AUDIT_FILE="$HOME/helm-workspace/queue-audit.log"
DECISIONS_LOG="$HOME/helm-workspace/decisions-log.md"
WORK_ITEMS="$HOME/helm-workspace/work-items.json"
EVENT_STREAM="$HOME/helm-workspace/event-stream.jsonl"
LOG="$HOME/marvin-bot/gap-audit-weekly.log"
CLAUDE="$HOME/.local/bin/claude"
HELM_IMPROVEMENTS_CHANNEL="{{USER_CHANNEL_HELM_IMPROVEMENTS}}"
DONE_FLAG="/tmp/pap-gap-audit-weekly-done-$(date +%Y%V)"  # keyed to year+week number
DISCORD_POST="$HOME/marvin-bot/discord-post.sh"
QUEUE_WRITE="$HOME/marvin-bot/queue-write.sh"
PROMPT_FILE="/tmp/pap-gap-audit-weekly-prompt-$(date +%Y%m%d).txt"
OWNER_DISCORD_ID="${HELM_OWNER_DISCORD_ID:-{{USER_ID}}}"

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [gap-audit-weekly] $*" | tee -a "$LOG"
}

# Already ran this week
[[ -f "$DONE_FLAG" ]] && exit 0

# Day guard: Monday only (day 1 in date +%u, or day 2 in date +%w — use %u for Mon=1)
DAY=$(date +%u)
[[ "$DAY" -ne 1 ]] && exit 0

# Hour guard: 9am–11am PT
HOUR=$(date +%H)
[[ "$HOUR" -lt 9 || "$HOUR" -gt 10 ]] && exit 0

log "Weekly gap audit starting (day=$DAY hour=$HOUR)"
touch "$DONE_FLAG"

WEEK_START=$(date -v-7d +%Y-%m-%d 2>/dev/null || date --date='7 days ago' +%Y-%m-%d)
TODAY=$(date +%Y-%m-%d)

bash "$DISCORD_POST" "$HELM_IMPROVEMENTS_CHANNEL" \
  "⏳ Weekly gap audit running — scanning 7 days of messages for anything that slipped through (~8 min)." \
  2>/dev/null || log "Discord post failed (non-fatal)"

# Extract Discord conversation messages from the past 7 days
# Only scan #general and #helm-improvements (and its threads) — exclude workspace/system channels
# Scan ALL files in workspace dirs to catch IDs regardless of which file they're in
WORKSPACE_CHANNEL_IDS=$(grep -rh "" "$HOME/helm-workspace/workspaces/" 2>/dev/null | grep -oE "[0-9]{17,19}" | sort -u | tr '\n' ' ')
DISCORD_MESSAGES=$(python3 - "$EVENT_STREAM" "$WORKSPACE_CHANNEL_IDS" << 'PYEOF'
import json, os, sys, datetime
from datetime import timezone, timedelta

OWNER_ID = os.environ.get('HELM_OWNER_DISCORD_ID', '{{USER_ID}}')
BOT_ID = '1498824219633647789'
cutoff = datetime.datetime.now(timezone.utc) - timedelta(days=7)

# Build exclusion set: workspace channels + all known system/utility channels
excluded_channels = set(sys.argv[2].split()) if len(sys.argv) > 2 else set()
excluded_channels.update({
    '{{USER_CHANNEL_HELM_AUDIT}}',  # helm-audit (read-only)
    '{{USER_CHANNEL_HELM_STATUS}}',  # helm-status
    '1499287733007421611',  # new-workspace / other utility
})
# Never exclude the two target channels even if they appear in workspace files
excluded_channels.discard('1498823989324419094')  # #general
excluded_channels.discard('{{USER_CHANNEL_HELM_IMPROVEMENTS}}')  # #helm-improvements

messages = []
try:
    with open(sys.argv[1]) as f:
        for line in f:
            try:
                e = json.loads(line)
                ts_str = e.get('ts', '')
                if not ts_str:
                    continue
                ts = datetime.datetime.fromisoformat(ts_str.replace('Z', '+00:00'))
                if ts < cutoff:
                    continue
                # Skip workspace and system channels
                channel_id = e.get('channelId', '')
                if channel_id in excluded_channels:
                    continue
                etype = e.get('type')
                if etype not in ('user_message', 'agent_message'):
                    continue
                content = (e.get('content') or '').strip()
                if not content:
                    continue
                author_id = e.get('authorId')
                phase = e.get('agentPhase') or ''
                if author_id == OWNER_ID:
                    author = 'Owner'
                elif author_id in (BOT_ID, 'bot') and phase in ('deliver', 'ack', 'update', 'block'):
                    author = f'Marvin({phase})'
                else:
                    continue
                messages.append({'ts': ts_str[:16], 'author': author, 'content': content[:300]})
            except Exception:
                pass
except Exception as ex:
    print(f"(error reading event stream: {ex})")
    sys.exit(0)

lines = [f"[{m['ts']}] {m['author']}: {m['content']}" for m in messages]
text = '\n'.join(lines)
# Cap at 18000 chars for weekly (larger window, more context)
if len(text) > 18000:
    text = '...(earlier messages truncated)...\n' + text[-18000:]
print(text if text else '(no conversation messages found in past 7 days)')
PYEOF
)

QUEUE_PENDING=$(python3 -c "
import re
with open('$QUEUE_FILE') as f:
    content = f.read()
blocks = re.findall(r'(?s)---\s*\nqueued_at:.*?status:\s*pending.*?---', content)
ids = [re.search(r'id:\s*(\S+)', b).group(1) for b in blocks if re.search(r'id:\s*(\S+)', b)]
print(', '.join(ids) if ids else '(none)')
" 2>/dev/null || echo "(unknown)")

RECENT_DECISIONS=$(tail -300 "$DECISIONS_LOG" 2>/dev/null | head -250 || echo "(none)")

WORK_ITEMS_CONTENT=$(python3 -c "
import json
with open('$WORK_ITEMS') as f:
    items = json.load(f)
all_items = [i for i in items if i.get('status') in ('active','design','concept','done')]
print(json.dumps(all_items, indent=2))
" 2>/dev/null | head -150 || echo "(not readable)")

AUDIT_WEEK=$(grep -E "^$(date +%Y-%m-)" "$AUDIT_FILE" 2>/dev/null | tail -50 || echo "(none)")

# Build workspace name list for false positive detection
WORKSPACE_NAMES=$(ls "$HOME/helm-workspace/workspaces/" 2>/dev/null | tr '\n' ',' | sed 's/,$//')

cat > "$PROMPT_FILE" << PROMPT_EOF
You are the PAP weekly gap-audit agent. Your job has THREE parts:

PART 1 — WORK GAPS: Find anything promised, approved, or identified as needed in the past 7 days that is NOT yet queued or done.
PART 2 — OPEN QUESTIONS: Surface unresolved questions or decisions that need attention.
PART 3 — WEEKLY SUMMARY: Post a concise summary to {{USER_JERRY}} and the PM.

Date range: $WEEK_START to $TODAY (past 7 days)

---

## PART 1: WORK GAP DETECTION — THREE-TIER CONFIDENCE SYSTEM

Every potential gap must be assigned a confidence tier BEFORE deciding what to do:

### TIER: QUEUE (auto-queue — high confidence)
All of the following must be true:
- The commitment was explicit: "yes do it", "implement X", "build Y", "go ahead"
- The topic is HELM system infrastructure (bot.js, protocols, agents, scripts, audit, PM behaviors) — NOT workspace features
- No workspace name appears in the item (workspace list: $WORKSPACE_NAMES)
- {{USER_JERRY}} did NOT later say it was done, handled, or a false positive
- No DELIVER or "verified" message shows the work was completed

### TIER: FLAG_FOR_PM (escalate to PM — medium confidence)
Flag for PM review when ANY of these are true:
- The item mentions a workspace by name: $WORKSPACE_NAMES
- The item involves creative assets (logos, images, mockups, designs) → workspace-specific
- The item involves external service pushes (GitHub, Cloudflare, DNS, marketing) → workspace may own this
- The item is a debugging/investigation task ("root cause", "investigate", "diagnose") without clear scope
- The commitment was ambiguous ("that would be nice", "eventually", "might be good")
- {{USER_JERRY}} later said "done", "handled", "addressed", "false positive", or "remove from queue" near this topic
- Resolution may have happened in a workspace channel (this audit cannot see workspace channels)
- Item was discussed more than 5 days ago and never mentioned again → likely silently resolved or deferred

### TIER: SKIP (do nothing)
Skip if:
- {{USER_JERRY}} explicitly confirmed this was done or cancelled
- A Marvin DELIVER with disk evidence confirmed it was built
- The item is workspace-specific AND workspace agents handle their own queue
- The item is purely conceptual with no concrete deliverable stated

---

### Instructions for PART 1

1. Classify each candidate gap into QUEUE / FLAG_FOR_PM / SKIP
2. QUEUE items (max 8): call queue-write.sh immediately:
   bash $QUEUE_WRITE "WEEKLY-GAP-[SHORT-ID]-$(date +%Y%m%d)" "description" <est_mins> --priority MED
3. FLAG_FOR_PM items: collect them — post as PM flag (Step A of Part 3)
4. SKIP: do nothing

---

## PART 2: OPEN QUESTION DETECTION

Scan for unresolved questions:
- "Should we X or Y?" threads that never concluded
- VERIFICATION_REQUIRED items never followed up on
- Decisions deferred but never revisited

Collect these alongside FLAG_FOR_PM items for the PM flag message.

---

## PART 3: WEEKLY SUMMARY REPORT

Post in this order:

**Step A — PM flag** (if any FLAG_FOR_PM items OR open questions exist):
bash $DISCORD_POST $HELM_IMPROVEMENTS_CHANNEL "⚠️ Weekly audit flagged [N] item(s) for PM review — uncertain whether these are real gaps or were handled in workspace channels. PM should verify before queuing.\n\nUncertain items:\n• [item — one line]\n\nOpen questions needing resolution:\n• [question]\n[OR: • No open questions]"

**Step B — {{USER_JERRY}} summary** (always post ONE after Step A):
bash $DISCORD_POST $HELM_IMPROVEMENTS_CHANNEL "<@$OWNER_DISCORD_ID> Weekly gap audit complete ($WEEK_START → $TODAY):\n\n**Auto-queued for engineer:** [N] items\n[• gap — one line each]\n[OR: • None — everything verified done]\n\n**Flagged for PM review (uncertain):** [M] items\n[OR: • None]\n\n**Coverage:** Scanned [X] {{USER_JERRY}} messages, [Y] Marvin DELIVER messages this week."

If both lists empty:
bash $DISCORD_POST $HELM_IMPROVEMENTS_CHANNEL "✅ Weekly audit clean — everything from this week is verified done or in queue. <@$OWNER_DISCORD_ID>"

---

## Inputs

### Discord conversation messages (past 7 days) — PRIMARY SOURCE
$DISCORD_MESSAGES

### Currently pending engineer queue items (IDs only — do NOT re-queue these)
$QUEUE_PENDING

### Recent decisions-log entries
$RECENT_DECISIONS

### All work items (active/design/concept/done)
$WORK_ITEMS_CONTENT

### This week's queue-audit entries
$AUDIT_WEEK

### Known workspace names (items mentioning these → FLAG_FOR_PM, not QUEUE)
$WORKSPACE_NAMES

---

CRITICAL RULES:
- Apply the tier system strictly. When in doubt → FLAG_FOR_PM, not QUEUE.
- Never queue workspace-specific work. Workspace agents own their queue.
- Always post the Part 3 summary so {{USER_JERRY}} receives the report even if everything is clean.
- A conversation discussing a topic near a DELIVER that resolved it = resolved, not a gap.
PROMPT_EOF

log "Spawning Claude for weekly gap analysis"
TS_START=$(date -u +%Y-%m-%dT%H:%M:%SZ)

HOME="$HOME" \
PATH="/opt/homebrew/bin:$HOME/.local/bin:$HOME/.bun/bin:/usr/local/bin:/usr/bin:/bin" \
  "$CLAUDE" --dangerously-skip-permissions -p "$(cat "$PROMPT_FILE")" >> "$LOG" 2>&1

EXIT_CODE=$?
TS_END=$(date -u +%Y-%m-%dT%H:%M:%SZ)
log "Claude exited code=$EXIT_CODE at $TS_END"

echo "$TS_END | GAP_AUDIT_WEEKLY_RUN | exit_code=$EXIT_CODE" >> "$AUDIT_FILE"

if [[ "$EXIT_CODE" -ne 0 ]]; then
  bash "$DISCORD_POST" "$HELM_IMPROVEMENTS_CHANNEL" \
    "⚠️ Weekly gap audit exited with error (code=$EXIT_CODE). Check gap-audit-weekly.log. <@$OWNER_DISCORD_ID>" \
    2>/dev/null || true
fi

rm -f "$PROMPT_FILE"
log "Weekly gap audit complete"
