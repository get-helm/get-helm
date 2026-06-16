#!/bin/bash
# pm-ledger-search.sh — Search PM ledger for keyword matches at ACK time
# Usage: pm-ledger-search.sh "keyword1 keyword2" [max_results]
# Returns: top N matching entries (most recent first) with ts, channel, summary

LEDGER="$HOME/helm-workspace/pm-ledger.md"
QUERY="${1:-}"
MAX="${2:-3}"

if [[ -z "$QUERY" ]]; then
  echo "Usage: pm-ledger-search.sh \"keyword1 keyword2\" [max_results]" >&2
  exit 1
fi

if [[ ! -f "$LEDGER" ]]; then
  echo "[pm-ledger] no ledger file found"
  exit 0
fi

# Parse entries between --- blocks
# Each entry has: ts, channel, trigger, keywords, summary
# Score = count of query words found in keywords+summary
python3 << PYEOF
import re, sys

query_words = "${QUERY}".lower().split()
max_results = int("${MAX}")

with open("${LEDGER}") as f:
    content = f.read()

# Split on entry separators
blocks = re.split(r'\n---\n', content)

entries = []
for block in blocks:
    ts_m = re.search(r'^ts: (.+)$', block, re.M)
    ch_m = re.search(r'^channel: (.+)$', block, re.M)
    kw_m = re.search(r'^keywords: (.+)$', block, re.M)
    su_m = re.search(r'^summary: (.+)$', block, re.M)
    if ts_m and su_m:
        ts = ts_m.group(1).strip()
        channel = ch_m.group(1).strip() if ch_m else 'unknown'
        keywords = kw_m.group(1).strip().lower() if kw_m else ''
        summary = su_m.group(1).strip()
        search_text = (keywords + ' ' + summary.lower())
        score = sum(1 for w in query_words if w in search_text)
        if score > 0:
            entries.append((score, ts, channel, summary))

# Sort: highest score first, then most recent
entries.sort(key=lambda x: (-x[0], x[1]), reverse=False)
entries.sort(key=lambda x: (-x[0]))

top = entries[:max_results]
if not top:
    print("[pm-ledger] no matches for: ${QUERY}")
else:
    for score, ts, channel, summary in top:
        print(f"[{ts}] ch:{channel} ({score} kw match) — {summary}")
PYEOF
