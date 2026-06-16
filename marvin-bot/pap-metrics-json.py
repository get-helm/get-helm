#!/usr/bin/env python3
# pap-metrics-json.py — 24h event metrics as JSON for status dashboard
# Called by VPS generate-status.sh via SSH. Outputs JSON to stdout.

import json
import os
from datetime import datetime, timezone, timedelta

EVENT_STREAM = os.path.expanduser("~/pap-workspace/event-stream.jsonl")
CHANNEL_NAMES = {
    "1498823989324419094": "#general",
    "1499287733007421611": "#new-workspace",
    "1500203712692486326": "#capture",
    "{{USER_CHANNEL_HELM_STATUS}}": "#pap-status",
    "1501236121399722024": "#etf-tracker",
    "1501656066340032776": "#pap-improvements",
    "{{USER_CHANNEL_HELM_AUDIT}}": "#pap-audit",
    "1502485100976144434": "#options-helper",
    "1504126943669260403": "#daily-brief",
    "1504160847134720050": "#financial-review",
    "1504684387852222465": "#japan-trip",
    "{{USER_CHANNEL_HELM_IMPROVEMENTS}}": "#pap-chat",
}

cutoff = (datetime.now(timezone.utc) - timedelta(hours=24)).timestamp()
totals = {}
per_channel = {}

try:
    with open(EVENT_STREAM) as f:
        for line in f:
            try:
                e = json.loads(line)
                ts_raw = e.get("ts") or e.get("timestamp", 0)
                if isinstance(ts_raw, str):
                    try:
                        ts = datetime.fromisoformat(ts_raw.replace("Z", "+00:00")).timestamp()
                    except Exception:
                        ts = 0
                else:
                    ts = float(ts_raw) if ts_raw else 0
                if ts < cutoff:
                    continue
                t = e.get("type", "")
                totals[t] = totals.get(t, 0) + 1
                ch = e.get("channelId", "") or e.get("channel_id", "")
                if ch:
                    name = CHANNEL_NAMES.get(ch, ch[-6:])
                    if name not in per_channel:
                        per_channel[name] = {}
                    per_channel[name][t] = per_channel[name].get(t, 0) + 1
            except Exception:
                pass
except Exception:
    pass

print(json.dumps({"totals": totals, "per_channel": per_channel}))
