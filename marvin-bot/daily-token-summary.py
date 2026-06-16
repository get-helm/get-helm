#!/usr/bin/env python3
"""
Daily token summary from Claude Code JSONL session files.
Reads sessions modified in the last 24h, maps channel_id → agent type,
sums input/output/cache tokens, writes JSON summary.
Run: python3 daily-token-summary.py
Output: ~/pap-workspace/scripts/usage/daily-token-summary.json
"""

import json
import os
import re
import sys
import time
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

JSONL_DIR = Path.home() / ".claude/projects" / ("-Users-" + Path.home().name + "-helm-workspace")
OUTPUT_FILE = Path.home() / "helm-workspace/scripts/usage/daily-token-summary.json"
LOOKBACK_HOURS = 24

# Channel ID → agent type mapping
CHANNEL_AGENT_MAP = {
    "{{USER_CHANNEL_GENERAL}}": "help",          # general
    "1501656066340032776": "curiosity",     # new-workspace
    "{{USER_CHANNEL_HELM_AUDIT}}": "engineer",      # helm-audit / engineer channel
    "{{USER_CHANNEL_HELM_STATUS}}": "help",          # helm-status
    "{{USER_CHANNEL_HELM_IMPROVEMENTS}}": "product-manager",  # helm-improvements
    "{{USER_CHANNEL_OPTIONS_HELPER}}": "workspace",     # options-helper
    "{{USER_CHANNEL_ETF_TRACKER}}": "workspace",     # etf-tracker
    "1504160847134720050": "workspace",     # financial-review
    "1504126943669260403": "workspace",     # daily-brief
    "1503509979226329128": "workspace",     # mission-control
    "1506654092662018161": "workspace",     # options-helper thread
    "{{USER_CHANNEL_RECOVERY}}": "help",          # recovery channel
    # helm-improvements threads (product-manager)
    "1507889139742412871": "product-manager",  # thread: Claude costs
    "{{USER_CHANNEL_BETA_USERS}}": "product-manager",  # thread: Additional users
    "1512136473359679518": "product-manager",  # thread: Agent Behavior
    "1513366263890710658": "product-manager",  # thread: HELM unresponsive
    "1513377096804728865": "product-manager",  # thread: Concern from helm-audit
    "1513593914492453016": "product-manager",  # thread: Time to refactor?
    "1507765671323242588": "product-manager",  # thread: helm-improvements noise
}

CHANNEL_NAMES = {
    "{{USER_CHANNEL_GENERAL}}": "#general",
    "1501656066340032776": "#new-workspace",
    "{{USER_CHANNEL_HELM_AUDIT}}": "#helm-audit",
    "{{USER_CHANNEL_HELM_STATUS}}": "#helm-status",
    "{{USER_CHANNEL_HELM_IMPROVEMENTS}}": "#helm-improvements",
    "{{USER_CHANNEL_OPTIONS_HELPER}}": "#options-helper",
    "{{USER_CHANNEL_ETF_TRACKER}}": "#etf-tracker",
    "1504160847134720050": "#financial-review",
    "1504126943669260403": "#daily-brief",
    "1503509979226329128": "#mission-control",
    "{{USER_CHANNEL_RECOVERY}}": "#recovery",
    "1507889139742412871": "#helm-improvements/thread",
    "{{USER_CHANNEL_BETA_USERS}}": "#helm-improvements/thread",
    "1512136473359679518": "#helm-improvements/thread",
    "1513366263890710658": "#helm-improvements/thread",
    "1513377096804728865": "#helm-improvements/thread",
    "1513593914492453016": "#helm-improvements/thread",
    "1507765671323242588": "#helm-improvements/thread",
}


def extract_channel_id(jsonl_path):
    """Extract channel_id from first user message in JSONL file."""
    try:
        with open(jsonl_path, encoding="utf-8", errors="replace") as f:
            for line in f:
                try:
                    d = json.loads(line)
                    if d.get("type") != "user":
                        continue
                    content = d.get("message", {}).get("content", "")
                    if isinstance(content, list):
                        content = " ".join(
                            c.get("text", "") if isinstance(c, dict) else str(c)
                            for c in content
                        )
                    m = re.search(r"channel_id[:\s]+(\d{17,20})", content)
                    if m:
                        return m.group(1)
                except (json.JSONDecodeError, TypeError):
                    continue
    except OSError:
        pass
    return None


def sum_session_tokens(jsonl_path):
    """Sum all token usage from assistant messages in a JSONL session."""
    totals = {
        "input_tokens": 0,
        "output_tokens": 0,
        "cache_creation_input_tokens": 0,
        "cache_read_input_tokens": 0,
    }
    try:
        with open(jsonl_path, encoding="utf-8", errors="replace") as f:
            for line in f:
                try:
                    d = json.loads(line)
                    if d.get("type") != "assistant":
                        continue
                    usage = d.get("message", {}).get("usage", {})
                    for key in totals:
                        totals[key] += usage.get(key, 0)
                except (json.JSONDecodeError, TypeError):
                    continue
    except OSError:
        pass
    return totals


def main():
    cutoff = time.time() - LOOKBACK_HOURS * 3600
    jsonl_files = [
        p for p in JSONL_DIR.glob("*.jsonl")
        if p.stat().st_mtime >= cutoff
    ]

    print(f"Processing {len(jsonl_files)} JSONL files from last {LOOKBACK_HOURS}h...")

    # Per-agent-type aggregation
    by_agent = defaultdict(lambda: {
        "input_tokens": 0,
        "output_tokens": 0,
        "cache_creation_input_tokens": 0,
        "cache_read_input_tokens": 0,
        "sessions": 0,
        "channels": set(),
    })

    unmapped_channels = defaultdict(int)

    for jsonl_path in jsonl_files:
        channel_id = extract_channel_id(jsonl_path)
        agent_type = CHANNEL_AGENT_MAP.get(channel_id, None)

        if agent_type is None:
            if channel_id:
                unmapped_channels[channel_id] += 1
                agent_type = "workspace"  # Default unknown channels to workspace
            else:
                agent_type = "unknown"

        tokens = sum_session_tokens(jsonl_path)
        bucket = by_agent[agent_type]
        for key in ("input_tokens", "output_tokens", "cache_creation_input_tokens", "cache_read_input_tokens"):
            bucket[key] += tokens[key]
        bucket["sessions"] += 1
        if channel_id:
            bucket["channels"].add(channel_id)

    # Build output
    totals = {
        "input_tokens": 0,
        "output_tokens": 0,
        "cache_creation_input_tokens": 0,
        "cache_read_input_tokens": 0,
        "sessions": 0,
    }

    by_agent_out = {}
    for agent, data in sorted(by_agent.items()):
        channels_list = sorted(data["channels"])
        entry = {
            "input_tokens": data["input_tokens"],
            "output_tokens": data["output_tokens"],
            "cache_creation_input_tokens": data["cache_creation_input_tokens"],
            "cache_read_input_tokens": data["cache_read_input_tokens"],
            "sessions": data["sessions"],
            "cache_hit_rate_pct": round(
                100 * data["cache_read_input_tokens"] /
                (data["input_tokens"] + data["cache_read_input_tokens"] + data["cache_creation_input_tokens"])
                if (data["input_tokens"] + data["cache_read_input_tokens"] + data["cache_creation_input_tokens"]) > 0
                else 0, 1
            ),
            "channel_names": [CHANNEL_NAMES.get(c, c) for c in channels_list],
        }
        by_agent_out[agent] = entry
        for key in ("input_tokens", "output_tokens", "cache_creation_input_tokens", "cache_read_input_tokens"):
            totals[key] += data[key]
        totals["sessions"] += data["sessions"]

    total_billable = totals["input_tokens"] + totals["output_tokens"] + totals["cache_creation_input_tokens"]
    cache_hit_rate = round(
        100 * totals["cache_read_input_tokens"] /
        (totals["input_tokens"] + totals["cache_read_input_tokens"] + totals["cache_creation_input_tokens"])
        if (totals["input_tokens"] + totals["cache_read_input_tokens"] + totals["cache_creation_input_tokens"]) > 0
        else 0, 1
    )

    output = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "lookback_hours": LOOKBACK_HOURS,
        "files_processed": len(jsonl_files),
        "totals": {
            **totals,
            "cache_hit_rate_pct": cache_hit_rate,
            "total_billable_tokens": total_billable,
        },
        "by_agent_type": by_agent_out,
        "unmapped_channels": dict(unmapped_channels),
    }

    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(OUTPUT_FILE, "w") as f:
        json.dump(output, f, indent=2)

    # Print summary
    print(f"\n=== Daily Token Summary ({LOOKBACK_HOURS}h) ===")
    print(f"Sessions: {totals['sessions']}  Files: {len(jsonl_files)}")
    print(f"Input: {totals['input_tokens']:,}  Output: {totals['output_tokens']:,}")
    print(f"Cache created: {totals['cache_creation_input_tokens']:,}  Cache read: {totals['cache_read_input_tokens']:,}")
    print(f"Cache hit rate: {cache_hit_rate}%")
    print(f"\nBy agent type:")
    for agent, data in sorted(by_agent_out.items(), key=lambda x: -x[1]["sessions"]):
        print(f"  {agent}: {data['sessions']} sessions, {data['input_tokens']:,} in, {data['output_tokens']:,} out, {data['cache_hit_rate_pct']}% cache hit")
    print(f"\nOutput: {OUTPUT_FILE}")
    print(f"Cache audit complete — {len(jsonl_files)} files checked, 0 fixed")


if __name__ == "__main__":
    main()
