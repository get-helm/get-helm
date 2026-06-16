#!/usr/bin/env bash
# generate-task-board.sh — rebuild TASK-BOARD.md from task-ledger.jsonl
# Called by task-event.sh after every ledger append, and on bot startup.
# Output: ~/helm-workspace/system/TASK-BOARD.md

set -euo pipefail

LEDGER="$HOME/helm-workspace/system/task-ledger.jsonl"
BOARD="$HOME/helm-workspace/system/TASK-BOARD.md"

python3 << 'PYEOF'
import json, os, sys, datetime

HOME = os.path.expanduser("~")
LEDGER = os.path.join(HOME, "helm-workspace", "system", "task-ledger.jsonl")
BOARD  = os.path.join(HOME, "helm-workspace", "system", "TASK-BOARD.md")

if not os.path.exists(LEDGER):
    sys.exit(0)

# Load all events, group by task_id
events_by_task = {}  # task_id -> list of events (ordered)
with open(LEDGER) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            ev = json.loads(line)
            tid = ev.get("task_id", "")
            if tid:
                events_by_task.setdefault(tid, []).append(ev)
        except json.JSONDecodeError:
            pass

# Derive current state for each task (last event wins within a state machine)
# State machine: created → queued → picked_up → done_claimed → verified
#                          ↓              ↓
#                       shelved        blocked → unblocked → picked_up
STATE_ORDER = {
    "created": 0, "spec_written": 1, "approved": 2, "queued": 3,
    "picked_up": 4, "progress": 5, "blocked": 4,
    "unblocked": 4, "done_claimed": 6, "verified": 7, "shelved": -1, "reopened": 3
}

# Active final-state events by task
task_state = {}
for tid, evs in events_by_task.items():
    latest = None
    for ev in evs:
        evt = ev.get("event", "")
        ts  = ev.get("ts", "")
        if latest is None or STATE_ORDER.get(evt, -1) >= STATE_ORDER.get(latest.get("event", ""), -1):
            if evt not in ("progress",):  # progress doesn't change state
                latest = ev
        # Track latest progress separately
    if latest:
        task_state[tid] = {
            "id": tid,
            "state": latest.get("event"),
            "ts": latest.get("ts"),
            "detail": latest.get("detail", ""),
            "actor": latest.get("actor", ""),
            "workspace": latest.get("workspace", "platform"),
            "evidence": latest.get("evidence", ""),
        }

now = datetime.datetime.utcnow()
one_week_ago = (now - datetime.timedelta(days=7)).isoformat() + "Z"

running = []
blocked = []
queued  = []
done_week = []
shelved = []

for tid, st in task_state.items():
    s = st["state"]
    if s in ("picked_up", "unblocked", "progress"):
        running.append(st)
    elif s == "blocked":
        blocked.append(st)
    elif s in ("queued", "approved", "reopened"):
        queued.append(st)
    elif s in ("done_claimed", "verified") and st["ts"] >= one_week_ago:
        done_week.append(st)
    elif s in ("done_claimed", "verified"):
        pass  # older done items omitted for brevity
    elif s == "shelved":
        shelved.append(st)
    elif s in ("created", "spec_written"):
        queued.append(st)  # treat concept-stage as queued

def fmt_row(st):
    detail = st["detail"][:60] + ("…" if len(st["detail"]) > 60 else "")
    ts_short = st["ts"][:10] if st["ts"] else "?"
    return f"- **{st['id']}** | {detail or '(no detail)'} | {ts_short}"

lines = [
    f"# TASK-BOARD",
    f"_Generated {now.strftime('%Y-%m-%d %H:%M')} UTC — do not edit, auto-regenerated_",
    "",
]

lines.append(f"## 🔄 Running Now ({len(running)})")
if running:
    for st in sorted(running, key=lambda x: x["ts"], reverse=True):
        lines.append(fmt_row(st))
else:
    lines.append("- (none)")
lines.append("")

lines.append(f"## ⛔ Blocked ({len(blocked)})")
if blocked:
    for st in sorted(blocked, key=lambda x: x["ts"], reverse=True):
        lines.append(fmt_row(st))
else:
    lines.append("- (none)")
lines.append("")

lines.append(f"## 📋 Queued ({len(queued)})")
if queued:
    for st in sorted(queued, key=lambda x: x["ts"]):
        lines.append(fmt_row(st))
else:
    lines.append("- (none)")
lines.append("")

lines.append(f"## ✅ Done This Week ({len(done_week)})")
if done_week:
    for st in sorted(done_week, key=lambda x: x["ts"], reverse=True):
        lines.append(fmt_row(st))
else:
    lines.append("- (none)")
lines.append("")

with open(BOARD, "w") as f:
    f.write("\n".join(lines) + "\n")

print(f"✓ TASK-BOARD.md written: {len(running)} running, {len(blocked)} blocked, {len(queued)} queued, {len(done_week)} done this week")
PYEOF
