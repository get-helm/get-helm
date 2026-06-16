#!/usr/bin/env bash
# impl-check.sh — search codebase for evidence that a task was already implemented
# Usage: impl-check.sh "keyword or task description" [--quiet]
# Returns: 0 = FOUND (evidence exists) | 1 = NOT-FOUND
#
# Call this from PRE-CLAIM-GATE before asserting any item is "unbuilt" or "not implemented."
# If FOUND, do NOT claim the item is missing — note "may be implemented, verify path."
#
# Option A of the 2026-06-14 agent-confusion fix. Extends PRE-CLAIM-GATE to cover
# filesystem code in addition to task-registry + queue records.

set -uo pipefail

QUERY="${1:-}"
QUIET=false
[[ "${2:-}" == "--quiet" ]] && QUIET=true

if [[ -z "$QUERY" ]]; then
  echo "Usage: impl-check.sh \"keyword or task description\" [--quiet]" >&2
  exit 2
fi

FOUND=false
EVIDENCE=()

# Extract meaningful search terms: skip short/common words, take first 6 meaningful words
TERMS=$(echo "$QUERY" | tr '[:upper:]' '[:lower:]' \
  | grep -oE '[a-z][a-z0-9_-]{3,}' \
  | grep -vE '^(this|that|with|from|into|when|then|will|have|been|also|dont|cant|wont|should|would|could|already|about|after|before|which|their|there)$' \
  | head -6)

if [[ -z "$TERMS" ]]; then
  echo "NOT-FOUND: could not extract search terms from: $QUERY" >&2
  exit 1
fi

# Search locations (ordered: most likely first)
SEARCH_PATHS=(
  "$HOME/marvin-bot"
  "$HOME/.claude/agents"
  "$HOME/helm-workspace/system"
  "$HOME/helm-workspace/specs"
  "$HOME/helm-config/bot"
  "$HOME/helm-workspace/product"
)

# For each term, search all locations
for TERM in $TERMS; do
  for DIR in "${SEARCH_PATHS[@]}"; do
    [[ -d "$DIR" ]] || continue
    HITS=$(grep -rl "$TERM" "$DIR" --include="*.sh" --include="*.md" --include="*.json" --include="*.jsonl" --include="*.js" 2>/dev/null | head -3)
    if [[ -n "$HITS" ]]; then
      while IFS= read -r hit; do
        EVIDENCE+=("$TERM → $(basename "$hit") ($(dirname "$hit" | sed "s|$HOME|~|g"))")
      done <<< "$HITS"
      FOUND=true
    fi
  done
done

# Also check git log for recent commits mentioning any term
if command -v git &>/dev/null; then
  for TERM in $TERMS; do
    GIT_HIT=$(git -C "$HOME/marvin-bot" log --oneline --since="90 days ago" --grep="$TERM" -1 2>/dev/null \
      || git -C "$HOME/helm-config" log --oneline --since="90 days ago" --grep="$TERM" -1 2>/dev/null \
      || true)
    if [[ -n "$GIT_HIT" ]]; then
      EVIDENCE+=("git-commit: $GIT_HIT")
      FOUND=true
    fi
  done
fi

# Also check engineer-queue.md done records
QUEUE_FILE="$HOME/helm-workspace/system/engineer-queue.md"
if [[ -f "$QUEUE_FILE" ]]; then
  for TERM in $TERMS; do
    DONE_HIT=$(grep -A 5 "status: done" "$QUEUE_FILE" 2>/dev/null | grep -i "$TERM" | head -1 || true)
    if [[ -n "$DONE_HIT" ]]; then
      EVIDENCE+=("queue-done: $DONE_HIT")
      FOUND=true
    fi
  done
fi

# Output
if $FOUND; then
  $QUIET || echo "FOUND: implementation evidence for \"$QUERY\""
  if ! $QUIET; then
    printf "%s\n" "${EVIDENCE[@]}" | sort -u | head -5 | while IFS= read -r e; do
      echo "  • $e"
    done
  fi
  exit 0
else
  $QUIET || echo "NOT-FOUND: no implementation evidence for \"$QUERY\" (searched: $TERMS)"
  exit 1
fi
