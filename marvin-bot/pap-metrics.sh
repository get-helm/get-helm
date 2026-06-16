#!/bin/bash
# pap-metrics.sh — per-channel metrics summary from event-stream.jsonl
# Posts plain-text summary to #pap-improvements
# TD-05

set -e

CHANNEL_IDS="{{USER_CHANNEL_HELM_AUDIT}}"  # #pap-audit (internal metrics)
EVENT_STREAM="$HOME/helm-workspace/event-stream.jsonl"

if [[ ! -f "$EVENT_STREAM" ]]; then
  echo "ERROR: event-stream.jsonl not found at $EVENT_STREAM"
  exit 1
fi

export $(grep DISCORD_BOT_TOKEN ~/marvin-bot/.env)

SUMMARY=$(python3 << 'PYEOF'
import json
from datetime import datetime, timezone, timedelta
from collections import defaultdict

EVENT_STREAM = "/Users/{{USER_HOME}}/helm-workspace/event-stream.jsonl"
CUTOFF = datetime.now(timezone.utc) - timedelta(days=7)

# Channel name map (known channels)
CHANNEL_NAMES = {
    "{{USER_CHANNEL_GENERAL}}": "#general",
    "1499287733007421611": "#new-workspace",
    "1500203712692486326": "#capture",
    "{{USER_CHANNEL_HELM_STATUS}}": "#pap-status",
    "{{USER_CHANNEL_ETF_TRACKER}}": "#etf-tracker",
    "1501656066340032776": "#pap-improvements-archived",
    "{{USER_CHANNEL_HELM_AUDIT}}": "#pap-audit",
    "{{USER_CHANNEL_OPTIONS_HELPER}}": "#options-helper",
    "1504126943669260403": "#daily-brief",
    "1504160847134720050": "#financial-review",
    "1504684387852222465": "#japan-trip",
    "{{USER_CHANNEL_HELM_IMPROVEMENTS}}": "#pap-improvements",
}

TRACKED = ["agent_spawn", "timeout_warn", "timeout_kill", "deliver_validated", "validation_failure", "ack_warn", "ack_kill"]

counts = defaultdict(lambda: defaultdict(int))
totals = defaultdict(int)

with open(EVENT_STREAM) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            d = json.loads(line)
        except json.JSONDecodeError:
            continue
        ts_str = d.get("ts", "")
        if not ts_str:
            continue
        try:
            ts = datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
        except ValueError:
            continue
        if ts < CUTOFF:
            continue
        ch = d.get("channelId", "unknown")
        t = d.get("type", "")
        if t in TRACKED:
            counts[ch][t] += 1
            totals[t] += 1

lines = []
lines.append("PAP Metrics — Last 7 Days")
lines.append(f"Generated: {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%MZ')}")
lines.append("")

# Sort channels by spawn count descending
sorted_channels = sorted(counts.keys(), key=lambda c: counts[c].get("agent_spawn", 0), reverse=True)

for ch in sorted_channels:
    name = CHANNEL_NAMES.get(ch, f"ch:{ch[-6:]}")
    c = counts[ch]
    spawns = c.get("agent_spawn", 0)
    delivers = c.get("deliver_validated", 0)
    fail = c.get("validation_failure", 0)
    twarn = c.get("timeout_warn", 0)
    tkill = c.get("timeout_kill", 0)
    ackwarn = c.get("ack_warn", 0)
    ackkill = c.get("ack_kill", 0)

    deliver_rate = f"{int(delivers/spawns*100)}%" if spawns > 0 else "n/a"

    parts = [f"{name}:"]
    parts.append(f"  spawns={spawns}, delivers={delivers} ({deliver_rate})")
    if twarn or tkill:
        parts.append(f"  timeouts: warn={twarn}, kill={tkill}")
    if ackwarn or ackkill:
        parts.append(f"  ack: warn={ackwarn}, kill={ackkill}")
    if fail:
        parts.append(f"  validation_fail={fail}")
    lines.append("\n".join(parts))

lines.append("")
lines.append(f"Totals: spawns={totals['agent_spawn']}, delivers={totals['deliver_validated']}, timeout_kill={totals['timeout_kill']}, validation_fail={totals['validation_failure']}")

print("\n".join(lines))
PYEOF
)

if [[ -z "$SUMMARY" ]]; then
  echo "ERROR: metrics script produced no output"
  exit 1
fi

# Write metrics to helm-audit.log (helm-audit channel retired per channel-consolidation directive)
HELM_AUDIT_LOG=~/helm-workspace/system/helm-audit.log
_ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
printf '[%s] [metrics] %s\n\n' "$_ts" "$SUMMARY" >> "$HELM_AUDIT_LOG" 2>/dev/null || true

echo "Done. Metrics written to helm-audit.log."
