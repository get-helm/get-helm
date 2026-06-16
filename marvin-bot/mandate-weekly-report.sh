#!/usr/bin/env bash
# mandate-weekly-report.sh — Per-mandate compliance table for PM weekly sweep
set -euo pipefail

WORKDIR="${HOME}/helm-workspace"
MARVIN="${HOME}/marvin-bot"
METRICS="${WORKDIR}/system/mandate-metrics.json"
MAP="${MARVIN}/mandate-map.json"
COUNTS="${WORKDIR}/system/reflect-counts.jsonl"

if [[ ! -f "$METRICS" ]]; then echo "No mandate-metrics.json found"; exit 0; fi

python3 - <<'PYEOF'
import json, os, sys
from datetime import datetime, timedelta
from pathlib import Path
from collections import defaultdict

WORKDIR = Path(os.environ['HOME']) / 'helm-workspace'
MARVIN = Path(os.environ['HOME']) / 'marvin-bot'
metrics_path = WORKDIR / 'system' / 'mandate-metrics.json'
map_path = MARVIN / 'mandate-map.json'
counts_path = WORKDIR / 'system' / 'reflect-counts.jsonl'

try:
    metrics = json.loads(metrics_path.read_text())
except:
    print("No metrics found"); sys.exit(0)

try:
    vcode_to_mandate = json.loads(map_path.read_text())
except:
    vcode_to_mandate = {}

# Count scans this week vs last week
now = datetime.utcnow()
this_week_start = (now - timedelta(days=7)).strftime('%Y-%m-%d')
last_week_start = (now - timedelta(days=14)).strftime('%Y-%m-%d')

this_week_scans = 0
last_week_scans = 0
try:
    for line in counts_path.read_text().splitlines():
        try:
            entry = json.loads(line)
            d = entry.get('date','')
            if d >= this_week_start:
                this_week_scans += 1
            elif d >= last_week_start:
                last_week_scans += 1
        except:
            pass
except:
    pass

# Aggregate violations by mandate per week
mandate_this = defaultdict(int)
mandate_last = defaultdict(int)

for entry in metrics.get('daily', []):
    day = entry.get('date', '')
    violations = entry.get('violations', {})
    for vcode, count in violations.items():
        mandate = vcode_to_mandate.get(vcode, f'?{vcode}')
        if day >= this_week_start:
            mandate_this[mandate] += count
        elif day >= last_week_start:
            mandate_last[mandate] += count

# Build sorted list
all_mandates = sorted(set(list(mandate_this.keys()) + list(mandate_last.keys())))
rows = []
for m in all_mandates:
    this_v = mandate_this.get(m, 0)
    last_v = mandate_last.get(m, 0)
    trend = '→' if this_v == last_v else ('↓' if this_v < last_v else '↑')
    comp_pct = ''
    if this_week_scans > 0 and not m.startswith('?'):
        comp = max(0, 100 - round(100 * this_v / this_week_scans))
        comp_pct = f'{comp}%'
    rows.append((this_v, m, this_v, last_v, trend, comp_pct))

rows.sort(reverse=True)

print(f"## Mandate Compliance — Week of {this_week_start}")
print(f"Scans this week: {this_week_scans} | Last week: {last_week_scans}")
print()
print(f"{'Mandate':<12} {'This Wk':>8} {'Last Wk':>8} {'Trend':>6} {'Compliance':>12}")
print('-' * 55)
for _, m, this_v, last_v, trend, comp in rows[:15]:
    print(f"{m:<12} {this_v:>8} {last_v:>8} {trend:>6} {comp:>12}")

print()
# Top 5 by violation count
top5 = sorted(rows, reverse=True)[:5]
print("Top 5 this week:")
for _, m, this_v, *_ in top5:
    print(f"  {m}: {this_v} violations")

# Most improved (biggest drop)
improved = [(last-this, m) for _, m, this, last, *_ in rows if last > 0 and this < last]
improved.sort(reverse=True)
if improved:
    print("\nMost improved (3):")
    for delta, m in improved[:3]:
        print(f"  {m}: -{delta} violations")
PYEOF
