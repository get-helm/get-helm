#!/usr/bin/env python3
"""weekly-friction-review.py — ENG-PM-PATTERN-SURFACING

Runs weekly (Mondays 15:00 UTC / 8am PT). Reads friction-log.md for last 7 days,
groups by behavior type, escalates patterns with 3+ occurrences to engineer queue
with suggested gate fix. Surfaces patterns, not individual incidents.
"""
import json, os, re, subprocess, sys
from datetime import datetime, timezone, timedelta
from collections import Counter, defaultdict

FRICTION_LOG  = os.path.expanduser('~/pap-workspace/friction-log.md')
DECISIONS_LOG = os.path.expanduser('~/pap-workspace/decisions-log.md')
LOG_DIR       = os.path.expanduser('~/pap-workspace/logs')
HELM_IMPROVEMENTS = '{{USER_CHANNEL_HELM_IMPROVEMENTS}}'
PATTERN_THRESHOLD = 3  # occurrences in 7 days to qualify for engineer queue


def post_discord(channel_id, message):
    discord_post_sh = os.path.expanduser('~/marvin-bot/discord-post.sh')
    try:
        result = subprocess.run(
            [discord_post_sh, channel_id, message],
            capture_output=True, text=True, timeout=15
        )
        if result.returncode != 0:
            print(f'Discord post failed: {result.stderr}', file=sys.stderr)
    except Exception as e:
        print(f'Discord post failed: {e}', file=sys.stderr)


def parse_friction_log(hours=168):
    """Return list of dicts {behavior, channel, ts} for last N hours."""
    cutoff = datetime.now(timezone.utc) - timedelta(hours=hours)
    entries = []
    if not os.path.exists(FRICTION_LOG):
        return entries
    with open(FRICTION_LOG) as f:
        for line in f:
            line = line.strip()
            if not line.startswith('['):
                continue
            m = re.match(r'\[(\d{4}-\d{2}-\d{2}T[\d:.]+Z)\]\s+(\S+)\s+channel=(\S+)', line)
            if not m:
                continue
            ts_str, behavior, channel = m.groups()
            try:
                ts = datetime.fromisoformat(ts_str.replace('Z', '+00:00'))
            except ValueError:
                continue
            if ts >= cutoff:
                entries.append({'ts': ts, 'behavior': behavior, 'channel': channel})
    return entries


def queue_engineer_fix(behavior, count, channels, week_str):
    """Queue an engineer task for a recurring weekly friction pattern."""
    item_id = f'FRICTION-WEEKLY-{behavior}-{week_str}'
    channel_list = ', '.join(sorted(set(channels))[:3])
    desc = f'Weekly pattern: {behavior} — {count} violations in 7 days. Needs root-cause gate fix.'

    try:
        result = subprocess.run(
            ['bash', os.path.expanduser('~/marvin-bot/queue-write.sh'),
             item_id, desc, '60'],
            capture_output=True, text=True, timeout=15
        )
        if result.returncode != 0:
            raise Exception(result.stderr)
    except Exception as e:
        print(f'queue-write.sh failed: {e} — writing directly', file=sys.stderr)
        ts = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
        entry = (
            f'\n---\nqueued_at: {ts}\nid: {item_id}\npriority: MED\n'
            f'description: Weekly friction pattern: {behavior} appeared {count}x in last 7 days '
            f'(channels: {channel_list}). Implement gate fix to catch and prevent this pattern.\n'
            f'estimate_mins: 60\nrestart_required: no\nstatus: pending\n---\n'
        )
        with open(os.path.expanduser('~/pap-workspace/engineer-queue.md'), 'a') as f:
            f.write(entry)

    return item_id


def main():
    os.makedirs(LOG_DIR, exist_ok=True)

    entries = parse_friction_log(hours=168)
    week_str = datetime.now(timezone.utc).strftime('%Y-W%V')
    today_str = datetime.now(timezone.utc).strftime('%Y-%m-%d')

    if not entries:
        msg = f'📊 **Weekly Friction Review** — {week_str}\nNo friction entries in last 7 days. All clear.'
        print(msg)
        post_discord(HELM_IMPROVEMENTS, msg)
        with open(DECISIONS_LOG, 'a') as f:
            f.write(f'\n## [{datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M")}] — weekly-friction-review: 0 violations\n')
        return

    behavior_counter = Counter(e['behavior'] for e in entries)
    behavior_channels = defaultdict(list)
    for e in entries:
        behavior_channels[e['behavior']].append(e['channel'])

    total = len(entries)
    patterns = [(b, c) for b, c in behavior_counter.most_common() if c >= PATTERN_THRESHOLD]
    queued_ids = []

    for behavior, count in patterns:
        item_id = queue_engineer_fix(behavior, count, behavior_channels[behavior], week_str)
        queued_ids.append((item_id, behavior, count))

    # Post summary to helm-improvements
    lines = [f'📊 **Weekly Friction Review** — {week_str} ({total} total violations)']
    if patterns:
        lines.append(f'**{len(patterns)} recurring pattern(s) queued for engineer:**')
        for item_id, behavior, count in queued_ids:
            lines.append(f'- `{behavior}`: {count}x → queued as `{item_id}`')
    else:
        lines.append(f'No patterns exceed threshold ({PATTERN_THRESHOLD}+ occurrences). Top behavior: {behavior_counter.most_common(1)[0][0] if behavior_counter else "none"}')

    msg = '\n'.join(lines)
    print(msg)
    post_discord(HELM_IMPROVEMENTS, msg)

    with open(DECISIONS_LOG, 'a') as f:
        f.write(
            f'\n## [{datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M")}] — weekly-friction-review\n'
            f'Week: {week_str}\nTotal violations: {total}\nPatterns queued: {len(queued_ids)}\n'
            f'Items: {", ".join(i for i, _, _ in queued_ids) or "none"}\n'
        )


if __name__ == '__main__':
    main()
