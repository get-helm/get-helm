#!/usr/bin/env bash
# engineer-nightly.sh — Nightly engineer queue processor
# LaunchAgent (com.pap.engineer.nightly) fires every 10 min via launchd.
# Time guard: 2 AM–4 AM PT. Restart fires at 5 AM (1-hour buffer).
# Done-today flag prevents double-processing within the window.

set -euo pipefail

QUEUE_FILE="/Users/{{USER_HOME}}/helm-workspace/engineer-queue.md"
AUDIT_FILE="/Users/{{USER_HOME}}/helm-workspace/queue-audit.log"
DECISIONS_LOG="/Users/{{USER_HOME}}/helm-workspace/decisions-log.md"
LOG="/Users/{{USER_HOME}}/marvin-bot/engineer-nightly.log"
CLAUDE="/Users/{{USER_HOME}}/.local/bin/claude"
WORKDIR="/Users/{{USER_HOME}}/helm-workspace"
PAP_IMPROVEMENTS_CHANNEL="{{USER_CHANNEL_HELM_IMPROVEMENTS}}"
DONE_FLAG="/tmp/pap-engineer-done-$(date +%Y%m%d)"
DISCORD_POST="/Users/{{USER_HOME}}/marvin-bot/discord-post.sh"
PROMPT_FILE="/tmp/pap-engineer-prompt-$(date +%Y%m%d).txt"

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [engineer] $*" | tee -a "$LOG"
}

# Already ran tonight
[[ -f "$DONE_FLAG" ]] && exit 0

# Time guard: 1 AM–5:59 AM PT (5-hour overnight window; nightly-restart.sh fires at 5 AM, may interrupt 5-6 AM run)
HOUR=$(date +%H)
[[ "$HOUR" -lt 1 || "$HOUR" -ge 6 ]] && exit 0

log "Engineer nightly starting (hour=$HOUR)"

# Count pending items
PENDING_COUNT=$(python3 -c "
import re
with open('$QUEUE_FILE') as f:
    content = f.read()
blocks = re.findall(r'(?s)---\s*\nqueued_at:.*?status:\s*pending.*?---', content)
print(len(blocks))
" 2>/dev/null || echo "0")

if [[ "$PENDING_COUNT" -eq 0 ]]; then
  log "Queue empty — nothing to implement tonight"
  touch "$DONE_FLAG"
  exit 0
fi

log "Found $PENDING_COUNT pending item(s)"
touch "$DONE_FLAG"

# TOKEN-ENGINEER-BATCH-001: Process 3-5 items per session to reduce per-item spawn overhead.
# One session pays the fixed injection cost (~50-80K tokens) once for multiple items.
# If more than BATCH_SIZE items remain, they'll be picked up in the next nightly window.
BATCH_SIZE=15
if [[ "$PENDING_COUNT" -gt "$BATCH_SIZE" ]]; then
  log "Capping batch at $BATCH_SIZE items (found $PENDING_COUNT pending)"
  BATCH_COUNT=$BATCH_SIZE
else
  BATCH_COUNT=$PENDING_COUNT
fi

QUEUE_CONTENT=$(cat "$QUEUE_FILE")
EST_MINS=$(( BATCH_COUNT * 8 ))

  # L3 start notification → audit log (not helm-improvements; per channel-consolidation directive)
  printf '[%s] [engineer-nightly] ⏳ Engineer nightly: %d item(s) queued. Starting now, ~%d min.\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$PENDING_COUNT" "$EST_MINS" >> ~/helm-workspace/system/helm-audit.log 2>/dev/null || \
    log "helm-audit.log write failed (non-fatal)"

# Write prompt to temp file to avoid nested heredoc issues
cat > "$PROMPT_FILE" << PROMPT_EOF
You are the PAP engineer agent running in a nightly batch. Your job: implement every pending item in engineer-queue.md, then mark each one done.

## TOKEN-ENGINEER-BATCH-001 SESSION RULES
- This session processes UP TO $BATCH_COUNT items (batch limit = $BATCH_SIZE). Do not exit after completing one item — continue to the next.
- After completing each item: write a checkpoint noting what was done ("Done: X. In progress: next item. Next: remaining items."). This satisfies the silence-watchdog and lets you resume if killed.
- If you are killed mid-session and auto-resumed: read the checkpoint and continue from where you left off.
- Do NOT exit until all $BATCH_COUNT items are implemented or blocked. Silent exits between items = protocol violation.

## Rules
1. Work through items one at a time in order of priority (HIGH first, then MED, LOW).
2. For each item:
   a. Read the full spec from engineer-queue.md
   b. Implement the change in the referenced file
   c. Read back the file to verify the change landed
   d. Update the item's status from 'pending' to 'done' in engineer-queue.md directly (use Edit tool)
   e. Append to $DECISIONS_LOG: "## [timestamp] ENGINEER IMPLEMENTED: [item-id] — [one-line description]"
3. Never restart bot.js yourself — the nightly-restart.sh at 2am handles deploys.
4. If an item is ambiguous or requires a decision you cannot make: mark it 'blocked' with a note, then move on.
5. After ALL items are processed, write completion to audit log:
   printf '[%s] [engineer-nightly] ✅ Engineer nightly done: [N] implemented, [M] blocked.\n' "\$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> ~/helm-workspace/system/helm-audit.log

## Current queue contents
$QUEUE_CONTENT

## File locations
- Main bot file: ~/marvin-bot/bot.js
- Agent files: ~/.claude/agents/
- PAP workspace: ~/helm-workspace/

Start now. Do not stop until every pending item is implemented or marked blocked.
PROMPT_EOF

# TOKEN-CACHE-WINDOW-001: Apply staged instruction-file changes before spawning Claude.
# Agents write to system/instruction-staging/ instead of editing live always-injected files
# (CLAUDE.md, turn-protocol.md, behaviors.md, MEMORY.md) to avoid mid-day cache invalidation.
# Each staged file begins with: # APPLY_TO: /absolute/path/to/target
STAGING_DIR="$WORKDIR/system/instruction-staging"
if [[ -d "$STAGING_DIR" ]]; then
  shopt -s nullglob
  for staged_file in "$STAGING_DIR"/*.md; do
    [[ "$(basename "$staged_file")" == "README.md" ]] && continue
    TARGET_PATH=$(head -1 "$staged_file" | sed 's/^#[[:space:]]*APPLY_TO:[[:space:]]*//')
    if [[ -n "$TARGET_PATH" && "$TARGET_PATH" != "$staged_file" ]]; then
      log "Applying staged instruction change: $(basename "$staged_file") → $TARGET_PATH"
      if cp "$staged_file" "$TARGET_PATH"; then
        rm -f "$staged_file"
        printf '[%s] [engineer-nightly] INSTRUCTION-STAGE-APPLY: %s → %s\n' \
          "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(basename "$staged_file")" "$TARGET_PATH" \
          >> ~/helm-workspace/system/helm-audit.log 2>/dev/null || true
      else
        log "ERROR: failed to apply staged file $staged_file → $TARGET_PATH"
        printf '[%s] [engineer-nightly] INSTRUCTION-STAGE-FAIL: %s → %s\n' \
          "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(basename "$staged_file")" "$TARGET_PATH" \
          >> ~/helm-workspace/system/helm-audit.log 2>/dev/null || true
      fi
    else
      log "WARNING: staged file missing APPLY_TO header: $(basename "$staged_file") — skipping"
    fi
  done
  shopt -u nullglob
fi

TS_START=$(date -u +%Y-%m-%dT%H:%M:%SZ)
log "Spawning Claude to implement $BATCH_COUNT/$PENDING_COUNT item(s) — see log for output"
STATS_FILE="/tmp/pap-engineer-stats-$(date +%Y%m%d-%H%M%S).txt"

HOME=/Users/{{USER_HOME}} \
PATH="/opt/homebrew/bin:/Users/{{USER_HOME}}/.local/bin:/Users/{{USER_HOME}}/.bun/bin:/usr/local/bin:/usr/bin:/bin" \
  "$CLAUDE" --dangerously-skip-permissions -p "$(cat "$PROMPT_FILE")" >> "$LOG" 2>"$STATS_FILE"

EXIT_CODE=$?
TS_END=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Capture stderr (token stats and errors) to main log
cat "$STATS_FILE" >> "$LOG" 2>/dev/null

# TOKEN-ENGINEER-BATCH-001: parse token stats from Claude output and log to daily-token-summary
DAILY_TOKEN_SUMMARY="$WORKDIR/system/daily-token-summary.log"
TOKEN_INPUT=$(grep -oE 'input_tokens["\s:]+[0-9]+' "$STATS_FILE" 2>/dev/null | grep -oE '[0-9]+' | tail -1 || echo "unknown")
TOKEN_CACHE=$(grep -oE 'cache_read_input_tokens["\s:]+[0-9]+' "$STATS_FILE" 2>/dev/null | grep -oE '[0-9]+' | tail -1 || echo "unknown")
TOKEN_OUTPUT=$(grep -oE 'output_tokens["\s:]+[0-9]+' "$STATS_FILE" 2>/dev/null | grep -oE '[0-9]+' | tail -1 || echo "unknown")
printf '[%s] ENGINEER_BATCH items=%d/%d input=%s cached=%s output=%s exit=%d\n' \
  "$TS_END" "$BATCH_COUNT" "$PENDING_COUNT" "$TOKEN_INPUT" "$TOKEN_CACHE" "$TOKEN_OUTPUT" "$EXIT_CODE" \
  >> "$DAILY_TOKEN_SUMMARY" 2>/dev/null || true
rm -f "$STATS_FILE"

log "Claude exited code=$EXIT_CODE at $TS_END (batch=$BATCH_COUNT, tokens: in=$TOKEN_INPUT cached=$TOKEN_CACHE out=$TOKEN_OUTPUT)"

echo "$TS_END | ENGINEER_RUN | items_queued=$PENDING_COUNT, batch=$BATCH_COUNT, exit_code=$EXIT_CODE" >> "$AUDIT_FILE"

if [[ "$EXIT_CODE" -ne 0 ]]; then
  bash "$DISCORD_POST" "$PAP_IMPROVEMENTS_CHANNEL" \
    "⚠️ Engineer nightly exited with error (code=$EXIT_CODE). Check engineer-nightly.log for details." \
    2>/dev/null || true
fi

rm -f "$PROMPT_FILE"

# Log rotation — keep logs under 10MB
bash "$HOME/marvin-bot/helm-log-rotate.sh" 2>/dev/null || true

log "Engineer nightly complete"
