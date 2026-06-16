#!/bin/bash
# pm-pre-queue-check.sh — mandatory gate before any PM queue write
# Usage: bash pm-pre-queue-check.sh "ITEM-TITLE or description"
# Returns: 0 = ok to queue | 1 = blocked (item is challenged/stale/already-done)
#
# PM must call this script before every queue-write.sh call.
# If exit 1, PM must NOT queue — log to pap-audit + friction-log instead.

CHALLENGED_FILE=~/helm-workspace/product/CHALLENGED-ITEMS.md
ENGINEER_QUEUE_FILE=~/helm-workspace/system/engineer-queue.md
ITEM_TITLE="${1:-}"

if [[ -z "$ITEM_TITLE" ]]; then
  echo "Usage: pm-pre-queue-check.sh \"ITEM-TITLE\""
  exit 2
fi

# Extract structured item IDs from title (WORD-WORD-NNN, WORD-NNN, or multi-segment like B01-FOO-BAR)
# These are the canonical identifiers like WI-017, RECOVERY-TEST-01, B07-BLOCK-GATE-001
ITEM_IDS=$(echo "$ITEM_TITLE" | grep -oE '[A-Z][A-Z0-9]+-[A-Za-z0-9]+(-[A-Za-z0-9]+)*' | tr '[:upper:]' '[:lower:]')

ALL_TERMS="$ITEM_IDS"

# ── CHECK 1: CHALLENGED-ITEMS.md (exact item name match only) ──────────────
# Extracts the item name/ID from "## ITEM: NAME (description)" lines.
# Only blocks if an input item ID exactly matches a challenged item name.
# Does NOT use keyword/substring matching — prevents false positives from words
# like "recovery", "enforcement", "pushback" appearing in challenged item descriptions.
if [[ -f "$CHALLENGED_FILE" ]]; then
  # Extract only the identifier part (before any space or paren) from ## ITEM: lines
  # Normalize to lowercase + replace separators for comparison
  CHALLENGED_NAMES=$(grep -oE "## ITEM: [^ (]+" "$CHALLENGED_FILE" 2>/dev/null \
    | sed 's/## ITEM: //' \
    | tr '[:upper:]' '[:lower:]')

  MATCHED_KEYWORDS=""
  while IFS= read -r input_id; do
    [[ -z "$input_id" ]] && continue
    # Normalize input ID for comparison (already lowercase from extraction above)
    while IFS= read -r challenged_name; do
      [[ -z "$challenged_name" ]] && continue
      # Exact match (case-insensitive already, both lowercase)
      if [[ "$input_id" == "$challenged_name" ]]; then
        MATCHED_KEYWORDS="$MATCHED_KEYWORDS $input_id"
        break
      fi
    done <<< "$CHALLENGED_NAMES"
  done <<< "$ALL_TERMS"

  if [[ -n "$MATCHED_KEYWORDS" ]]; then
    echo "BLOCKED: '$ITEM_TITLE' matches challenged item name(s):$MATCHED_KEYWORDS"
    echo "Check CHALLENGED-ITEMS.md before re-queuing this item."
    TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    # PRE-QUEUE-BLOCKED (not PUSHBACK-RECUR) — this is the gate WORKING, not a protocol violation.
    # T1-D must NOT queue engineer fixes for PRE-QUEUE-BLOCKED events; they are informational only.
    echo "{\"ts\":\"$TS\",\"type\":\"PRE-QUEUE-BLOCKED\",\"item\":\"$ITEM_TITLE\",\"reason\":\"pm-pre-queue-check blocked: matched CHALLENGED-ITEMS.md item name: $MATCHED_KEYWORDS\"}" >> ~/helm-workspace/friction-log.md
    exit 1
  fi
fi

# ── CHECK 2: engineer-queue.md done records ───────────────────────────────
# Done records have status: done + completed_at: (no queued_at:).
# If the item we're about to queue already has a done record, block re-queue.
if [[ -f "$ENGINEER_QUEUE_FILE" ]]; then
  DONE_MATCH=""
  while IFS= read -r term; do
    [[ -z "$term" ]] && continue
    # Look for blocks containing both status: done and our term
    if python3 - "$ENGINEER_QUEUE_FILE" "$term" << 'PYEOF' 2>/dev/null
import sys, re
queue_file, term = sys.argv[1], sys.argv[2].lower()
content = open(queue_file).read()
# Split into blocks by ---
blocks = re.split(r'\n---\n', content)
for block in blocks:
    if 'status: done' in block and term in block.lower():
        sys.exit(0)  # found a match
sys.exit(1)  # no match
PYEOF
    then
      DONE_MATCH="$DONE_MATCH $term"
    fi
  done <<< "$ALL_TERMS"

  if [[ -n "$DONE_MATCH" ]]; then
    echo "BLOCKED: '$ITEM_TITLE' matches completed item(s) in engineer-queue.md:$DONE_MATCH"
    echo "This item was already completed. Verify it's a new request before re-queuing."
    TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "{\"ts\":\"$TS\",\"type\":\"ALREADY-DONE-REQUEUE\",\"item\":\"$ITEM_TITLE\",\"reason\":\"pm-pre-queue-check blocked: matched done record in engineer-queue.md: $DONE_MATCH\"}" >> ~/helm-workspace/friction-log.md
    exit 1
  fi
fi

# ── CHECK 3: task-registry.jsonl (canonical completion source) ──────────────
# task-registry.jsonl is the authoritative source; engineer-queue.md done records
# can lag or be absent after engineer removes the claimed block.
TASK_REGISTRY=~/helm-workspace/task-registry.jsonl
if [[ -f "$TASK_REGISTRY" ]] && [[ -n "$ITEM_IDS" ]]; then
  REGISTRY_MATCH=""
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    MATCHED_LINE=$(grep -i "\"id\".*\"$id\"" "$TASK_REGISTRY" 2>/dev/null | tail -1)
    if [[ -n "$MATCHED_LINE" ]] && echo "$MATCHED_LINE" | grep -qi '"status".*"done"'; then
      REGISTRY_MATCH="$REGISTRY_MATCH $id"
    fi
  done <<< "$ITEM_IDS"

  if [[ -n "$REGISTRY_MATCH" ]]; then
    echo "BLOCKED: '$ITEM_TITLE' — IDs already completed in task-registry.jsonl:$REGISTRY_MATCH"
    echo "Item is done. Update pm-scratch.md state. Do NOT re-queue."
    TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "{\"ts\":\"$TS\",\"type\":\"ALREADY-DONE-REQUEUE\",\"item\":\"$ITEM_TITLE\",\"reason\":\"task-registry.jsonl done entry found for:$REGISTRY_MATCH\"}" >> ~/helm-workspace/friction-log.md
    exit 1
  fi
fi

# ── CHECK 4: filesystem implementation evidence (impl-check.sh) ───────────────
# Catches items that were implemented but removed from queue without a done record.
# Returns FOUND if any search term from the title matches files/git in the codebase.
# WARN (not block) — file presence alone isn't proof of completion.
IMPL_CHECK_SCRIPT="$HOME/marvin-bot/impl-check.sh"
if [[ -f "$IMPL_CHECK_SCRIPT" ]]; then
  IMPL_OUTPUT=$(bash "$IMPL_CHECK_SCRIPT" "$ITEM_TITLE" 2>/dev/null || true)
  if echo "$IMPL_OUTPUT" | grep -q "^FOUND:"; then
    echo "WARN: '$ITEM_TITLE' — impl-check found filesystem evidence this may already be implemented."
    echo "$IMPL_OUTPUT"
    echo "Verify the implementation before queuing to avoid duplicate work."
    echo "If this is genuinely new work, proceed — this is a warning, not a block."
    TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "{\"ts\":\"$TS\",\"type\":\"IMPL-EXISTS-WARN\",\"item\":\"$ITEM_TITLE\",\"reason\":\"impl-check.sh found filesystem evidence\"}" >> ~/helm-workspace/friction-log.md
    # WARN only — still exit 0 so PM can queue after verifying
  fi
fi

echo "OK: '$ITEM_TITLE' — no CHALLENGED-ITEMS.md, done-record, or task-registry match. Queue write allowed."
exit 0
