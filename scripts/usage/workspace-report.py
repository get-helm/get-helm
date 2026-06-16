#!/usr/bin/env python3
"""workspace-report.py
Reads event-stream.jsonl and produces per-workspace invocation counts
with week-over-week trend. Optionally combines with Claude.ai scrape result.
Output: JSON to stdout + Discord-ready text.
"""

import json
import os
import sys
import urllib.request
from datetime import datetime, timezone, timedelta
from collections import defaultdict

EVENT_STREAM = os.path.expanduser("~/pap-workspace/event-stream.jsonl")
DAILY_TOKEN_SUMMARY = os.path.expanduser("~/pap-workspace/scripts/usage/daily-token-summary.json")
CLAUDE_RESULT = os.path.expanduser("~/pap-workspace/scripts/usage/last-result.json")
ENV_FILE = os.path.expanduser("~/marvin-bot/.env")
GUILD_ID = "{{USER_DISCORD_SERVER_ID}}"

# System/infra channels to always exclude from the report
EXCLUDE_CHANNELS = {
    "{{USER_CHANNEL_HELM_AUDIT}}",  # pap-audit
    "1504126943669260403",  # daily-brief
    "1499287733007421611",  # new-workspace
    "1500203712692486326",  # capture
    "{{USER_CHANNEL_HELM_STATUS}}",  # pap-status
}


def load_bot_token():
    if not os.path.exists(ENV_FILE):
        return None
    with open(ENV_FILE) as f:
        for line in f:
            if line.startswith("DISCORD_BOT_TOKEN="):
                return line.strip().split("=", 1)[1]
    return None


def fetch_live_channel_names():
    """Fetch current channel names from Discord API. Returns id->name dict."""
    token = load_bot_token()
    if not token:
        return {}
    try:
        req = urllib.request.Request(
            f"https://discord.com/api/v10/guilds/{GUILD_ID}/channels",
            headers={"Authorization": f"Bot {token}"},
        )
        with urllib.request.urlopen(req, timeout=5) as resp:
            channels = json.loads(resp.read())
        if isinstance(channels, list):
            return {ch["id"]: f"#{ch['name']}" for ch in channels if ch.get("name")}
    except Exception:
        pass
    return {}


def get_channel_names():
    """Merge live Discord names with fallback hardcoded map."""
    fallback = {
        "1498823989324419094": "#general",
        "1501236121399722024": "#etf-tracker",
        "1501656066340032776": "#pap-improvements-archived",
        "1502485100976144434": "#options-helper",
        "1504160847134720050": "#financial-review",
        "1504684387852222465": "#japan-2026",
        "{{USER_CHANNEL_HELM_IMPROVEMENTS}}": "#pap-improvements",
        "1505752160057561149": "#mission-control",
        "1506681614808387605": "#pap-dashboard",
        "1506681603332772053": "#pap-chat",
    }
    live = fetch_live_channel_names()
    return {**fallback, **live}  # live names win


def load_invocations(days_back=14):
    """Return dict of channelId -> list of datetime for agent_spawn events."""
    cutoff = datetime.now(timezone.utc) - timedelta(days=days_back)
    invocations = defaultdict(list)

    with open(EVENT_STREAM) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                d = json.loads(line)
            except json.JSONDecodeError:
                continue
            if d.get("type") != "agent_spawn":
                continue
            ch = d.get("channelId")
            if not ch:
                continue
            ts_str = d.get("ts", "")
            try:
                ts = datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
            except ValueError:
                continue
            if ts < cutoff:
                continue
            invocations[ch].append(ts)

    return invocations


def compute_weekly(invocations, channel_names):
    """Return per-channel counts for this week and last week.
    Only includes channels that exist in Discord (known names) and aren't excluded."""
    now = datetime.now(timezone.utc)
    this_week_start = now - timedelta(days=7)
    last_week_start = now - timedelta(days=14)

    results = {}
    for ch, timestamps in invocations.items():
        if ch in EXCLUDE_CHANNELS:
            continue
        if ch not in channel_names:
            continue  # deleted or unknown channel — skip
        this_week = sum(1 for ts in timestamps if ts >= this_week_start)
        last_week = sum(1 for ts in timestamps if last_week_start <= ts < this_week_start)
        if this_week == 0 and last_week == 0:
            continue
        results[ch] = {
            "name": channel_names[ch],
            "this_week": this_week,
            "last_week": last_week,
            "trend": this_week - last_week,
            "trend_pct": round((this_week - last_week) / last_week * 100) if last_week > 0 else None,
        }
    return results


def trend_arrow(diff, pct):
    if diff == 0:
        return "→"
    if diff > 0:
        label = f"+{diff}"
        if pct and pct > 20:
            return f"↑ {label}"
        return f"↗ {label}"
    label = f"{diff}"
    if pct and pct < -20:
        return f"↓ {label}"
    return f"↘ {label}"


def format_resets_at(iso_str):
    """Convert ISO timestamp to human-friendly 'resets in Xh' or 'resets Fri'."""
    if not iso_str:
        return ""
    try:
        ts = datetime.fromisoformat(iso_str.replace("Z", "+00:00"))
        now = datetime.now(timezone.utc)
        delta = ts - now
        hours = delta.total_seconds() / 3600
        if hours < 0:
            return "reset pending"
        if hours < 24:
            return f"resets in {int(hours)}h"
        days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        return f"resets {days[ts.weekday()]}"
    except Exception:
        return ""


def format_discord(weekly, claude_usage=None):
    lines = ["**PAP Usage Report**"]
    now_str = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%MZ")
    lines.append(f"Generated: {now_str}")
    lines.append("")

    if claude_usage:
        lines.append("**Claude.ai Subscription**")
        err = claude_usage.get("error")
        if err == "session_expired":
            lines.append("  ⚠️ Session expired — login needed")
        elif err:
            lines.append(f"  ⚠️ Fetch failed: {err}")
        elif claude_usage.get("sevenDayPct") is not None:
            five = claude_usage.get("fiveHourPct")
            seven = claude_usage.get("sevenDayPct")
            sonnet = claude_usage.get("sevenDaySonnetPct")
            five_reset = format_resets_at(claude_usage.get("fiveHourResetsAt"))
            seven_reset = format_resets_at(claude_usage.get("sevenDayResetsAt"))

            # Flag if any metric is high
            warn = "🔴 " if (seven and seven >= 80) or (sonnet and sonnet >= 80) else ("🟡 " if (seven and seven >= 60) or (sonnet and sonnet >= 60) else "")
            lines.append(f"  {warn}7-day overall: **{seven:.0f}%** ({seven_reset})")
            if sonnet is not None:
                sonnet_warn = "🔴 " if sonnet >= 80 else ("🟡 " if sonnet >= 60 else "")
                lines.append(f"  {sonnet_warn}7-day Sonnet: **{sonnet:.0f}%** ({seven_reset})")
            if five is not None:
                five_warn = "🔴 " if five >= 80 else ("🟡 " if five >= 60 else "")
                lines.append(f"  {five_warn}Current session (5hr): **{five:.0f}%** ({five_reset})")
        else:
            lines.append("  ⚠️ Usage data unavailable")
        lines.append("")

    lines.append("**Per-Workspace Invocations (This Week vs Last Week)**")

    # Sort by this_week desc
    sorted_channels = sorted(weekly.items(), key=lambda x: x[1]["this_week"], reverse=True)

    total_this = 0
    total_last = 0
    for ch, data in sorted_channels:
        arrow = trend_arrow(data["trend"], data["trend_pct"])
        lines.append(f"  {data['name']}: {data['this_week']} this wk / {data['last_week']} last wk  {arrow}")
        total_this += data["this_week"]
        total_last += data["last_week"]

    lines.append("")
    total_arrow = trend_arrow(total_this - total_last,
                              round((total_this - total_last) / total_last * 100) if total_last > 0 else None)
    lines.append(f"**Total: {total_this} this wk / {total_last} last wk  {total_arrow}**")

    # 3-line token summary excerpt from daily-token-summary.json
    try:
        if os.path.exists(DAILY_TOKEN_SUMMARY):
            ts = json.load(open(DAILY_TOKEN_SUMMARY))
            tot = ts.get("totals", {})
            top_agent = max(ts.get("by_agent_type", {}).items(), key=lambda x: x[1]["sessions"], default=(None, {}))
            lines.append("")
            lines.append("**Token Usage (24h)**")
            lines.append(f"  Sessions: {tot.get('sessions', 0)}  Cache hit: {tot.get('cache_hit_rate_pct', 0)}%")
            lines.append(f"  Output: {tot.get('output_tokens', 0):,} tokens  Created cache: {tot.get('cache_creation_input_tokens', 0):,}")
            if top_agent[0]:
                a = top_agent[1]
                lines.append(f"  Top: {top_agent[0]} ({a['sessions']} sessions, {a['cache_hit_rate_pct']}% cache hit)")
    except Exception:
        pass

    return "\n".join(lines)


def check_high_pace_alert(weekly):
    """Return alert string if today's pace is unusually high, else None."""
    now = datetime.now(timezone.utc)
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    day_of_week = now.weekday()  # 0=Mon

    total_today = 0
    total_this_week = sum(d["this_week"] for d in weekly.values())

    # Reload just for today's count (exclude system channels)
    invocations = load_invocations(days_back=1)
    for ch, timestamps in invocations.items():
        if ch in EXCLUDE_CHANNELS:
            continue
        today_count = sum(1 for ts in timestamps if ts >= today_start)
        total_today += today_count

    if total_today == 0:
        return None

    avg_daily_this_week = total_this_week / max(day_of_week + 1, 1)
    if avg_daily_this_week > 0 and total_today > avg_daily_this_week * 2 and total_today > 10:
        return f"⚠️ High pace: {total_today} invocations today vs avg {avg_daily_this_week:.0f}/day this week"
    return None


def check_sonnet_alert(claude_usage):
    """Return alert string if Sonnet 7-day usage exceeds 80%, else None."""
    if not claude_usage or claude_usage.get("error"):
        return None
    sonnet = claude_usage.get("sevenDaySonnetPct")
    if sonnet is None:
        return None
    if sonnet >= 80:
        reset = format_resets_at(claude_usage.get("sevenDayResetsAt"))
        return f"🔴 Sonnet usage at **{sonnet:.0f}%** of 7-day limit ({reset}) — PAP may hit rate limits soon"
    return None


if __name__ == "__main__":
    channel_names = get_channel_names()
    invocations = load_invocations(days_back=14)
    weekly = compute_weekly(invocations, channel_names)

    # Fetch live Claude usage via API (fast, no browser)
    claude_usage = None
    scraper_path = os.path.join(os.path.dirname(__file__), "claude-scraper.py")
    try:
        import subprocess
        res = subprocess.run(
            ["python3", scraper_path, "fetch-usage"],
            capture_output=True, text=True, timeout=15
        )
        if res.returncode == 0 and res.stdout.strip():
            claude_usage = json.loads(res.stdout.strip())
    except Exception:
        # Fall back to cached result
        if os.path.exists(CLAUDE_RESULT):
            try:
                claude_usage = json.load(open(CLAUDE_RESULT))
            except Exception:
                pass

    report = format_discord(weekly, claude_usage)
    alert = check_high_pace_alert(weekly)
    sonnet_alert = check_sonnet_alert(claude_usage)

    result = {
        "report": report,
        "alert": alert,
        "sonnet_alert": sonnet_alert,
        "weekly": weekly,
        "ts": datetime.now(timezone.utc).isoformat(),
    }

    print(json.dumps(result, indent=2, default=str))
