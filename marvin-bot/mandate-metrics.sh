#!/bin/bash
# mandate-metrics.sh — parse friction-log.md and emit per-mandate violation counts
# Output: system/mandate-metrics.json (timeseries + weekly comparison)
# Run: daily at 06:15 UTC alongside validation-metrics OR by PM T2-C sweep
# Alerts to #helm-improvements if any mandate rises >20% week-over-week
# Exit 0 always — alerts are non-blocking

set -euo pipefail

FRICTION_LOG="$HOME/helm-workspace/system/friction-log.md"
OUTPUT="$HOME/helm-workspace/system/mandate-metrics.json"
AUDIT_LOG="$HOME/helm-workspace/system/helm-audit.log"
DISCORD_POST="$HOME/marvin-bot/discord-post.sh"
HELM_IMPROVEMENTS="{{USER_CHANNEL_HELM_IMPROVEMENTS}}"
THRESHOLD="${1:-20}"  # % increase triggers alert (default 20%)

log() {
  local ts; ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  echo "[$ts] [mandate-metrics] $*" >> "$AUDIT_LOG"
}

if [[ ! -f "$FRICTION_LOG" ]]; then
  log "friction-log.md not found — skipping"
  exit 0
fi

RESULT=$(python3 - "$FRICTION_LOG" "$OUTPUT" "$THRESHOLD" << 'PYEOF'
import json, re, sys
from datetime import datetime, timezone, timedelta
from collections import defaultdict

friction_log_path = sys.argv[1]
output_path = sys.argv[2]
threshold = int(sys.argv[3])

# Pattern: [2026-06-14T01:36:09.021Z] VIOLATION_TYPE channel=...
LOG_LINE = re.compile(r'^\[(\d{4}-\d{2}-\d{2})T[\d:.]+Z\]\s+([A-Z0-9_-]+)\s*')

# Load existing output to preserve full history
existing = {}
try:
    with open(output_path) as f:
        existing = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    pass

daily = defaultdict(lambda: defaultdict(int))  # {date: {violation_type: count}}

with open(friction_log_path) as f:
    for line in f:
        m = LOG_LINE.match(line)
        if not m:
            continue
        date_str = m.group(1)
        vtype = m.group(2)
        if vtype in ('PASS',):
            continue
        daily[date_str][vtype] += 1

# Build/update timeseries
timeseries = existing.get('timeseries', {})
for date, counts in daily.items():
    timeseries[date] = dict(counts)

# Week-over-week comparison
now = datetime.now(timezone.utc)
today = now.date()
week0_dates = [(today - timedelta(days=i)).isoformat() for i in range(7)]   # this week
week1_dates = [(today - timedelta(days=7+i)).isoformat() for i in range(7)] # prev week

def sum_week(dates):
    totals = defaultdict(int)
    for d in dates:
        for vtype, count in timeseries.get(d, {}).items():
            totals[vtype] += count
    return dict(totals)

w0 = sum_week(week0_dates)
w1 = sum_week(week1_dates)

changes = {}
alerts = []
for vtype in sorted(set(w0.keys()) | set(w1.keys())):
    c0 = w0.get(vtype, 0)
    c1 = w1.get(vtype, 0)
    pct = round((c0 - c1) / c1 * 100, 1) if c1 > 0 else None
    changes[vtype] = {'this_week': c0, 'last_week': c1, 'pct_change': pct}
    if pct is not None and pct > threshold and c0 >= 5:
        alerts.append(f"{vtype}: {c1}→{c0} (+{pct}%)")

ts = now.strftime('%Y-%m-%dT%H:%M:%SZ')
output = {
    'updated_at': ts,
    'week_over_week': changes,
    'alerts': alerts,
    'timeseries': timeseries
}

with open(output_path, 'w') as f:
    json.dump(output, f, indent=2)
    f.write('\n')

if alerts:
    print('ALERTS:' + '|'.join(alerts))
else:
    print('OK')
PYEOF
)

if [[ "$RESULT" == ALERTS:* ]]; then
  ALERT_LIST="${RESULT#ALERTS:}"
  FORMATTED=$(echo "$ALERT_LIST" | tr '|' '\n' | sed 's/^/  - /')
  log "Week-over-week mandate spike: $ALERT_LIST"
  "$DISCORD_POST" "$HELM_IMPROVEMENTS" "📊 Mandate violation spike (>$THRESHOLD% week-over-week):
$FORMATTED

PM: investigate root cause and queue engineer fix if structural."
else
  log "Week-over-week check clean — no mandate spikes"
fi
