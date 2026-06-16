#!/usr/bin/env python3
"""
value-metrics.py — PAP VALUE-01 nightly metrics
Computes 3 locked metrics and writes to ~/pap-workspace/value-metrics.json
On Mondays: posts weekly trend summary to pap-improvements

Metrics:
  1. task_completion_rate — % of ACK sessions in last 7 days that reached DELIVER
  2. pm_proactivity_ratio — % of PM turns that were schedule/sweep-triggered (unprompted)
  3. error_recurrence_rate — count of friction-log violation types across 3+ distinct days
"""

import json
import os
import re
import sys
from datetime import datetime, timezone, timedelta
from collections import defaultdict
import urllib.request
import urllib.error

EVENT_STREAM    = os.path.expanduser("~/pap-workspace/event-stream.jsonl")
FRICTION_LOG    = os.path.expanduser("~/pap-workspace/friction-log.md")
DECISIONS_LOG   = os.path.expanduser("~/pap-workspace/decisions-log.md")
METRICS_OUT     = os.path.expanduser("~/pap-workspace/value-metrics.json")
IMPROVEMENTS_CH = "{{USER_CHANNEL_HELM_IMPROVEMENTS}}"
ENV_PATH        = os.path.expanduser("~/marvin-bot/.env")
DAYS            = 7


def load_token():
    with open(ENV_PATH) as f:
        for line in f:
            if line.startswith("DISCORD_BOT_TOKEN="):
                return line.split("=", 1)[1].strip()
    raise ValueError("DISCORD_BOT_TOKEN not in .env")


def post_discord(channel_id, text):
    token = load_token()
    url = f"https://discord.com/api/v10/channels/{channel_id}/messages"
    payload = json.dumps({"content": text}).encode()
    req = urllib.request.Request(url, data=payload, headers={
        "Authorization": f"Bot {token}",
        "Content-Type": "application/json",
    })
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            return r.status == 200
    except urllib.error.URLError:
        return False


def parse_iso(ts_str):
    try:
        return datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
    except (ValueError, AttributeError):
        return None


# ── Metric 1: Task completion rate ───────────────────────────────────────────
def compute_completion_rate(days=7):
    """ACK sessions that reached deliver_validated / total ACK sessions."""
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    ack_count = 0
    deliver_count = 0

    with open(EVENT_STREAM) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                d = json.loads(line)
            except json.JSONDecodeError:
                continue
            ts = parse_iso(d.get("ts", ""))
            if not ts or ts < cutoff:
                continue
            t = d.get("type", "")
            phase = d.get("agentPhase", "")
            if t == "agent_message" and phase == "ack":
                ack_count += 1
            elif t == "deliver_validated":
                deliver_count += 1

    rate = round(deliver_count / ack_count, 3) if ack_count else 0.0
    return {"ack_count": ack_count, "deliver_count": deliver_count, "rate": rate}


# ── Metric 2: PM proactivity ratio ──────────────────────────────────────────
def compute_pm_proactivity(days=7):
    """% of PM turns with schedule/sweep/heartbeat trigger (unprompted) in last N days."""
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    unprompted = 0
    prompted = 0
    current_date = None

    # Parse decisions-log.md
    # Headers: ## 2026-05-22 16:37:00
    # Trigger: schedule / sweep / deliver / mention / idle-skip
    date_re = re.compile(r"^## (\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2})")
    trigger_re = re.compile(r"^Trigger:\s*(\S+)")

    if not os.path.exists(DECISIONS_LOG):
        return {"unprompted": 0, "prompted": 0, "ratio": 0.0}

    with open(DECISIONS_LOG) as f:
        for line in f:
            line = line.rstrip()
            m = date_re.match(line)
            if m:
                ts = parse_iso(m.group(1).replace(" ", "T") + ":00Z")
                current_date = ts
                continue
            m = trigger_re.match(line)
            if m and current_date and current_date >= cutoff:
                trigger = m.group(1).lower()
                if trigger in ("schedule", "sweep", "heartbeat", "idle-skip", "idle"):
                    unprompted += 1
                elif trigger in ("deliver", "mention", "user", "manual"):
                    prompted += 1
                # "schedule (user message present)" → still unprompted

    total = unprompted + prompted
    ratio = round(unprompted / total, 3) if total else 0.0
    return {"unprompted": unprompted, "prompted": prompted, "total": total, "ratio": ratio}


# ── Metric 3: Error recurrence rate ─────────────────────────────────────────
def compute_error_recurrence(days=7):
    """Count of friction-log violation types appearing on 3+ distinct days in last N days."""
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    # Maps type → set of day strings
    type_days = defaultdict(set)

    # New-style entries: [2026-05-22T20:26:42.247Z] TYPE_NAME channel=...
    new_style = re.compile(r"^\[(\d{4}-\d{2}-\d{2}T[^]]+)\]\s+([A-Z_a-z-]+)")
    # Old-style: ## 2026-05-09 07:00:00 — Description
    old_style = re.compile(r"^## (\d{4}-\d{2}-\d{2})")

    if not os.path.exists(FRICTION_LOG):
        return {"recurring_types": [], "count": 0, "details": {}}

    with open(FRICTION_LOG) as f:
        for line in f:
            line = line.rstrip()
            m = new_style.match(line)
            if m:
                ts = parse_iso(m.group(1))
                if ts and ts >= cutoff:
                    vtype = m.group(2)
                    day = ts.strftime("%Y-%m-%d")
                    type_days[vtype].add(day)
                continue
            m = old_style.match(line)
            if m:
                day = m.group(1)
                ts = parse_iso(day + "T00:00:00Z")
                if ts and ts >= cutoff:
                    type_days["legacy_entry"].add(day)

    recurring = {t: sorted(days_set) for t, days_set in type_days.items() if len(days_set) >= 3}
    return {
        "recurring_types": list(recurring.keys()),
        "count": len(recurring),
        "details": recurring,
    }


# ── Prior-period comparison (7-day trend) ───────────────────────────────────
def compute_prior_period():
    """Compute completion rate for 8-14 days ago for trend comparison."""
    older_cutoff = datetime.now(timezone.utc) - timedelta(days=14)
    recent_cutoff = datetime.now(timezone.utc) - timedelta(days=7)
    ack = 0
    dlv = 0
    with open(EVENT_STREAM) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                d = json.loads(line)
            except json.JSONDecodeError:
                continue
            ts = parse_iso(d.get("ts", ""))
            if not ts or ts < older_cutoff or ts >= recent_cutoff:
                continue
            t = d.get("type", "")
            phase = d.get("agentPhase", "")
            if t == "agent_message" and phase == "ack":
                ack += 1
            elif t == "deliver_validated":
                dlv += 1
    return round(dlv / ack, 3) if ack else 0.0


def main():
    now = datetime.now(timezone.utc)
    is_monday = now.weekday() == 0

    print(f"[value-metrics] running at {now.isoformat()}")

    completion = compute_completion_rate(DAYS)
    proactivity = compute_pm_proactivity(DAYS)
    recurrence = compute_error_recurrence(DAYS)
    prior_completion_rate = compute_prior_period()

    completion_trend = round(completion["rate"] - prior_completion_rate, 3)

    metrics = {
        "generated_at": now.isoformat(),
        "window_days": DAYS,
        "task_completion_rate": {
            "rate": completion["rate"],
            "rate_pct": f"{completion['rate']*100:.1f}%",
            "ack_count": completion["ack_count"],
            "deliver_count": completion["deliver_count"],
            "prior_period_rate": prior_completion_rate,
            "trend": completion_trend,
            "trend_label": ("▲" if completion_trend > 0.01 else ("▼" if completion_trend < -0.01 else "→")),
        },
        "pm_proactivity_ratio": {
            "ratio": proactivity["ratio"],
            "ratio_pct": f"{proactivity['ratio']*100:.1f}%",
            "unprompted_turns": proactivity["unprompted"],
            "prompted_turns": proactivity["prompted"],
            "total_pm_turns": proactivity.get("total", 0),
        },
        "error_recurrence": {
            "recurring_type_count": recurrence["count"],
            "recurring_types": recurrence["recurring_types"],
            "details": recurrence["details"],
        },
    }

    # Write JSON
    with open(METRICS_OUT, "w") as f:
        json.dump(metrics, f, indent=2)
    print(f"[value-metrics] written to {METRICS_OUT}")
    print(f"  completion_rate={metrics['task_completion_rate']['rate_pct']} "
          f"({completion['deliver_count']}/{completion['ack_count']}) "
          f"trend={metrics['task_completion_rate']['trend_label']}")
    print(f"  pm_proactivity={metrics['pm_proactivity_ratio']['ratio_pct']} "
          f"({proactivity['unprompted']}/{proactivity.get('total', 0)} turns unprompted)")
    print(f"  error_recurrence={recurrence['count']} types recurring 3+ days")

    # Monday weekly trend post to pap-improvements
    if is_monday:
        rate_pct = metrics["task_completion_rate"]["rate_pct"]
        trend = metrics["task_completion_rate"]["trend_label"]
        pm_pct = metrics["pm_proactivity_ratio"]["ratio_pct"]
        recurring_n = recurrence["count"]
        recurring_list = ", ".join(recurrence["recurring_types"][:3]) or "none"
        msg = (
            f"📊 **Weekly PAP Health — {now.strftime('%b %d')}**\n"
            f"Task completion: {rate_pct} {trend} (vs prior week)\n"
            f"PM proactivity: {pm_pct} of PM turns were schedule-triggered\n"
            f"Error recurrence: {recurring_n} violation type(s) seen 3+ days — {recurring_list}\n"
            f"Full data: ~/pap-workspace/value-metrics.json"
        )
        ok = post_discord(IMPROVEMENTS_CH, msg)
        print(f"[value-metrics] Monday post to pap-improvements: {'OK' if ok else 'FAILED'}")

    return metrics


if __name__ == "__main__":
    main()
