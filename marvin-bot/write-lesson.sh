#!/bin/bash
# write-lesson.sh — Append a lesson entry to lessons-learned.jsonl
# Usage: write-lesson.sh <agent_type> <error_class> <what_went_wrong> <correction> <prevention>
# Or pipe JSON directly: echo '{"agent_type":"help",...}' | write-lesson.sh

LESSONS_FILE="$HOME/helm-workspace/lessons-learned.jsonl"

if [ $# -eq 5 ]; then
    TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    python3 -c "
import json, sys
entry = {
    'ts': '$TS',
    'agent_type': sys.argv[1],
    'error_class': sys.argv[2],
    'what_went_wrong': sys.argv[3],
    'correction': sys.argv[4],
    'prevention': sys.argv[5]
}
print(json.dumps(entry))
" "$1" "$2" "$3" "$4" "$5" >> "$LESSONS_FILE"
    echo "Lesson written to $LESSONS_FILE"
elif [ -p /dev/stdin ]; then
    # Piped JSON
    cat >> "$LESSONS_FILE"
    echo "Lesson written to $LESSONS_FILE"
else
    echo "Usage: write-lesson.sh <agent_type> <error_class> <what_went_wrong> <correction> <prevention>"
    echo "  agent_type: help, curiosity, workspace, connector, product-manager, engineer"
    echo "  error_class: e.g. verification_delegation, silent_exit, missing_pushback"
    exit 1
fi
