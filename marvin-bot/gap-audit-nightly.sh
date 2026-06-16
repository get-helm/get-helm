#!/usr/bin/env bash
# gap-audit-nightly.sh — Nightly gap audit: finds commitments made today but not yet queued or done.
# Runs BEFORE engineer window (2am PT). Time guard: 11pm–1am PT.
# Spawns Claude to cross-reference Discord messages + decisions-log.md with queue-audit.log.
# Also flags open questions/uncertainties for PM review.

set -euo pipefail

QUEUE_FILE="/Users/{{USER_HOME}}/helm-workspace/engineer-queue.md"
AUDIT_FILE="/Users/{{USER_HOME}}/helm-workspace/queue-audit.log"
DECISIONS_LOG="/Users/{{USER_HOME}}/helm-workspace/decisions-log.md"
WORK_ITEMS="/Users/{{USER_HOME}}/helm-workspace/work-items.json"
EVENT_STREAM="/Users/{{USER_HOME}}/helm-workspace/event-stream.jsonl"
LOG="/Users/{{USER_HOME}}/marvin-bot/gap-audit-nightly.log"
CLAUDE="/Users/{{USER_HOME}}/.local/bin/claude"
WORKDIR="/Users/{{USER_HOME}}/helm-workspace"
HELM_IMPROVEMENTS_CHANNEL="{{USER_CHANNEL_HELM_IMPROVEMENTS}}"
DONE_FLAG="/tmp/pap-gap-audit-done-$(date +%Y%m%d)"
DISCORD_POST="/Users/{{USER_HOME}}/marvin-bot/discord-post.sh"
QUEUE_WRITE="/Users/{{USER_HOME}}/marvin-bot/queue-write.sh"
PROMPT_FILE="/tmp/pap-gap-audit-prompt-$(date +%Y%m%d).txt"

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [gap-audit] $*" | tee -a "$LOG"
}

# Already ran tonight
[[ -f "$DONE_FLAG" ]] && exit 0

# Time guard: 11pm–1am PT (hours 23 and 0)
HOUR=$(date +%H)
[[ "$HOUR" -ne 23 && "$HOUR" -ne 0 ]] && exit 0

log "Gap audit starting (hour=$HOUR)"
touch "$DONE_FLAG"

TODAY=$(date +%Y-%m-%d)
DECISIONS_TODAY=$(grep -c "^## $TODAY\|^## \[$TODAY" "$DECISIONS_LOG" 2>/dev/null || echo "0")
AUDIT_TODAY=$(grep -c "^$TODAY\|^$TODAY" "$AUDIT_FILE" 2>/dev/null || echo "0")

log "Found $DECISIONS_TODAY decision entries and $AUDIT_TODAY audit entries for $TODAY"

# Gap audit runs silently — no "starting" post to helm-improvements. Results only if actionable.

# Extract Discord conversation messages from the past 24 hours
# Only scan #general and #helm-improvements (and its threads) — exclude workspace/system channels
# Scan ALL files in workspace dirs to catch IDs regardless of which file they're in
WORKSPACE_CHANNEL_IDS=$(grep -rh "" /Users/{{USER_HOME}}/helm-workspace/workspaces/ 2>/dev/null | grep -oE "[0-9]{17,19}" | sort -u | tr '\n' ' ')
DISCORD_MESSAGES=$(python3 - "$EVENT_STREAM" "$WORKSPACE_CHANNEL_IDS" << 'PYEOF'
import json, sys, datetime, subprocess
from datetime import timezone, timedelta

OWNER_ID = os.environ.get('HELM_OWNER_DISCORD_ID', '{{USER_ID}}')
BOT_ID = '1498824219633647789'
cutoff = datetime.datetime.now(timezone.utc) - timedelta(hours=24)

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
                    author = '{{USER_JERRY}}'
                elif author_id in (BOT_ID, 'bot') and phase in ('deliver', 'ack', 'update', 'block'):
                    author = f'Marvin({phase})'
                else:
                    continue
                messages.append({'ts': ts_str[:16], 'author': author, 'content': content[:400]})
            except Exception:
                pass
except Exception as ex:
    print(f"(error reading event stream: {ex})")
    sys.exit(0)

lines = [f"[{m['ts']}] {m['author']}: {m['content']}" for m in messages]
text = '\n'.join(lines)
# Cap at 10000 chars — take the most recent portion
if len(text) > 10000:
    text = '...(earlier messages truncated)...\n' + text[-10000:]
print(text if text else '(no conversation messages found in past 24 hours)')
PYEOF
)

DECISIONS_CONTENT=$(grep -A 20 "^## $TODAY\|^## \[$TODAY" "$DECISIONS_LOG" 2>/dev/null | head -200 || echo "(none)")
QUEUE_PENDING=$(python3 -c "
import re
with open('$QUEUE_FILE') as f:
    content = f.read()
blocks = re.findall(r'(?s)---\s*\nqueued_at:.*?status:\s*pending.*?---', content)
ids = [re.search(r'id:\s*(\S+)', b).group(1) for b in blocks if re.search(r'id:\s*(\S+)', b)]
print(', '.join(ids) if ids else '(none)')
" 2>/dev/null || echo "(unknown)")
AUDIT_TODAY_ENTRIES=$(grep "^$(date +%Y-%m-%d)" "$AUDIT_FILE" 2>/dev/null | tail -20 || echo "(none)")
WORK_ITEMS_CONTENT=$(python3 -c "
import json
with open('$WORK_ITEMS') as f:
    items = json.load(f)
pending = [i for i in items if i.get('status') in ('active','design','concept')]
print(json.dumps(pending, indent=2))
" 2>/dev/null | head -100 || echo "(not readable)")

# Build workspace name list for false positive detection
WORKSPACE_NAMES=$(ls /Users/{{USER_HOME}}/helm-workspace/workspaces/ 2>/dev/null | tr '\n' ',' | sed 's/,$//')

cat > "$PROMPT_FILE" << PROMPT_EOF
You are the PAP gap-audit agent. Your job has THREE parts:

PART 1 — WORK GAPS: Find anything promised, approved, or identified as needed today — but NOT yet queued or done.
PART 2 — OPEN QUESTIONS: Flag unresolved questions that need PM or user attention.
PART 3 — SUMMARY: Post one summary Discord message.

Today's date: $TODAY

---

## PART 1: WORK GAP DETECTION — THREE-TIER CONFIDENCE SYSTEM

Every potential gap must be assigned a confidence tier BEFORE deciding what to do:

### TIER: QUEUE (auto-queue — high confidence)
All of the following must be true:
- The commitment was explicit: "yes do it", "implement X", "build Y", "go ahead"
- The topic is HELM system infrastructure (bot.js, protocols, agents, scripts, audit, PM behaviors) — NOT workspace features
- No workspace name appears in the item (workspace list: $WORKSPACE_NAMES)
- {{USER_JERRY}} did NOT later say it was done, handled, or a false positive
- No DELIVER or "verified" message in the conversation shows the work was completed

### TIER: FLAG_FOR_PM (escalate — medium confidence)
Flag for PM review when ANY of these are true:
- The item mentions a workspace by name: $WORKSPACE_NAMES
- The item involves creative assets (logos, images, mockups) → likely workspace-specific
- The item involves external pushes (GitHub, Cloudflare, DNS, marketing) → workspace may own this
- The item is a debugging investigation ("root cause undiagnosed", "investigate X") with no clear scope
- The commitment was ambiguous ("that would be nice", "eventually", "when you get a chance")
- {{USER_JERRY}} later said "it's done", "handled", "addressed", or "false positive" near this topic
- The resolution may have happened in a workspace channel (which this audit doesn't scan)

### TIER: SKIP (do nothing — low confidence)
Skip if:
- {{USER_JERRY}} explicitly said this was done, cancelled, or a false positive
- A Marvin DELIVER with "Verified:" or disk evidence confirmed it was built
- The item is workspace-specific AND workspace agents handle their own queue
- The item is purely conceptual/exploratory with no concrete deliverable stated

---

### Instructions for PART 1

1. For each candidate gap, determine tier (QUEUE / FLAG_FOR_PM / SKIP)
2. QUEUE items (max 5): call queue-write.sh immediately:
   bash $QUEUE_WRITE "GAP-AUDIT-[SHORT-ID]-$(date +%Y%m%d)" "description" <est_mins> --priority MED
3. FLAG_FOR_PM items (max 5): collect them — post as a PM flag to Discord (see below)
4. SKIP items: do nothing, no mention

---

## PART 2: OPEN QUESTION FLAGGING

Scan for unresolved questions:
- "Should we X or Y?" threads with no conclusion
- VERIFICATION_REQUIRED items never followed up on
- Decisions explicitly deferred but never revisited

Collect these alongside any FLAG_FOR_PM items from Part 1.

---

## PART 3: POSTING RESULTS

Post in this order:

**All results go to pm-log only. PM reads pm-log during sweeps and escalates to helm-improvements only if user action is needed.**

**Step A — PM flag** (if any FLAG_FOR_PM items OR open questions exist):
bash /Users/{{USER_HOME}}/marvin-bot/pm-log-write.sh "gap-audit" "FLAGGED: [N] item(s) for PM review — [item 1 one line], [item 2 one line]. Open questions: [question 1 or none]"

**Step B — Summary** (always write exactly one to pm-log):
If QUEUE items found:
bash /Users/{{USER_HOME}}/marvin-bot/pm-log-write.sh "gap-audit" "DONE: [N] item(s) queued for engineer, [M] flagged for PM review. [One sentence on what was queued.]"

If nothing found:
bash /Users/{{USER_HOME}}/marvin-bot/pm-log-write.sh "gap-audit" "CLEAN: nothing slipped through today."

If only FLAG_FOR_PM items (no QUEUE items):
bash /Users/{{USER_HOME}}/marvin-bot/pm-log-write.sh "gap-audit" "DONE: 0 items auto-queued, [N] flagged for PM review (uncertain confidence — see FLAGGED entry above)."

---

## Inputs

### Discord conversation messages (past 24 hours) — PRIMARY SOURCE
$DISCORD_MESSAGES

### Today's decisions-log entries
$DECISIONS_CONTENT

### Currently pending engineer queue items (IDs only — do NOT re-queue these)
$QUEUE_PENDING

### Today's queue-audit entries
$AUDIT_TODAY_ENTRIES

### Active/design/concept work items
$WORK_ITEMS_CONTENT

### Known workspace names (items mentioning these → FLAG_FOR_PM, not QUEUE)
$WORKSPACE_NAMES

---

CRITICAL RULES:
- Apply the tier system strictly. When in doubt → FLAG_FOR_PM, not QUEUE.
- Never queue workspace-specific work. Workspace agents own their queue.
- 0 queued + 0 flagged is a valid and good outcome.
- Never manufacture gaps. Only concrete commitments with clear scope get queued.
PROMPT_EOF

log "Spawning Claude for gap analysis (with Discord message context)"
TS_START=$(date -u +%Y-%m-%dT%H:%M:%SZ)

HOME=/Users/{{USER_HOME}} \
PATH="/opt/homebrew/bin:/Users/{{USER_HOME}}/.local/bin:/Users/{{USER_HOME}}/.bun/bin:/usr/local/bin:/usr/bin:/bin" \
  "$CLAUDE" --dangerously-skip-permissions -p "$(cat "$PROMPT_FILE")" >> "$LOG" 2>&1

EXIT_CODE=$?
TS_END=$(date -u +%Y-%m-%dT%H:%M:%SZ)
log "Claude exited code=$EXIT_CODE at $TS_END"

echo "$TS_END | GAP_AUDIT_RUN | exit_code=$EXIT_CODE" >> "$AUDIT_FILE"

if [[ "$EXIT_CODE" -ne 0 ]]; then
  bash ~/marvin-bot/pm-log-write.sh "gap-audit" "ERROR: Claude exited code=$EXIT_CODE. Engineer run continues — check gap-audit-nightly.log." || true
fi

rm -f "$PROMPT_FILE"
log "Gap audit complete"
