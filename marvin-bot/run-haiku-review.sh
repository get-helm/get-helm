#!/usr/bin/env bash
# run-haiku-review.sh — Daily semantic analysis of friction log via Claude Haiku
# Usage: bash ~/marvin-bot/run-haiku-review.sh
# Reads:  ~/helm-workspace/system/friction-log.md (last 24h entries)
# Writes: ~/helm-workspace/behavior-metrics.json (appends semantic_reviews array + last_semantic_review)
# Called by: PM T2-L at the start of each daily sweep
# Estimated cost: ~0.01/day (Haiku model, ~500-1000 tokens)
#
# Output format added to behavior-metrics.json:
#   "last_semantic_review": {
#     "top_semantic_failure": "...",
#     "failure_type": "comprehension|priority|structural",
#     "recommended_fix": "...",
#     "top_behaviors": ["B-XX", "B-YY"],
#     "confidence": "high|medium|low",
#     "entry_count": N,
#     "reviewed_at": "2026-06-08T..."
#   },
#   "semantic_reviews": [ ...last 7 days... ]

set -euo pipefail

FRICTION_LOG="$HOME/helm-workspace/system/friction-log.md"
METRICS_FILE="$HOME/helm-workspace/behavior-metrics.json"
CLAUDE_BIN="/Users/{{USER_HOME}}/.local/bin/claude"

LOG_TAG="[haiku-review $(date -u +%H:%M:%SZ)]"

# ── 1. Extract last 24h violation entries ────────────────────────────────────

if [[ ! -f "$FRICTION_LOG" ]]; then
    echo "$LOG_TAG friction-log.md not found — skipping"
    exit 0
fi

ENTRIES_FILE=$(mktemp /tmp/haiku-entries.XXXXXX)
trap 'rm -f "$ENTRIES_FILE" /tmp/haiku-prompt.* /tmp/haiku-response.*' EXIT

python3 - <<'PYEOF' > "$ENTRIES_FILE"
import sys, re, json
from datetime import datetime, timezone, timedelta

FRICTION_LOG = "/Users/{{USER_HOME}}/helm-workspace/system/friction-log.md"
cutoff = datetime.now(timezone.utc) - timedelta(hours=24)
lines_out = []

with open(FRICTION_LOG, encoding='utf-8', errors='replace') as f:
    for line in f:
        line = line.rstrip()
        if not line or line.strip() == 'PASS':
            continue
        # Look for ISO timestamp anywhere in the line
        m = re.search(r'(20\d\d-\d\d-\d\dT\d\d:\d\d:\d\d)', line)
        if m:
            try:
                ts = datetime.fromisoformat(m.group(1) + '+00:00')
                if ts >= cutoff:
                    lines_out.append(line)
                continue
            except ValueError:
                pass
        # Try JSON format with "ts" field
        try:
            d = json.loads(line)
            ts_str = d.get('ts', '')
            if ts_str:
                ts = datetime.fromisoformat(ts_str.replace('Z', '+00:00'))
                if ts >= cutoff:
                    lines_out.append(line)
        except Exception:
            pass

# Cap at 80 entries to stay in Haiku's token budget
for ln in lines_out[-80:]:
    print(ln)
PYEOF

ENTRY_COUNT=$(grep -c . "$ENTRIES_FILE" 2>/dev/null || echo 0)

if [[ "$ENTRY_COUNT" -lt 1 ]]; then
    echo "$LOG_TAG No violation entries in last 24h — skipping"
    exit 0
fi

echo "$LOG_TAG $ENTRY_COUNT violation entries → sending to Haiku"

# ── 2. Build prompt ──────────────────────────────────────────────────────────

PROMPT_FILE=$(mktemp /tmp/haiku-prompt.XXXXXX)
{
    cat <<'HEADER'
You are analyzing behavior violation logs from HELM, an AI agent system. The logs below are from the last 24 hours.

Analyze these violations SEMANTICALLY — not just which rules were broken, but WHY agents keep failing at them.

FRICTION LOG ENTRIES:
---
HEADER
    cat "$ENTRIES_FILE"
    cat <<'FOOTER'
---

Classify the core failure pattern as one of:
- comprehension: agents don't understand what the rule requires
- priority: agents understand but treat it as lower priority than other goals
- structural: the rule is ambiguous, contradictory, or hard to follow in practice

Respond ONLY with a single JSON object (no markdown, no explanation):
{
  "top_semantic_failure": "one sentence describing the root conceptual failure",
  "failure_type": "comprehension|priority|structural",
  "recommended_fix": "one sentence describing the highest-leverage protocol change",
  "top_behaviors": ["B-XX", "B-YY"],
  "confidence": "high|medium|low"
}
FOOTER
} > "$PROMPT_FILE"

# ── 3. Call Haiku ────────────────────────────────────────────────────────────

RESPONSE_FILE=$(mktemp /tmp/haiku-response.XXXXXX)

# Use gtimeout (brew coreutils) if available, else run without timeout (macOS)
TIMEOUT_CMD=$(command -v gtimeout 2>/dev/null || command -v timeout 2>/dev/null || echo "")
if [[ -n "$TIMEOUT_CMD" ]]; then
    RUN_CLAUDE="$TIMEOUT_CMD 90 $CLAUDE_BIN"
else
    RUN_CLAUDE="$CLAUDE_BIN"
fi

if ! $RUN_CLAUDE -p "$(cat "$PROMPT_FILE")" \
        --model claude-haiku-4-5-20251001 \
        > "$RESPONSE_FILE" 2>/dev/null; then
    echo "$LOG_TAG Haiku call failed or timed out — skipping"
    exit 0
fi

if [[ ! -s "$RESPONSE_FILE" ]]; then
    echo "$LOG_TAG Haiku returned empty response — skipping"
    exit 0
fi

# ── 4. Parse JSON and write to behavior-metrics.json ────────────────────────

python3 - <<PYEOF
import json, re, sys
from datetime import datetime, timezone

response_file = "$RESPONSE_FILE"
metrics_file  = "$METRICS_FILE"
entry_count   = int("$ENTRY_COUNT")

# Parse Haiku response — strip markdown fences if present
text = open(response_file).read().strip()
text = re.sub(r'^\s*\`\`\`(?:json)?\s*', '', text)
text = re.sub(r'\s*\`\`\`\s*$', '', text)

# Find first JSON object
review = {}
m = re.search(r'\{.*\}', text, re.DOTALL)
if m:
    try:
        review = json.loads(m.group(0))
    except Exception as e:
        print(f"[haiku-review] JSON parse error: {e}")
        print(f"[haiku-review] Raw: {text[:300]}")
        sys.exit(0)
else:
    print(f"[haiku-review] No JSON found in response: {text[:300]}")
    sys.exit(0)

# Stamp and store
review['entry_count'] = entry_count
review['reviewed_at'] = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

# Read existing metrics
try:
    with open(metrics_file) as f:
        metrics = json.load(f)
except Exception as e:
    print(f"[haiku-review] Cannot read {metrics_file}: {e}")
    sys.exit(1)

# Maintain rolling 7-day review history
history = metrics.get('semantic_reviews', [])
history.append(review)
metrics['semantic_reviews'] = history[-7:]
metrics['last_semantic_review'] = review

with open(metrics_file, 'w') as f:
    json.dump(metrics, f, indent=2)

print(f"[haiku-review] Wrote daily_semantic_review to behavior-metrics.json")
print(f"[haiku-review] Top failure : {review.get('top_semantic_failure', 'N/A')}")
print(f"[haiku-review] Failure type: {review.get('failure_type', 'N/A')}")
print(f"[haiku-review] Fix         : {review.get('recommended_fix', 'N/A')}")
print(f"[haiku-review] Confidence  : {review.get('confidence', 'N/A')}")

# ENG-HAIKU-FINDINGS-LOOP-001: route findings to queue or steward
import subprocess, os
from datetime import datetime, timezone

recommended_fix = review.get('recommended_fix', '').strip()
top_failure = review.get('top_semantic_failure', '').strip()
failure_type = review.get('failure_type', '').strip()
confidence = review.get('confidence', '').strip()

if recommended_fix and recommended_fix.lower() not in ('none', 'n/a', ''):
    # Queue to engineer via queue-write.sh (pm-pre-queue-check is called internally)
    item_id = f"HAIKU-FINDING-{datetime.now(timezone.utc).strftime('%Y%m%d%H%M')}"
    description = f"Haiku semantic review finding ({failure_type}, confidence={confidence}): {top_failure}. Recommended fix: {recommended_fix}"
    queue_script = os.path.expanduser("~/marvin-bot/queue-write.sh")
    try:
        result = subprocess.run(
            [queue_script, item_id, description, "30", "--priority", "MED"],
            capture_output=True, text=True, timeout=30
        )
        if result.returncode == 0:
            print(f"[haiku-review] Queued finding to engineer: {item_id}")
            # Log WS-ADVANCE to decisions-log.md
            decisions_log = os.path.expanduser("~/helm-workspace/system/decisions-log.md")
            advance_entry = f"\n## [{datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M')}] WS-ADVANCE — Haiku finding auto-queued\n"
            advance_entry += f"- Item: {item_id}\n- Finding: {top_failure}\n- Fix queued: {recommended_fix}\n"
            with open(decisions_log, 'a') as dl:
                dl.write(advance_entry)
        else:
            print(f"[haiku-review] queue-write.sh blocked or failed: {result.stdout.strip()} {result.stderr.strip()}")
    except Exception as qe:
        print(f"[haiku-review] Queue error: {qe}")
else:
    # No recommended fix — append to steward-findings.md
    steward_findings = os.path.expanduser("~/helm-workspace/system/steward-findings.md")
    ts = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    finding_entry = f"\n## [{ts}] Haiku finding (no fix recommendation)\n"
    finding_entry += f"- Failure: {top_failure}\n- Type: {failure_type}\n- Confidence: {confidence}\n"
    try:
        with open(steward_findings, 'a') as sf:
            sf.write(finding_entry)
        print(f"[haiku-review] No fix — appended to steward-findings.md")
    except Exception as se:
        print(f"[haiku-review] steward-findings write error: {se}")
PYEOF
