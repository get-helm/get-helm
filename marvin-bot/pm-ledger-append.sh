#!/bin/bash
# pm-ledger-append.sh — Append PM action to shared ledger at DELIVER time
# Usage: pm-ledger-append.sh "keywords" "summary" [channel_id] [trigger]
# Keywords: space-separated lowercase terms (e.g. "options-helper deploy vps")
# Summary: one-line description of what PM decided/did this sweep

LEDGER="$HOME/helm-workspace/pm-ledger.md"
KEYWORDS="${1:-}"
SUMMARY="${2:-}"
CHANNEL_ID="${3:-unknown}"
TRIGGER="${4:-schedule}"

if [[ -z "$KEYWORDS" || -z "$SUMMARY" ]]; then
  echo "Usage: pm-ledger-append.sh \"keywords\" \"summary\" [channel_id] [trigger]" >&2
  exit 1
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

cat >> "$LEDGER" << EOF

---
ts: $TIMESTAMP
channel: $CHANNEL_ID
trigger: $TRIGGER
keywords: $KEYWORDS
summary: $SUMMARY
EOF

echo "Ledger entry appended: $TIMESTAMP — $SUMMARY"
