#!/usr/bin/env python3
# pap-metrics.py — per-channel metrics summary from event-stream.jsonl
# Posts plain-text summary to #pap-improvements
# TD-05 (babysitting ratio added in Session 61)

import json
import os
import sys
from datetime import datetime, timezone, timedelta
from collections import defaultdict

EVENT_STREAM = os.path.expanduser("~/pap-workspace/event-stream.jsonl")
PAP_IMPROVEMENTS_CHANNEL = "{{USER_CHANNEL_HELM_AUDIT}}"  # pap-audit (internal metrics)
DAYS = 7
TRIGGER_WINDOW_SEC = 120  # 2 min window to classify spawn as {{USER_JERRY}}-triggered

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

TRACKED = [
    "agent_spawn", "timeout_warn", "timeout_kill",
    "deliver_validated", "validation_failure", "ack_warn", "ack_kill"
]


def load_env():
    env_path = os.path.expanduser("~/marvin-bot/.env")
    with open(env_path) as f:
        for line in f:
            line = line.strip()
            if line.startswith("DISCORD_BOT_TOKEN="):
                return line.split("=", 1)[1].strip()
    raise ValueError("DISCORD_BOT_TOKEN not found in .env")


def read_events(days=7):
    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    counts = defaultdict(lambda: defaultdict(int))
    totals = defaultdict(int)

    # For babysitting ratio: track last user_message ts per channel
    last_user_msg = {}  # channelId -> datetime
    # Per-channel babysit counts
    babysit = defaultdict(lambda: {"owner": 0, "auto": 0})

    # We need two passes: one to collect all events in order, then classify spawns
    events = []
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
            if ts < cutoff:
                continue
            events.append((ts, d))

    # Sort by time (should already be in order, but defensive)
    events.sort(key=lambda x: x[0])

    for ts, d in events:
        ch = d.get("channelId")
        t = d.get("type", "")

        if t == "user_message" and ch:
            last_user_msg[ch] = ts

        if t == "agent_spawn" and ch:
            last_msg_ts = last_user_msg.get(ch)
            if last_msg_ts and (ts - last_msg_ts).total_seconds() <= TRIGGER_WINDOW_SEC:
                babysit[ch]["owner"] += 1
            else:
                babysit[ch]["auto"] += 1

        if t in TRACKED and ch:
            counts[ch][t] += 1
            totals[t] += 1

    return counts, totals, babysit


def build_summary(counts, totals, babysit):
    lines = []
    lines.append(f"PAP Metrics — Last {DAYS} Days")
    lines.append(f"Generated: {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%MZ')}")
    lines.append("")

    sorted_channels = sorted(
        counts.keys(),
        key=lambda c: counts[c].get("agent_spawn", 0),
        reverse=True
    )

    total_owner = 0
    total_auto = 0

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

        owner = babysit[ch]["owner"]
        auto = babysit[ch]["auto"]
        total_owner += owner
        total_auto += auto
        auto_pct = f"{int(auto / (owner + auto) * 100)}%" if (owner + auto) > 0 else "n/a"

        deliver_rate = f"{int(delivers/spawns*100)}%" if spawns > 0 else "n/a"

        row = f"{name}: spawns={spawns}, delivers={delivers} ({deliver_rate}), auto={auto_pct}"
        if twarn or tkill:
            row += f", timeout(warn={twarn} kill={tkill})"
        if ackwarn or ackkill:
            row += f", ack(warn={ackwarn} kill={ackkill})"
        if fail:
            row += f", val_fail={fail}"
        lines.append(row)

    lines.append("")
    total_spawns = total_owner + total_auto
    global_auto_pct = f"{int(total_auto / total_spawns * 100)}%" if total_spawns > 0 else "n/a"
    lines.append(
        f"Totals: spawns={totals['agent_spawn']} | delivers={totals['deliver_validated']} | "
        f"t_kill={totals['timeout_kill']} | val_fail={totals['validation_failure']} | "
        f"ack_kill={totals['ack_kill']}"
    )
    lines.append(
        f"Babysitting ratio: owner-triggered={total_owner}, autonomous={total_auto}, "
        f"auto_pct={global_auto_pct}"
    )
    lines.append("(auto = PM sweeps, cron triggers, auto-resume, engineer queue; owner = spawn within 2min of user message)")

    return "\n".join(lines)


def post_to_discord(token, channel_id, content):
    import subprocess
    msg = f"```\n{content}\n```"
    if len(msg) > 2000:
        msg = msg[:1990] + "\n```"
    env = os.environ.copy()
    env["DISCORD_BOT_TOKEN"] = token
    result = subprocess.run(
        [os.path.expanduser("~/marvin-bot/discord-post.sh"), channel_id, msg],
        env=env,
        capture_output=True,
        text=True
    )
    if result.returncode != 0:
        raise RuntimeError(f"discord-post.sh failed: {result.stderr}")
    return "ok"


if __name__ == "__main__":
    token = load_env()
    counts, totals, babysit = read_events(DAYS)
    summary = build_summary(counts, totals, babysit)
    print(summary)
    print()
    msg_id = post_to_discord(token, PAP_IMPROVEMENTS_CHANNEL, summary)
    print(f"Posted to #pap-improvements: message ID {msg_id}")
