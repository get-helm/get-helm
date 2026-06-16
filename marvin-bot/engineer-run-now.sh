#!/usr/bin/env bash
# engineer-run-now.sh — On-demand engineer queue processor (no time guard).
# {{USER_JERRY}}-approved immediate run (2026-06-14). Mirrors engineer-nightly.sh claude
# invocation but skips the 1-6 AM time guard and done-flag so it runs on demand.
# Restart approved by {{USER_JERRY}} for this batch.

set -uo pipefail

QUEUE_FILE="/Users/{{USER_HOME}}/helm-workspace/engineer-queue.md"
AUDIT_FILE="/Users/{{USER_HOME}}/helm-workspace/queue-audit.log"
DECISIONS_LOG="/Users/{{USER_HOME}}/helm-workspace/decisions-log.md"
LOG="/Users/{{USER_HOME}}/marvin-bot/engineer-nightly.log"
CLAUDE="/Users/{{USER_HOME}}/.local/bin/claude"
WORKDIR="/Users/{{USER_HOME}}/helm-workspace"
PROMPT_FILE="/tmp/pap-engineer-runnow-$(date +%Y%m%d-%H%M%S).txt"

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [engineer-run-now] $*" | tee -a "$LOG"; }

PENDING_COUNT=$(python3 -c "
import re
c=open('$QUEUE_FILE').read()
print(len(re.findall(r'(?s)---\s*\nqueued_at:.*?status:\s*pending.*?---', c)))
" 2>/dev/null || echo "0")

log "On-demand engineer run starting — $PENDING_COUNT pending item(s)"
[[ "$PENDING_COUNT" -eq 0 ]] && { log "Queue empty — nothing to do"; exit 0; }

QUEUE_CONTENT=$(cat "$QUEUE_FILE")

cat > "$PROMPT_FILE" << PROMPT_EOF
You are the PAP engineer agent running an on-demand batch approved by {{USER_JERRY}}. Implement EVERY pending item in engineer-queue.md, then mark each done. Do not stop until the queue is clear.

## PRIORITY ORDER ({{USER_JERRY}}'s explicit request)
1. GET-HELM-REPO-001 — build the get-helm/get-helm PUBLIC distribution repo (canonical target is github.com/get-helm/get-helm; the repo is ALREADY PUBLIC; NEVER publish or flip {{USER_GITHUB}}/marvin-bot or {{USER_GITHUB}}/helm-config — those are private backups).
2. CONVERSATIONAL-ONBOARD-001 — rebuild onboarding as the approved Claude Desktop conversational flow (no terminal).
3. After both complete: SMOKE TEST the clean install flow end-to-end against get-helm/get-helm (anonymous clone + install on the VPS sandbox path). Report literal output. Append a SMOKE-TEST result to $DECISIONS_LOG.
Then implement the remaining pending items (button cascade, cadence-miss, etc.).

## Rules
1. For each item: read its full spec, implement in the referenced file, READ BACK the file to verify the change landed, set status pending->done in engineer-queue.md, append "## [ts] ENGINEER IMPLEMENTED: [id] — [desc]" to $DECISIONS_LOG.
2. After each item, write a checkpoint note so a kill can resume.
3. If a restart is required to deploy a change, you MAY restart: {{USER_JERRY}} pre-approved all restarts for this batch. Use ~/marvin-bot/safe-restart.sh --force.
4. If an item truly needs a {{USER_JERRY}} decision you cannot make, mark it blocked with a note and move on — do not stall the whole batch.
5. When all items done: printf '[%s] [engineer-run-now] DONE: [N] implemented, [M] blocked.\n' "\$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> ~/helm-workspace/system/helm-audit.log

## Current queue contents
$QUEUE_CONTENT

## File locations
- Main bot file: ~/marvin-bot/bot.js
- Agent files: ~/.claude/agents/
- PAP workspace: ~/helm-workspace/

Start now. Do not stop until every pending item is implemented or marked blocked.
PROMPT_EOF

TS_START=$(date -u +%Y-%m-%dT%H:%M:%SZ)
log "Spawning Claude to implement $PENDING_COUNT item(s)"
STATS_FILE="/tmp/pap-engineer-runnow-stats-$(date +%Y%m%d-%H%M%S).txt"

HOME=/Users/{{USER_HOME}} \
PATH="/opt/homebrew/bin:/Users/{{USER_HOME}}/.local/bin:/Users/{{USER_HOME}}/.bun/bin:/usr/local/bin:/usr/bin:/bin" \
  "$CLAUDE" --dangerously-skip-permissions -p "$(cat "$PROMPT_FILE")" >> "$LOG" 2>"$STATS_FILE"
EXIT_CODE=$?
TS_END=$(date -u +%Y-%m-%dT%H:%M:%SZ)
cat "$STATS_FILE" >> "$LOG" 2>/dev/null
rm -f "$STATS_FILE" "$PROMPT_FILE"

echo "$TS_END | ENGINEER_RUN_NOW | items_queued=$PENDING_COUNT, exit_code=$EXIT_CODE" >> "$AUDIT_FILE"
printf '[%s] [engineer-run-now] batch finished exit=%d\n' "$TS_END" "$EXIT_CODE" >> ~/helm-workspace/system/helm-audit.log 2>/dev/null
log "On-demand engineer run complete exit=$EXIT_CODE"
