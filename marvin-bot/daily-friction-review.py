#!/usr/bin/env python3
"""daily-friction-review.py — CPO daily friction analysis.

Runs daily at 8am PT (15:00 UTC). Reads friction-log.md for last 24h,
groups by behavior type, identifies top patterns, queues engineer fixes
for patterns recurring 2+ consecutive days, posts summary to helm-improvements.
"""
import json, os, re, subprocess, sys
from datetime import datetime, timezone, timedelta
from collections import Counter, defaultdict

FRICTION_LOG = os.path.expanduser('~/pap-workspace/friction-log.md')
PM_SCRATCH   = os.path.expanduser('~/pap-workspace/pm-scratch.md')
DECISIONS_LOG = os.path.expanduser('~/pap-workspace/decisions-log.md')
LOG_DIR      = os.path.expanduser('~/pap-workspace/logs')
HELM_IMPROVEMENTS = '{{USER_CHANNEL_HELM_IMPROVEMENTS}}'


def post_discord(channel_id, message):
    discord_post_sh = os.path.expanduser('~/marvin-bot/discord-post.sh')
    try:
        result = subprocess.run(
            [discord_post_sh, channel_id, message],
            capture_output=True, text=True, timeout=15
        )
        if result.returncode != 0:
            print(f'Discord post failed: {result.stderr}')
    except Exception as e:
        print(f'Discord post failed: {e}')


def parse_friction_log(hours=24):
    """Return list of dicts with {behavior, channel, ts} for last N hours."""
    cutoff = datetime.now(timezone.utc) - timedelta(hours=hours)
    entries = []
    if not os.path.exists(FRICTION_LOG):
        return entries
    with open(FRICTION_LOG) as f:
        for line in f:
            line = line.strip()
            if not line.startswith('['):
                continue
            m = re.match(r'\[(\d{4}-\d{2}-\d{2}T[\d:.]+Z)\]\s+(\S+)\s+channel=(\d+)', line)
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


def get_yesterday_top():
    """Read pm-scratch.md DAILY-FRICTION-HISTORY for yesterday's top behaviors."""
    if not os.path.exists(PM_SCRATCH):
        return {}
    with open(PM_SCRATCH) as f:
        content = f.read()
    m = re.search(r'## DAILY-FRICTION-HISTORY\n(.*?)(?:\n##|\Z)', content, re.DOTALL)
    if not m:
        return {}
    yesterday = (datetime.now(timezone.utc) - timedelta(days=1)).strftime('%Y-%m-%d')
    entry_m = re.search(rf'{re.escape(yesterday)}:\s*(.+)', m.group(1))
    if not entry_m:
        return {}
    result = {}
    for item in entry_m.group(1).split(','):
        if ':' in item:
            k, v = item.strip().split(':', 1)
            try:
                result[k.strip()] = int(v.strip())
            except ValueError:
                pass
    return result


def save_today_top(behavior_counts):
    """Append today's top behaviors to pm-scratch.md DAILY-FRICTION-HISTORY."""
    today = datetime.now(timezone.utc).strftime('%Y-%m-%d')
    top5 = sorted(behavior_counts.items(), key=lambda x: -x[1])[:5]
    entry = today + ': ' + ','.join(f'{k}:{v}' for k, v in top5)

    if not os.path.exists(PM_SCRATCH):
        return

    with open(PM_SCRATCH) as f:
        content = f.read()

    if '## DAILY-FRICTION-HISTORY' in content:
        content = re.sub(
            r'(## DAILY-FRICTION-HISTORY\n)',
            f'\\1{entry}\n',
            content, count=1
        )
    else:
        content += f'\n## DAILY-FRICTION-HISTORY\n{entry}\n'

    with open(PM_SCRATCH, 'w') as f:
        f.write(content)


def queue_engineer_fix(behavior, count, channels):
    """Queue an engineer task for a recurring friction pattern."""
    item_id = f'FRICTION-FIX-{behavior}-{datetime.now(timezone.utc).strftime("%Y%m%d")}'
    channel_list = ', '.join(sorted(set(channels))[:3])
    desc = f'Recurring {behavior}: {count} violations in 24h'

    try:
        result = subprocess.run(
            ['bash', os.path.expanduser('~/marvin-bot/queue-write.sh'),
             item_id, desc, '30'],
            capture_output=True, text=True, timeout=15
        )
        if result.returncode != 0:
            raise Exception(result.stderr)
    except Exception as e:
        print(f'queue-write.sh failed: {e} — writing directly')
        ts = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
        entry = (
            f'\n---\nqueued_at: {ts}\nid: {item_id}\n'
            f'problem: |\n  Recurring {behavior} ({count} times in 24h). Channels: {channel_list}.\n'
            f'  Pattern recurred 2+ consecutive days — auto-queued by CPO friction review.\n'
            f'success_criteria:\n'
            f'  - Root cause identified and fix implemented\n'
            f'  - Violation count drops below 3/day\n'
            f'estimated_min: 30\npriority: MED\nrestart_required: false\n'
            f'task_name: {item_id}\n---\n'
        )
        with open(os.path.expanduser('~/pap-workspace/engineer-queue.md'), 'a') as f:
            f.write(entry)

    return item_id


def main():
    os.makedirs(LOG_DIR, exist_ok=True)

    entries = parse_friction_log(hours=24)
    today_str = datetime.now(timezone.utc).strftime('%Y-%m-%d')

    if not entries:
        msg = f'📊 **Daily Friction Review** — {today_str}\nNo friction entries in last 24h. All clear.'
        print(msg)
        post_discord(HELM_IMPROVEMENTS, msg)
        with open(DECISIONS_LOG, 'a') as f:
            f.write(f'\n## [{datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M")}] — daily-friction-review: 0 violations\n')
        return

    # Tally by behavior type and track channels
    behavior_counter = Counter(e['behavior'] for e in entries)
    behavior_channels = defaultdict(list)
    for e in entries:
        behavior_channels[e['behavior']].append(e['channel'])

    total = len(entries)
    top5 = behavior_counter.most_common(5)
    yesterday_top = get_yesterday_top()

    # Auto-queue for patterns recurring 2+ consecutive days at 3+ occurrences
    queued_fixes = []
    for behavior, count in top5[:2]:
        if count >= 3 and yesterday_top.get(behavior, 0) >= 2:
            item_id = queue_engineer_fix(behavior, count, behavior_channels[behavior])
            queued_fixes.append((behavior, count, item_id))

    save_today_top(dict(behavior_counter))

    # Build Discord summary
    lines = [f'📊 **Daily Friction Review** — {today_str}',
             f'Total violations (24h): **{total}**', '']
    lines.append('**Top patterns:**')
    for behavior, count in top5:
        n_channels = len(set(behavior_channels[behavior]))
        lines.append(f'• `{behavior}`: **{count}** — {n_channels} channel(s)')

    if queued_fixes:
        lines.extend(['', '**Auto-queued (2+ day recurrence):**'])
        for behavior, count, item_id in queued_fixes:
            lines.append(f'• `{item_id}`: {behavior} ({count} today, ≥2 yesterday)')
    else:
        lines.extend(['', '_No patterns met auto-queue threshold (3+ today, 2+ yesterday)._'])

    summary = '\n'.join(lines)
    print(summary)
    post_discord(HELM_IMPROVEMENTS, summary)

    with open(DECISIONS_LOG, 'a') as f:
        top_label = top5[0][0] if top5 else 'none'
        f.write(
            f'\n## [{datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M")}] '
            f'— daily-friction-review: {total} violations, top={top_label}, '
            f'auto-queued={len(queued_fixes)}\n'
        )


if __name__ == '__main__':
    main()
