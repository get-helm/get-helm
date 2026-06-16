#!/bin/bash
# qmd-query.sh — Query the second brain via QMD
# Usage: qmd-query.sh "query string" [N results] [--min-relevance 0.7]
# Output: JSON array with source/date/title/summary/relevance fields

QUERY="$1"
N="${2:-5}"
QMD=~/.bun/bin/qmd
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
MIN_RELEVANCE="0"

# Parse optional --min-relevance flag
while [[ $# -gt 2 ]]; do
  case "$3" in
    --min-relevance)
      MIN_RELEVANCE="${4:-0}"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

if [[ -z "$QUERY" ]]; then
  echo '[]'
  exit 0
fi

if [[ ! -x "$QMD" ]]; then
  echo '[]'
  exit 0
fi

# Usage telemetry — PM T2-C reads weekly counts to measure second-brain adoption
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] qmd-query q=\"$QUERY\"" >> ~/helm-workspace/system/tool-usage.log 2>/dev/null

# Clean up any stale literal-XXXXXX files left by the old (broken) template.
# BSD/macOS mktemp only randomizes TRAILING X's — a suffix after XXXXXX produces
# a literal "XXXXXX" file every run, which collides across concurrent queries and
# silently returns []. Templates below keep the X's last so mktemp actually randomizes.
rm -f /tmp/qmd-result-XXXXXX.json /tmp/qmd-wiki-XXXXXX.json 2>/dev/null
TMPFILE=$(mktemp /tmp/qmd-result.XXXXXX)
WIKI_TMP=$(mktemp /tmp/qmd-wiki.XXXXXX)
# Bail out gracefully if mktemp failed (disk full, permissions, etc.)
if [[ -z "$TMPFILE" || -z "$WIKI_TMP" ]]; then
  echo '[]'
  exit 0
fi
trap "rm -f $TMPFILE $WIKI_TMP" EXIT

# Wiki-first: grep wiki/index.md for category match, extract filenames from category file
WIKI_INDEX=~/helm-workspace/second-brain/wiki/index.md
WIKI_DIR=~/helm-workspace/second-brain/wiki
SB_DIR=~/helm-workspace/second-brain

python3 - "$QUERY" "$WIKI_INDEX" "$WIKI_DIR" "$SB_DIR" << 'WIKIEOF' > "$WIKI_TMP" 2>/dev/null || echo '[]' > "$WIKI_TMP"
import sys, os, re, json

query = sys.argv[1].lower()
wiki_index = os.path.expanduser(sys.argv[2])
wiki_dir = os.path.expanduser(sys.argv[3])
sb_dir = os.path.expanduser(sys.argv[4])

# Category keyword map (mirrors wiki/index.md categories)
CATEGORY_KEYWORDS = {
    'token-efficiency': ['token','tokens','cost','caching','prompt cache','session limit','expensive','cheaper','openrouter','caveman','budget','spend','usage','rate limit','token hack','save money'],
    'second-brain': ['second brain','knowledge base','knowledge graph','qmd','wiki','search','index','karpathy','graphify','memory system','retrieval','llm knowledge','organize','capture','ttl','decay','recall','obsidian'],
    'pap-system': ['pap','skills','agent','orchestration','agentic os','hermes','claude code features','vision','multi-agent','computer use','anti-glaze','hooks','prompting','system prompt'],
    'claude-api': ['anthropic','claude api','memory 2.0','dispatch','computer use','scheduled tasks','mcp','ncp','business features','plugins','new features','api'],
    'ai-tools': ['hermes','openclaw','paperclip','trading assistant','graphify tool'],
    'workflows': ['daily brief','general channel','capture','pap improvements','mission control','on the go','japan','email','discord','conversation history','archived'],
    'personal': ['email','onboarding','lso','low stress options'],
}

# Find best-matching category
best_cat = None
best_score = 0
for cat, keywords in CATEGORY_KEYWORDS.items():
    score = sum(1 for kw in keywords if kw in query)
    if score > best_score:
        best_score = score
        best_cat = cat

if best_score == 0 or best_cat is None:
    print('[]')
    sys.exit(0)

# Read matching category file and extract filenames
cat_file = os.path.join(wiki_dir, best_cat + '.md')
if not os.path.exists(cat_file):
    print('[]')
    sys.exit(0)

results = []
with open(cat_file) as f:
    for line in f:
        m = re.search(r'\*\*([^*]+\.md)\*\*\s*[—-]+\s*(.+)', line)
        if not m:
            m = re.search(r'\|\s*([^\s|]+\.md)\s*\|\s*(.+?)\s*\|', line)
        if m:
            fname = m.group(1).strip()
            title = m.group(2).strip()
            fpath = os.path.join(sb_dir, fname)
            if os.path.exists(fpath):
                date_match = re.search(r'(\d{4}-\d{2}-\d{2})', fname)
                date = date_match.group(1) if date_match else ''
                results.append({
                    'source': fpath,
                    'date': date,
                    'title': title,
                    'summary': f'[wiki:{best_cat}] {title}',
                    'relevance': round(0.6 + best_score * 0.05, 2),
                    'context': f'wiki category: {best_cat}'
                })

print(json.dumps(results[:5]))
WIKIEOF

# QMD writes valid JSON to stdout, then on Apple Silicon the ggml-metal backend
# hits GGML_ASSERT during process exit (SIGABRT / "Abort trap: 6"). Bash prints
# "Abort trap: 6" to stderr whenever a child dies by signal — `2>/dev/null` on
# the call line doesn't catch it because it comes from the outer shell, not the
# child. Workaround: run qmd in a background job and wait for it, then disown
# so bash never reports the signal-death message.
"$QMD" query "$QUERY" --json -n "$N" > "$TMPFILE" 2>/dev/null &
QMD_PID=$!
wait "$QMD_PID" 2>/dev/null || true

if [[ ! -s "$TMPFILE" ]]; then
  echo '[]'
  exit 0
fi

python3 - "$TMPFILE" "$WIKI_TMP" "$MIN_RELEVANCE" << 'PYEOF'
import json, re, sys

min_relevance = float(sys.argv[3]) if len(sys.argv) > 3 else 0

# Load QMD results
try:
    with open(sys.argv[1]) as f:
        items = json.load(f)
    if not isinstance(items, list):
        items = []
except Exception:
    items = []

# Load wiki results
try:
    with open(sys.argv[2]) as f:
        wiki_items = json.load(f)
    if not isinstance(wiki_items, list):
        wiki_items = []
except Exception:
    wiki_items = []

# Parse QMD results
qmd_results = []
qmd_sources = set()
for item in items:
    file_path = item.get('file', '')
    title = item.get('title', '')
    score = item.get('score', 0)
    snippet = item.get('snippet', '')
    context = item.get('context', '')

    if score < min_relevance:
        continue

    fname = file_path.split('/')[-1]
    date_match = re.search(r'(\d{4}-\d{2}-\d{2})', fname)
    date = date_match.group(1) if date_match else ''

    summary = re.sub(r'@@ -\d+,\d+ @@ \(\d+ before, \d+ after\)\n?', '', snippet).strip()
    summary = summary[:300] if len(summary) > 300 else summary

    qmd_results.append({
        'source': file_path,
        'date': date,
        'title': title,
        'summary': summary,
        'relevance': round(score, 2),
        'context': context
    })
    qmd_sources.add(file_path)

# If QMD returned fewer than 2 results, prepend wiki results (deduped)
results = list(qmd_results)
if len(qmd_results) < 2 and wiki_items:
    wiki_only = [w for w in wiki_items if w.get('source', '') not in qmd_sources]
    results = wiki_only[:3] + results

print(json.dumps(results, indent=2))
PYEOF
