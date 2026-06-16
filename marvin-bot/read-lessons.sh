#!/bin/bash
# read-lessons.sh — Output last N lessons from lessons-learned.jsonl in readable format
# Usage: read-lessons.sh [N]  (default: 20)

LESSONS_FILE="$HOME/helm-workspace/lessons-learned.jsonl"
N="${1:-20}"

if [ ! -f "$LESSONS_FILE" ]; then
    echo "No lessons recorded yet. (File: $LESSONS_FILE)"
    exit 0
fi

TOTAL=$(wc -l < "$LESSONS_FILE")
echo "=== PAP Lessons Learned (last $N of $TOTAL) ==="
echo ""

tail -n "$N" "$LESSONS_FILE" | python3 -c "
import sys, json

i = 1
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        d = json.loads(line)
        print(f\"[{i}] {d.get('ts','?')} — {d.get('agent_type','?')} — {d.get('error_class','?')}\")
        print(f\"    What: {d.get('what_went_wrong','?')}\")
        print(f\"    Fix:  {d.get('correction','?')}\")
        print(f\"    Prev: {d.get('prevention','?')}\")
        print()
        i += 1
    except:
        pass
"
