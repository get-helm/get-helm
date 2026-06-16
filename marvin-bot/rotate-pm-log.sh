#!/bin/bash
# Rotate pm-log.md: keep last 10 entries, archive rest
PM_LOG=~/helm-workspace/system/pm-log.md
PM_ARCHIVE=~/helm-workspace/system/pm-log-archive.md

[[ -f "$PM_LOG" ]] || exit 0

# Count entries (## headers)
ENTRY_COUNT=$(grep -c "^## " "$PM_LOG" 2>/dev/null || echo 0)

if [[ "$ENTRY_COUNT" -le 10 ]]; then
    exit 0
fi

# Find line where 11th entry from top begins
KEEP_BOUNDARY=$(grep -n "^## " "$PM_LOG" | awk -F: 'NR==11{print $1}')

if [[ -z "$KEEP_BOUNDARY" ]]; then
    exit 0
fi

# Archive entries before the 11th
head -n "$((KEEP_BOUNDARY - 1))" "$PM_LOG" >> "$PM_ARCHIVE"

# Keep only from 11th entry onward
tail -n "+$KEEP_BOUNDARY" "$PM_LOG" > /tmp/pm-log-trimmed.md
mv /tmp/pm-log-trimmed.md "$PM_LOG"

SIZE=$(ls -lh "$PM_LOG" | awk '{print $5}')
echo "pm-log.md rotated: kept entries from line $KEEP_BOUNDARY, size now $SIZE"
