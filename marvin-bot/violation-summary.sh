#!/usr/bin/env bash
# violation-summary.sh — ENG-MANDATES-P3-001 Phase 3 aggregation
# Reads friction-log.md, groups violations by type+week, writes violation-summary.json
# Auto-queues engineer fix when 3+ same-type violations in current week.
# Weekly top-3 digest posted to Discord.
# Usage: bash ~/marvin-bot/violation-summary.sh [--post-digest]
#
# violation-summary.json schema:
#   { "generated_at": "...", "week": "YYYY-WNN",
#     "violations": { "B06-APPROVAL-SEEKING": { "count": N, "last_seen": "...", "auto_queued": bool } },
#     "top3": [ { "type": "...", "count": N }, ... ] }

set -euo pipefail

FRICTION_LOG="$HOME/helm-workspace/system/friction-log.md"
SUMMARY_FILE="$HOME/helm-workspace/system/violation-summary.json"
DECISIONS_LOG="$HOME/helm-workspace/system/decisions-log.md"
POST_DIGEST=false

if [[ "${1:-}" == "--post-digest" ]]; then
    POST_DIGEST=true
fi

LOG_TAG="[violation-summary $(date -u +%H:%M:%SZ)]"

if [[ ! -f "$FRICTION_LOG" ]]; then
    echo "$LOG_TAG friction-log.md not found — skipping"
    exit 0
fi

# ── 1. Parse friction-log entries from current week ────────────────────────
python3 - <<PYEOF
import json, re, sys
from datetime import datetime, timezone, timedelta
from collections import defaultdict

FRICTION_LOG = "$FRICTION_LOG"
SUMMARY_FILE = "$SUMMARY_FILE"
QUEUE_SCRIPT = "$HOME/marvin-bot/queue-write.sh"
DECISIONS_LOG = "$DECISIONS_LOG"
POST_DIGEST = "$POST_DIGEST" == "true"

now = datetime.now(timezone.utc)
# Start of current ISO week (Monday 00:00 UTC)
week_start = now - timedelta(days=now.weekday(), hours=now.hour, minutes=now.minute, seconds=now.second, microseconds=now.microsecond)
week_label = now.strftime("%Y-W%W")

# Count violation types from friction-log
counts = defaultdict(lambda: {"count": 0, "last_seen": "", "samples": []})
with open(FRICTION_LOG, encoding="utf-8", errors="replace") as f:
    for line in f:
        line = line.rstrip()
        if not line:
            continue
        # Format: [2026-06-12T15:21:51Z] VIOLATION-TYPE channel=... ...
        m = re.match(r'\[(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z)\]\s+([A-Z][A-Z0-9_-]+(?:-[A-Z0-9][A-Z0-9_-]+)*)', line)
        if not m:
            continue
        try:
            ts = datetime.fromisoformat(m.group(1).replace("Z", "+00:00"))
        except Exception:
            continue
        if ts < week_start:
            continue
        vtype = m.group(2)
        counts[vtype]["count"] += 1
        counts[vtype]["last_seen"] = m.group(1)
        if len(counts[vtype]["samples"]) < 3:
            counts[vtype]["samples"].append(line[:120])

# Sort by count descending
sorted_violations = sorted(counts.items(), key=lambda x: x[1]["count"], reverse=True)
top3 = [{"type": t, "count": v["count"], "last_seen": v["last_seen"]} for t, v in sorted_violations[:3]]

# Build summary
summary = {
    "generated_at": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
    "week": week_label,
    "week_start": week_start.strftime("%Y-%m-%dT%H:%M:%SZ"),
    "violations": {t: {k: vv for k, vv in v.items() if k != "samples"} for t, v in counts.items()},
    "top3": top3,
    "auto_queued_this_run": []
}

# Auto-queue engineer fix for types with 3+ hits this week (not already queued)
import subprocess, os
existing_summary = {}
if os.path.exists(SUMMARY_FILE):
    try:
        existing_summary = json.load(open(SUMMARY_FILE))
    except Exception:
        pass
already_queued = set(existing_summary.get("auto_queued_this_run", []))

for vtype, vdata in sorted_violations:
    if vdata["count"] >= 3 and vtype not in already_queued:
        item_id = f"FRICTION-{vtype.replace('-', '_')[:30]}-RECURRING"
        description = f"Recurring {vtype}: {vdata['count']} violations this week. Auto-queued by violation-summary.sh. Sample: {vdata['samples'][0][:100] if vdata['samples'] else 'N/A'}"
        try:
            result = subprocess.run(
                [os.path.expanduser("~/marvin-bot/queue-write.sh"), item_id, description, "30", "--priority", "MED"],
                capture_output=True, text=True, timeout=30
            )
            if result.returncode == 0:
                summary["auto_queued_this_run"].append(vtype)
                print(f"[violation-summary] Auto-queued fix for {vtype} ({vdata['count']} hits): {item_id}")
                # Log to decisions-log
                with open(DECISIONS_LOG, "a") as dl:
                    dl.write(f"\n## [{now.strftime('%Y-%m-%d %H:%M')}] VIOLATION-AUTO-QUEUE — {vtype}\n")
                    dl.write(f"- Count this week: {vdata['count']} (threshold: 3)\n")
                    dl.write(f"- Item queued: {item_id}\n")
            else:
                print(f"[violation-summary] Queue blocked for {vtype}: {result.stdout.strip()}")
        except Exception as qe:
            print(f"[violation-summary] Queue error for {vtype}: {qe}")

# Write summary JSON
with open(SUMMARY_FILE, "w") as f:
    json.dump(summary, f, indent=2)

print(f"[violation-summary] Written {SUMMARY_FILE}")
print(f"[violation-summary] Top 3 violations this week:")
for item in top3:
    print(f"  {item['type']}: {item['count']}")

# Post weekly digest if requested
if POST_DIGEST and top3:
    import subprocess, os
    digest_lines = ["📊 **Weekly Violation Digest** — top 3 patterns this week:"]
    for i, item in enumerate(top3, 1):
        digest_lines.append(f"{i}. **{item['type']}**: {item['count']} occurrences")
    auto_q = summary.get("auto_queued_this_run", [])
    if auto_q:
        digest_lines.append(f"\nAuto-queued engineer fix for: {', '.join(auto_q)}")
    else:
        digest_lines.append("\nNo auto-queues this run (all types below threshold or already queued).")

    msg = "\n".join(digest_lines)
    discord_script = os.path.expanduser("~/marvin-bot/discord-post.sh")
    try:
        subprocess.run([discord_script, "{{USER_CHANNEL_HELM_IMPROVEMENTS}}", msg], timeout=15, check=False)
        print(f"[violation-summary] Posted weekly digest to helm-improvements")
    except Exception as pe:
        print(f"[violation-summary] Discord post error: {pe}")
PYEOF

# ── B02-OVERRUN-ROOTCAUSE-001: Per-channel B02 histogram ──────────────────
# Parses B02_OVERRUN entries, groups by channel, maps to names, adds to summary.
python3 - <<'B02EOF'
import json, re, os
from datetime import datetime, timezone, timedelta
from collections import defaultdict

FRICTION_LOG = os.path.expanduser("~/helm-workspace/system/friction-log.md")
SUMMARY_FILE = os.path.expanduser("~/helm-workspace/system/violation-summary.json")
REGISTRY = os.path.expanduser("~/helm-workspace/channel-registry.json")

now = datetime.now(timezone.utc)
week_start = now - timedelta(days=now.weekday(), hours=now.hour, minutes=now.minute, seconds=now.second)

ch_map = {}
try:
    reg = json.load(open(REGISTRY))
    for name, cid in reg.get("system_channels", {}).items():
        ch_map[str(cid)] = name.replace("_", "-")
    for w in reg.get("workspace_channels", []):
        ch_map[str(w.get("channel_id",""))] = w.get("name","?")
except Exception:
    pass

b02_by_channel = defaultdict(int)
with open(FRICTION_LOG, encoding="utf-8", errors="replace") as f:
    for line in f:
        m = re.match(r'\[(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})', line)
        if not m or "B02_OVERRUN" not in line:
            continue
        try:
            ts = datetime.fromisoformat(m.group(1)).replace(tzinfo=timezone.utc)
        except Exception:
            continue
        if ts < week_start:
            continue
        cm = re.search(r'channel=(\d+)', line)
        if cm:
            b02_by_channel[cm.group(1)] += 1

total = sum(b02_by_channel.values())
histogram = sorted(
    [{"channel_id": cid, "name": ch_map.get(cid, f"#{cid[-6:]}"), "count": cnt,
      "pct": round(cnt/total*100) if total else 0}
     for cid, cnt in b02_by_channel.items()],
    key=lambda x: x["count"], reverse=True
)

try:
    summary = json.load(open(SUMMARY_FILE))
except Exception:
    summary = {}
summary["b02_overrun_histogram"] = {"total_this_week": total, "by_channel": histogram[:10]}
with open(SUMMARY_FILE, "w") as f:
    json.dump(summary, f, indent=2)

if histogram:
    print(f"[b02-histogram] {total} B02_OVERRUN this week. Top channels:")
    for h in histogram[:5]:
        print(f"  #{h['name']}: {h['count']} ({h['pct']}%)")
else:
    print("[b02-histogram] No B02_OVERRUN entries this week.")
B02EOF
