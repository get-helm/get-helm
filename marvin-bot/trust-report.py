#!/usr/bin/env python3
"""
trust-report.py — Weekly engineer delivery trust report
Posts to #helm-improvements Monday morning.
Schema: items_promised, items_delivered, delivery_rate_pct, avg_estimate_accuracy_pct, silence_violations_count
"""

import json
import os
import re
import subprocess
from datetime import datetime, timezone, timedelta

QUEUE_FILE = os.path.expanduser("~/pap-workspace/engineer-queue.md")
FRICTION_LOG = os.path.expanduser("~/pap-workspace/friction-log.md")
ENV_FILE = os.path.expanduser("~/marvin-bot/.env")
DISCORD_CHANNEL = "{{USER_CHANNEL_HELM_IMPROVEMENTS}}"  # helm-improvements
OUTPUT_FILE = os.path.expanduser("~/pap-workspace/trust-report-latest.json")


def load_env():
    env = {}
    if os.path.exists(ENV_FILE):
        for line in open(ENV_FILE):
            line = line.strip()
            if "=" in line and not line.startswith("#"):
                k, _, v = line.partition("=")
                env[k.strip()] = v.strip()
    return env


def parse_queue_completions(days=7):
    """Read task-registry.jsonl for done items in last N days."""
    registry_path = os.path.expanduser("~/pap-workspace/task-registry.jsonl")
    if not os.path.exists(registry_path):
        return []

    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    items = []

    with open(registry_path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue

            shipped_at = entry.get("shipped_at") or entry.get("completed_at")
            if not shipped_at:
                continue
            try:
                ts = datetime.fromisoformat(shipped_at.replace("Z", "+00:00"))
            except ValueError:
                continue

            if ts >= cutoff and entry.get("status") == "done":
                items.append(entry)

    return items


def parse_promised_items(days=7):
    """Count items queued in engineer-queue.md in last N days via queue-audit.log."""
    audit_path = os.path.expanduser("~/pap-workspace/queue-audit.log")
    if not os.path.exists(audit_path):
        return 0

    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    count = 0

    with open(audit_path) as f:
        for line in f:
            # Format: [YYYY-MM-DDTHH:MM:SSZ] QUEUED item-id description ~Nm
            m = re.match(r"\[(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z)\]\s+QUEUED", line)
            if m:
                try:
                    ts = datetime.fromisoformat(m.group(1).replace("Z", "+00:00"))
                    if ts >= cutoff:
                        count += 1
                except ValueError:
                    pass

    return count


def parse_estimate_accuracy(done_items):
    """Compare estimated vs actual minutes for completed items."""
    accuracies = []

    # Get estimated minutes from engineer-queue.md completed blocks (estimate_mins field)
    # Also cross-reference with notes in task-registry.jsonl
    for item in done_items:
        notes = item.get("notes", "")
        # Look for "actual: Nm" pattern in notes
        actual_m = re.search(r"actual[:\s]+(\d+)\s*min", notes, re.IGNORECASE)
        estimated_m = re.search(r"estimated?[:\s]+(\d+)\s*min", notes, re.IGNORECASE)

        if actual_m and estimated_m:
            actual = int(actual_m.group(1))
            estimated = int(estimated_m.group(1))
            if estimated > 0:
                accuracy = max(0, 100 - abs(actual - estimated) / estimated * 100)
                accuracies.append(accuracy)

    return round(sum(accuracies) / len(accuracies), 1) if accuracies else None


def count_silence_violations(days=7):
    """Count silence-related violations from friction-log.md."""
    if not os.path.exists(FRICTION_LOG):
        return 0

    cutoff = datetime.now(timezone.utc) - timedelta(days=days)
    count = 0
    silence_keywords = ["timeout_kill", "timeout_warn", "ORPHANED-ACK", "cadence_miss", "ack_kill"]

    with open(FRICTION_LOG) as f:
        current_ts = None
        for line in f:
            ts_m = re.search(r"(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z)", line)
            if ts_m:
                try:
                    current_ts = datetime.fromisoformat(ts_m.group(1).replace("Z", "+00:00"))
                except ValueError:
                    pass

            if current_ts and current_ts >= cutoff:
                if any(kw in line for kw in silence_keywords):
                    count += 1

    return count


def build_report():
    done_items = parse_queue_completions(days=7)
    items_delivered = len(done_items)
    items_promised = max(parse_promised_items(days=7), items_delivered)  # delivered can't exceed promised

    delivery_rate = round(items_delivered / items_promised * 100, 1) if items_promised > 0 else 0.0
    estimate_accuracy = parse_estimate_accuracy(done_items)
    silence_violations = count_silence_violations(days=7)

    report = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "window_days": 7,
        "items_promised": items_promised,
        "items_delivered": items_delivered,
        "delivery_rate_pct": delivery_rate,
        "avg_estimate_accuracy_pct": estimate_accuracy,
        "silence_violations_count": silence_violations,
    }

    return report


def format_discord_message(report):
    rate = report["delivery_rate_pct"]
    accuracy = report.get("avg_estimate_accuracy_pct")
    silence = report["silence_violations_count"]

    rate_emoji = "✅" if rate >= 80 else ("⚠️" if rate >= 60 else "🔴")
    silence_emoji = "✅" if silence == 0 else ("⚠️" if silence <= 3 else "🔴")

    lines = [
        "📊 **Weekly Engineer Trust Report**",
        f"Items promised: {report['items_promised']} → delivered: {report['items_delivered']} {rate_emoji} ({rate}%)",
    ]

    if accuracy is not None:
        acc_emoji = "✅" if accuracy >= 80 else "⚠️"
        lines.append(f"Estimate accuracy: {accuracy}% {acc_emoji}")
    else:
        lines.append("Estimate accuracy: not enough data (no actual/estimated pairs found in notes)")

    lines.append(f"Silence violations (7d): {silence} {silence_emoji}")

    return "\n".join(lines)


def post_to_discord(message, token, channel_id):
    import urllib.request
    data = json.dumps({"content": message}).encode()
    req = urllib.request.Request(
        f"https://discord.com/api/v10/channels/{channel_id}/messages",
        data=data,
        headers={"Authorization": f"Bot {token}", "Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
        return resp.status


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true", help="Print report, don't post to Discord")
    args = parser.parse_args()

    report = build_report()

    # Save latest report
    with open(OUTPUT_FILE, "w") as f:
        json.dump(report, f, indent=2)

    message = format_discord_message(report)
    print(message)
    print(f"\nReport saved to {OUTPUT_FILE}")

    if not args.dry_run:
        env = load_env()
        token = env.get("DISCORD_BOT_TOKEN", "")
        if not token:
            print("ERROR: DISCORD_BOT_TOKEN not found in .env")
            exit(1)
        status = post_to_discord(message, token, DISCORD_CHANNEL)
        print(f"Posted to Discord: HTTP {status}")
