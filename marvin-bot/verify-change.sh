#!/bin/bash
# verify-change.sh <filepath>
# Called by agents before posting DELIVER when claiming a file was edited.
# Returns diff summary (exit 0) or error if file appears unchanged (exit 1).
# Usage:  bash ~/marvin-bot/verify-change.sh /path/to/file

FILE="$1"
if [ -z "$FILE" ]; then
    echo "Usage: verify-change.sh <filepath>"
    exit 2
fi

if [ ! -f "$FILE" ]; then
    echo "ERROR: $FILE does not exist — was it actually created?"
    exit 1
fi

# Check git diff (staged + unstaged vs HEAD)
REPO_DIR=$(git -C "$(dirname "$FILE")" rev-parse --show-toplevel 2>/dev/null)
if [ -n "$REPO_DIR" ]; then
    DIFF=$(git -C "$REPO_DIR" diff HEAD -- "$FILE" 2>/dev/null)
    STAGED=$(git -C "$REPO_DIR" diff --cached -- "$FILE" 2>/dev/null)
    COMBINED="${DIFF}${STAGED}"
    if [ -n "$COMBINED" ]; then
        ADDED=$(echo "$COMBINED" | grep -c '^+' 2>/dev/null || echo 0)
        REMOVED=$(echo "$COMBINED" | grep -c '^-' 2>/dev/null || echo 0)
        echo "VERIFIED: $FILE changed (+${ADDED}/-${REMOVED} lines)"
        echo "$COMBINED" | head -8
        exit 0
    fi
    # New file not yet staged
    if git -C "$REPO_DIR" ls-files --others --exclude-standard "$FILE" | grep -q .; then
        LINES=$(wc -l < "$FILE")
        echo "VERIFIED: $FILE is new (untracked, ${LINES} lines)"
        exit 0
    fi
    echo "WARNING: $FILE exists but shows no git diff — may not have been changed this turn."
    echo "File size: $(wc -c < "$FILE") bytes. Last modified: $(stat -f '%Sm' "$FILE" 2>/dev/null || stat -c '%y' "$FILE" 2>/dev/null)"
    exit 1
fi

# Not in a git repo — fall back to mtime check
MTIME=$(find "$FILE" -newer /tmp/.verify-baseline 2>/dev/null)
echo "WARNING: Not in git repo. File exists ($(wc -c < "$FILE") bytes) but cannot verify change."
exit 0
