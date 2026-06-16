#!/usr/bin/env bash
# refresh-context-cache.sh — CONTEXT-INJECTION-001
# Refreshes ~/helm-workspace/system/CONTEXT.md every 5 min via cron
# Bot.js reads this file and pre-injects into every agent spawn system prompt
# Root cause solved: agents forgetting recent decisions + duplicating queue writes

set -euo pipefail

CONTEXT_FILE="$HOME/helm-workspace/system/CONTEXT.md"
DECISIONS_LOG="$HOME/helm-workspace/system/decisions-log.md"
ENGINEER_QUEUE="$HOME/helm-workspace/system/engineer-queue.md"
FRICTION_LOG="$HOME/helm-workspace/system/friction-log.md"
WORK_ITEMS="$HOME/helm-workspace/system/work-items.json"
TASK_REGISTRY="$HOME/helm-workspace/task-registry.jsonl"

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

build_context() {
  echo "# HELM CONTEXT SNAPSHOT"
  echo "# Refreshed: $NOW (every 5 min — do not edit manually)"
  echo "# Pre-injected into every agent spawn to prevent forgotten decisions"
  echo ""

  # --- Recent decisions (last 10 from decisions-log.md) ---
  echo "## Recent Decisions (last 10)"
  if [[ -f "$DECISIONS_LOG" ]]; then
    # Extract ## [date] — ... decision headers and their first line of content
    python3 - << 'PYEOF'
import re, os

log_path = os.path.expanduser('~/helm-workspace/system/decisions-log.md')
if not os.path.exists(log_path):
    print("(no decisions-log.md found)")
    exit(0)

with open(log_path) as f:
    content = f.read()

# Match decision blocks: ## [YYYY-MM-DD HH:MM] — title
blocks = re.findall(r'## \[[\d]{4}-[\d]{2}-[\d]{2}[^\]]*\][^\n]*(?:\n(?![#])[^\n]*)*', content)
recent = blocks[-10:] if len(blocks) > 10 else blocks
recent.reverse()  # newest first

for block in recent:
    lines = block.strip().split('\n')
    header = lines[0]
    summary = lines[1].strip() if len(lines) > 1 else ''
    # Truncate long summaries
    if len(summary) > 120:
        summary = summary[:117] + '...'
    print(f"- {header}")
    if summary:
        print(f"  {summary}")
PYEOF
  else
    echo "(decisions-log.md not found)"
  fi
  echo ""

  # --- Engineer queue status ---
  echo "## Engineer Queue Status"
  if [[ -f "$ENGINEER_QUEUE" ]]; then
    # Count pending items (have queued_at: block)
    PENDING=$(grep -c "^queued_at:" "$ENGINEER_QUEUE" 2>/dev/null || echo 0)
    IN_PROGRESS=$(grep -c "^status: in_progress" "$ENGINEER_QUEUE" 2>/dev/null || echo 0)
    echo "Pending: $PENDING | In progress: $IN_PROGRESS"
    echo ""
    echo "Top pending items:"
    python3 - << 'PYEOF'
import re, os

queue_path = os.path.expanduser('~/helm-workspace/system/engineer-queue.md')
if not os.path.exists(queue_path):
    print("(engineer-queue.md not found)")
    exit(0)

with open(queue_path) as f:
    content = f.read()

# Find queued_at blocks (pending items)
blocks = re.split(r'\n---\n', content)
pending = []
for block in blocks:
    if 'queued_at:' in block:
        id_m = re.search(r'^id:\s*(.+)', block, re.MULTILINE)
        title_m = re.search(r'^title:\s*(.+)', block, re.MULTILINE)
        desc_m = re.search(r'^description:\s*(.+)', block, re.MULTILINE)
        item_id = id_m.group(1).strip() if id_m else 'unknown'
        title = title_m.group(1).strip() if title_m else (desc_m.group(1).strip()[:80] if desc_m else '')
        pending.append(f"- {item_id}: {title}")

for p in pending[:5]:
    print(p)
if len(pending) > 5:
    print(f"  ... and {len(pending)-5} more")
PYEOF
  else
    echo "(engineer-queue.md not found)"
  fi
  echo ""

  # --- Recent task-registry completions (last 5) ---
  echo "## Recently Completed Tasks"
  if [[ -f "$TASK_REGISTRY" ]]; then
    python3 - << 'PYEOF'
import json, os

registry_path = os.path.expanduser('~/helm-workspace/task-registry.jsonl')
if not os.path.exists(registry_path):
    print("(task-registry.jsonl not found)")
    exit(0)

done_entries = []
with open(registry_path) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
            if entry.get('status') in ('done', 'completed') or 'completed_at' in entry:
                done_entries.append(entry)
        except json.JSONDecodeError:
            continue

recent = done_entries[-5:]
recent.reverse()
for entry in recent:
    ts = (entry.get('shipped_at') or entry.get('completed_at') or entry.get('ts') or '')[:16]
    item_id = entry.get('id', entry.get('item_id', 'unknown'))
    summary = (entry.get('notes') or entry.get('summary') or '')[:80]
    print(f"- [{ts}] {item_id}: {summary}")
PYEOF
  else
    echo "(task-registry.jsonl not found)"
  fi
  echo ""

  # --- Blocked work items ---
  echo "## Blocked Items (need decision)"
  if [[ -f "$WORK_ITEMS" ]]; then
    python3 - << 'PYEOF'
import json, os

wi_path = os.path.expanduser('~/helm-workspace/system/work-items.json')
if not os.path.exists(wi_path):
    print("(none)")
    exit(0)

try:
    with open(wi_path) as f:
        data = json.load(f)
    items = data if isinstance(data, list) else data.get('items', [])
    blocked = [i for i in items if i.get('status') == 'blocked']
    if not blocked:
        print("(none)")
    else:
        for item in blocked[:3]:
            item_id = item.get('id', 'unknown')
            title = item.get('title', item.get('description', ''))[:80]
            print(f"- {item_id}: {title}")
except Exception:
    print("(error reading work-items.json)")
PYEOF
  else
    echo "(none)"
  fi
  echo ""

  # --- Top friction patterns (last 5 from friction-log, last 7 days) ---
  echo "## Top Friction Patterns (7d)"
  if [[ -f "$FRICTION_LOG" ]]; then
    python3 - << 'PYEOF'
import re, os
from datetime import datetime, timezone, timedelta
from collections import Counter

log_path = os.path.expanduser('~/helm-workspace/system/friction-log.md')
cutoff = datetime.now(timezone.utc) - timedelta(days=7)

behavior_counts = Counter()
with open(log_path) as f:
    for line in f:
        line = line.strip()
        if not line.startswith('['):
            continue
        m = re.match(r'\[(\d{4}-\d{2}-\d{2}T[\d:.]+Z)\]\s+(\S+)', line)
        if not m:
            continue
        ts_str, behavior = m.groups()
        try:
            ts = datetime.fromisoformat(ts_str.replace('Z', '+00:00'))
        except ValueError:
            continue
        if ts >= cutoff:
            behavior_counts[behavior] += 1

if not behavior_counts:
    print("(no violations in last 7 days)")
else:
    for behavior, count in behavior_counts.most_common(5):
        print(f"- {behavior}: {count}x")
PYEOF
  else
    echo "(friction-log.md not found)"
  fi
}

# Write to CONTEXT.md atomically
build_context > "${CONTEXT_FILE}.tmp"
mv "${CONTEXT_FILE}.tmp" "$CONTEXT_FILE"

# Log refresh to marvin.log (debug)
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] context-cache refreshed: $(wc -l < "$CONTEXT_FILE") lines" >> "$HOME/marvin-bot/marvin.log" 2>/dev/null || true
