#!/usr/bin/env bash
# mandate-weekly-tracker.sh — ENG-MANDATES-P4-BASELINE-001
# Tracks per-violation-type weekly rates in behavior-metrics.json.
# Compares current week vs 2 weeks ago; if rate stagnant post-fix → auto-opens
# reopened_fix item in work-items.json.
# Weekly report posted to helm-improvements every Monday.
# Usage: bash ~/marvin-bot/mandate-weekly-tracker.sh [--post-digest]

set -euo pipefail

FRICTION_LOG="$HOME/helm-workspace/system/friction-log.md"
BEHAVIOR_METRICS="$HOME/helm-workspace/behavior-metrics.json"
WORK_ITEMS="$HOME/helm-workspace/work-items.json"
TASK_REGISTRY="$HOME/helm-workspace/task-registry.jsonl"
DECISIONS_LOG="$HOME/helm-workspace/system/decisions-log.md"
PM_SCRATCH="$HOME/helm-workspace/system/pm-scratch.md"
HELM_IMPROVEMENTS_CHANNEL="{{USER_CHANNEL_HELM_IMPROVEMENTS}}"
POST_DIGEST=false

if [[ "${1:-}" == "--post-digest" ]]; then
    POST_DIGEST=true
fi

LOG_TAG="[mandate-weekly-tracker $(date -u +%H:%M:%SZ)]"

if [[ ! -f "$FRICTION_LOG" ]]; then
    echo "$LOG_TAG friction-log.md not found — skipping"
    exit 0
fi

python3 - <<PYEOF
import json, re, sys, os, subprocess
from datetime import datetime, timezone, timedelta
from collections import defaultdict

FRICTION_LOG = "$FRICTION_LOG"
BEHAVIOR_METRICS = "$BEHAVIOR_METRICS"
WORK_ITEMS = "$WORK_ITEMS"
TASK_REGISTRY = "$TASK_REGISTRY"
DECISIONS_LOG = "$DECISIONS_LOG"
PM_SCRATCH = "$PM_SCRATCH"
HELM_IMPROVEMENTS_CHANNEL = "$HELM_IMPROVEMENTS_CHANNEL"
POST_DIGEST = "$POST_DIGEST" == "true"

now = datetime.now(timezone.utc)
today_str = now.strftime("%Y-%m-%d")

def iso_week(dt):
    """Return ISO week label YYYY-WNN."""
    return dt.strftime("%Y-W%W")

def week_start(dt):
    """Monday 00:00 UTC of the week containing dt."""
    return dt - timedelta(days=dt.weekday(), hours=dt.hour,
                          minutes=dt.minute, seconds=dt.second, microseconds=dt.microsecond)

# ── 1. Parse friction-log: collect violation counts per type per week ──────
# Look back 5 weeks to have enough data for comparison
lookback_start = week_start(now) - timedelta(weeks=4)
weekly_counts = defaultdict(lambda: defaultdict(int))  # week_label -> vtype -> count

with open(FRICTION_LOG, encoding="utf-8", errors="replace") as f:
    for line in f:
        line = line.rstrip()
        if not line:
            continue
        m = re.match(r'\[(\d{4}-\d{2}-\d{2}T[\d:.]+Z)\]\s+([A-Z][A-Z0-9_-]+(?:-[A-Z0-9][A-Z0-9_-]+)*)', line)
        if not m:
            continue
        try:
            ts = datetime.fromisoformat(m.group(1).replace("Z", "+00:00"))
        except Exception:
            continue
        if ts < lookback_start:
            continue
        vtype = m.group(2)
        # Skip PASS entries (not violations)
        if vtype == "PASS":
            continue
        wlabel = iso_week(ts)
        weekly_counts[wlabel][vtype] += 1

current_week = iso_week(now)
prev_week = iso_week(now - timedelta(weeks=1))
two_weeks_ago = iso_week(now - timedelta(weeks=2))

print(f"[mandate-weekly-tracker] Current week: {current_week}, prev: {prev_week}, 2wk ago: {two_weeks_ago}")
print(f"[mandate-weekly-tracker] Weeks with data: {sorted(weekly_counts.keys())}")

# ── 2. Load existing behavior-metrics.json ────────────────────────────────
metrics = {}
if os.path.exists(BEHAVIOR_METRICS):
    try:
        metrics = json.load(open(BEHAVIOR_METRICS, encoding="utf-8"))
    except Exception as e:
        print(f"[mandate-weekly-tracker] WARN: Could not load behavior-metrics.json: {e}")

if "weekly_mandate_rates" not in metrics:
    metrics["weekly_mandate_rates"] = {}

# ── 3. Write current week counts ──────────────────────────────────────────
cw_data = dict(weekly_counts.get(current_week, {}))
pw_data = dict(weekly_counts.get(prev_week, {}))
tw_data = dict(weekly_counts.get(two_weeks_ago, {}))

metrics["weekly_mandate_rates"][current_week] = {
    "generated_at": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
    "total": sum(cw_data.values()),
    "violations": cw_data
}
# Backfill prior weeks if not already recorded
for wlabel, wdata in weekly_counts.items():
    if wlabel not in metrics["weekly_mandate_rates"]:
        metrics["weekly_mandate_rates"][wlabel] = {
            "generated_at": today_str,
            "total": sum(wdata.values()),
            "violations": dict(wdata)
        }

# Keep only last 8 weeks in the JSON to prevent unbounded growth
all_weeks = sorted(metrics["weekly_mandate_rates"].keys(), reverse=True)
for old_week in all_weeks[8:]:
    del metrics["weekly_mandate_rates"][old_week]

# ── 4. Load shipped fixes from task-registry ────────────────────────────
# FRICTION-<VIOLATION_TYPE>-RECURRING entries that are "done" indicate a fix shipped
shipped_fixes = {}  # vtype -> {"shipped_at": "...", "week": "..."}
if os.path.exists(TASK_REGISTRY):
    with open(TASK_REGISTRY, encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except Exception:
                continue
            if entry.get("status") != "done":
                continue
            item_id = entry.get("id", "")
            # Match FRICTION-<TYPE>-RECURRING or FRICTION-<TYPE>_RECURRING
            fm = re.match(r'FRICTION[_-](.+?)[_-]RECURRING', item_id)
            if not fm:
                continue
            raw_type = fm.group(1)
            # Normalize: underscores back to mixed (B02_OVERRUN → B02_OVERRUN, keep as-is)
            # The shipped_at is in the done entry
            shipped_at_str = entry.get("shipped_at", entry.get("completed_at", ""))
            if not shipped_at_str:
                continue
            try:
                shipped_dt = datetime.fromisoformat(shipped_at_str.replace("Z", "+00:00"))
            except Exception:
                continue
            shipped_week = iso_week(shipped_dt)
            # Store by both raw_type variants for matching
            for key in [raw_type, raw_type.replace("_", "-"), raw_type.replace("-", "_")]:
                if key not in shipped_fixes:
                    shipped_fixes[key] = {"shipped_at": shipped_at_str, "week": shipped_week, "id": item_id}

print(f"[mandate-weekly-tracker] Shipped fixes found: {list(shipped_fixes.keys())}")

# ── 5. Reopened fix detection ─────────────────────────────────────────────
# For each violation type: if fix shipped >=2 weeks ago AND current rate >= 80% of pre-fix rate
if "mandate_improvement_tracking" not in metrics:
    metrics["mandate_improvement_tracking"] = {}

reopened_items = []
for vtype, fix_info in shipped_fixes.items():
    fix_week = fix_info["week"]
    # Skip if fix shipped this week or last week (too soon to judge)
    if fix_week >= prev_week:
        print(f"[mandate-weekly-tracker] {vtype}: fix shipped {fix_week}, too recent to judge")
        continue

    # Pre-fix rate: average of the 2 weeks before fix shipped
    # Post-fix rate: current week
    current_count = cw_data.get(vtype, 0)
    pre_fix_count = tw_data.get(vtype, pw_data.get(vtype, 0))

    if pre_fix_count == 0:
        print(f"[mandate-weekly-tracker] {vtype}: no pre-fix data, skipping reopener check")
        continue

    improvement_pct = (pre_fix_count - current_count) / pre_fix_count * 100
    tracking_key = f"{vtype}-{fix_week}"

    metrics["mandate_improvement_tracking"][tracking_key] = {
        "vtype": vtype,
        "fix_shipped_week": fix_week,
        "fix_id": fix_info["id"],
        "pre_fix_count": pre_fix_count,
        "current_week_count": current_count,
        "improvement_pct": round(improvement_pct, 1),
        "checked_at": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "stagnant": improvement_pct < 20
    }

    if improvement_pct < 20 and current_count > 0:
        # Check if we already opened a reopener for this fix
        already_reopened = metrics["mandate_improvement_tracking"][tracking_key].get("reopened_item_id")
        if already_reopened:
            print(f"[mandate-weekly-tracker] {vtype}: already reopened as {already_reopened}, skipping")
            continue

        print(f"[mandate-weekly-tracker] {vtype}: stagnant ({improvement_pct:.0f}% improvement, {current_count} this week vs {pre_fix_count} pre-fix) — opening reopened_fix")
        reopened_items.append({
            "vtype": vtype,
            "fix_id": fix_info["id"],
            "pre_fix_count": pre_fix_count,
            "current_count": current_count,
            "improvement_pct": improvement_pct,
            "tracking_key": tracking_key
        })
    else:
        print(f"[mandate-weekly-tracker] {vtype}: improving ({improvement_pct:.0f}% drop, {current_count} this week vs {pre_fix_count} pre-fix)")

# ── 6. Write reopened_fix items to work-items.json ───────────────────────
if reopened_items and os.path.exists(WORK_ITEMS):
    try:
        wi_data = json.load(open(WORK_ITEMS, encoding="utf-8"))
        items = wi_data.get("items", [])
        # Find max WI-NN id
        max_id = 0
        for item in items:
            iid = item.get("id", "")
            m = re.match(r'WI-(\d+)', iid)
            if m:
                max_id = max(max_id, int(m.group(1)))

        new_ids = []
        for ri in reopened_items:
            max_id += 1
            new_id = f"WI-{max_id:03d}"
            new_item = {
                "id": new_id,
                "type": "reopened_fix",
                "title": f"Reopened: {ri['vtype']} violation rate stagnant 2+ weeks post-fix",
                "status": "open",
                "level": 2,
                "priority": "med",
                "source": "automation",
                "owner": "engineer",
                "created": today_str,
                "reopened_for": ri["vtype"],
                "original_fix": ri["fix_id"],
                "evidence": {
                    "pre_fix_count_per_week": ri["pre_fix_count"],
                    "current_week_count": ri["current_count"],
                    "improvement_pct": round(ri["improvement_pct"], 1)
                },
                "description": (
                    f"Fix {ri['fix_id']} shipped for {ri['vtype']} but violation rate is stagnant "
                    f"({ri['current_count']}/wk now vs {ri['pre_fix_count']}/wk pre-fix, "
                    f"{ri['improvement_pct']:.0f}% improvement — threshold: 20%). "
                    f"Re-investigate root cause and implement stronger fix."
                )
            }
            items.append(new_item)
            new_ids.append(new_id)
            # Record the reopened item ID in tracking
            metrics["mandate_improvement_tracking"][ri["tracking_key"]]["reopened_item_id"] = new_id
            print(f"[mandate-weekly-tracker] Created {new_id} for {ri['vtype']}")

        if new_ids:
            wi_data["items"] = items
            wi_data["last_updated"] = now.strftime("%Y-%m-%dT%H:%M:%SZ")
            wi_data["updated_by"] = "mandate-weekly-tracker"
            with open(WORK_ITEMS, "w", encoding="utf-8") as f:
                json.dump(wi_data, f, indent=2)
            print(f"[mandate-weekly-tracker] work-items.json updated with: {new_ids}")

            with open(DECISIONS_LOG, "a", encoding="utf-8") as dl:
                dl.write(f"\n## [{now.strftime('%Y-%m-%d %H:%M')}] MANDATE-REOPENER — stagnant violations\n")
                for ri in reopened_items:
                    dl.write(f"- {ri['vtype']}: {ri['current_count']}/wk ({ri['improvement_pct']:.0f}% improvement post-fix {ri['fix_id']})\n")
                dl.write(f"- Reopened items: {new_ids}\n")
    except Exception as e:
        print(f"[mandate-weekly-tracker] ERROR writing work-items.json: {e}")

# ── 7. Build weekly report ────────────────────────────────────────────────
# Collect top violations this week with trend arrows
trend_lines = []
all_vtypes = set(list(cw_data.keys()) + list(pw_data.keys()))
top_items = sorted(all_vtypes, key=lambda v: cw_data.get(v, 0), reverse=True)[:5]

for vtype in top_items:
    cw_c = cw_data.get(vtype, 0)
    pw_c = pw_data.get(vtype, 0)
    if cw_c == 0 and pw_c == 0:
        continue
    if pw_c == 0:
        trend = "🆕"
    elif cw_c < pw_c:
        trend = "✅↓"
    elif cw_c > pw_c:
        trend = "🔴↑"
    else:
        trend = "⚠️ →"
    trend_lines.append(f"  {trend} **{vtype}**: {cw_c} this wk (was {pw_c})")

# Check if today is Monday for auto-post
is_monday = now.weekday() == 0

# ── 8. Write updated behavior-metrics.json ───────────────────────────────
metrics["mandate_tracker_last_run"] = now.strftime("%Y-%m-%dT%H:%M:%SZ")
with open(BEHAVIOR_METRICS, "w", encoding="utf-8") as f:
    json.dump(metrics, f, indent=2)
print(f"[mandate-weekly-tracker] behavior-metrics.json updated")

# Update pm-scratch.md with last run date
if os.path.exists(PM_SCRATCH):
    content = open(PM_SCRATCH, encoding="utf-8").read()
    if "last_mandate_tracker_date" in content:
        content = re.sub(r'last_mandate_tracker_date:.*', f'last_mandate_tracker_date: {today_str}', content)
    else:
        content += f"\nlast_mandate_tracker_date: {today_str}\n"
    with open(PM_SCRATCH, "w", encoding="utf-8") as f:
        f.write(content)

# ── 9. Post digest if requested or Monday ─────────────────────────────────
if POST_DIGEST or is_monday:
    week_total = sum(cw_data.values())
    prev_total = sum(pw_data.values())
    delta = week_total - prev_total
    delta_str = f"+{delta}" if delta > 0 else str(delta)

    lines = [f"📊 **Weekly Mandate Tracker** — {current_week}"]
    lines.append(f"Total violations: {week_total} ({delta_str} vs last week)")
    lines.append("")
    if trend_lines:
        lines.append("Top 5 violation types:")
        lines.extend(trend_lines)
    else:
        lines.append("No violations recorded this week.")
    if reopened_items:
        lines.append("")
        lines.append(f"🔁 Stagnant post-fix — reopened {len(reopened_items)} item(s):")
        for ri in reopened_items:
            lines.append(f"  • {ri['vtype']}: {ri['improvement_pct']:.0f}% improvement (threshold: 20%)")

    msg = "\n".join(lines)
    discord_script = os.path.expanduser("~/marvin-bot/discord-post.sh")
    try:
        result = subprocess.run([discord_script, HELM_IMPROVEMENTS_CHANNEL, msg],
                                timeout=15, check=False, capture_output=True, text=True)
        if result.returncode == 0:
            print(f"[mandate-weekly-tracker] Digest posted to helm-improvements")
        else:
            print(f"[mandate-weekly-tracker] Discord post failed: {result.stderr}")
    except Exception as pe:
        print(f"[mandate-weekly-tracker] Discord post error: {pe}")
else:
    print(f"[mandate-weekly-tracker] Not Monday and --post-digest not set — skipping Discord post")

print(f"[mandate-weekly-tracker] Done. Current week: {current_week}, total: {sum(cw_data.values())}")
PYEOF
