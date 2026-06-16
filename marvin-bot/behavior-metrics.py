#!/usr/bin/env python3
"""behavior-metrics.py — per-behavior violation breakdown from friction-log.md
Usage: behavior-metrics.py [--days N] [--json]
Defaults: last 30 days, human-readable output
"""
import sys, re, json
from datetime import datetime, timedelta
from pathlib import Path
from collections import defaultdict

FRICTION_LOG = Path.home() / "helm-workspace/friction-log.md"
METRICS_JSON = Path.home() / "helm-workspace/behavior-metrics.json"

# friction code → behavior ID
CODE_MAP = {
    "CADENCE-MISS": "B-02",       "B02_OVERRUN": "B-02",     "B02_ACK_NO_ESTIMATE": "B-02",
    "ORPHANED-ACK": "B-04",       "B04-ORPHAN-EXIT": "B-04", "b04_orphan": "B-04",
    "B17-LENGTH": "B-17",         "b17_length": "B-17",
    "CLAIM-UNVERIFIED": "B-01",   "DELIVER-SCHEMA-VIOLATION": "B-01",
    "DELIVER-MISSING-PUSHBACK": "B-15", "PUSHBACK-RECUR": "B-15",
    "PUSHBACK-RECUR-ESCALATED": "B-15", "PUSHBACK-NO-OBLIGATION": "B-15",
    "B19-PATH-EXPOSED": "B-19",
    "B07-BLOCK-NO-EVIDENCE": "B-07",
    "B18-PROSE-QUESTION": "B-18", "b18_prose_question": "B-18",
    "RESEARCH-QUALITY": "B-11",   "research_skipped": "B-11",
    "B22-ENUM": "B-22",           "b22_enum_no_sentinel": "B-22",
    "B22-NO-PAUSE": "B-22",       "b22_no_pause": "B-22",
    "B20-TIMELINE": "B-20",       "b20_timeline": "B-20",
    "B06-APPROVAL-SEEKING": "B-06", "PROACTIVE-NEXT-QUESTION": "B-06",
    "PROACTIVE_NEXT-EMPTY": "B-06", "proactive_escape": "B-06",
    "b06_approval": "B-06",
    "b08_passback_flag": "B-08",  "passback_language": "B-08",
    "EMPTY_CHECKPOINT_NOTES": "B-03",
    "assumption_skip": "B-16",    "b16_context_skip": "B-16",
    "DUPLICATE-REPORTED": "B-21",
    "THREAD-MISROUTING": "B-05",
    "validation_failure": "B-01",
    "PUSHBACK-RECUR:": "B-15",    # trailing colon variant
    "CHALLENGED:": "SKIP",        # not a violation
    "vagueness_flag": "B-16",
    "pm_noise_gate_breach": "B-17",
}

# Codes that are not violations — skip counting them
SKIP_CODES = {"SKIP", "CHALLENGED:", "⚠️", "UPDATE-"}

def parse_args():
    days = 30
    json_mode = "--json" in sys.argv
    for i, a in enumerate(sys.argv):
        if a == "--days" and i + 1 < len(sys.argv):
            try: days = int(sys.argv[i+1])
            except ValueError: pass
    return days, json_mode

def run():
    days, json_mode = parse_args()
    cutoff = datetime.utcnow() - timedelta(days=days)

    counts = defaultdict(int)
    last_seen = {}
    raw_counts = defaultdict(int)
    unmapped_codes = defaultdict(int)

    pattern = re.compile(r'^\[(\d{4}-\d{2}-\d{2})T[^\]]*\]\s+(\S+)')

    if not FRICTION_LOG.exists():
        print(f"ERROR: {FRICTION_LOG} not found", file=sys.stderr)
        sys.exit(1)

    for line in FRICTION_LOG.read_text(errors="replace").splitlines():
        m = pattern.match(line)
        if not m:
            continue
        date_str, code = m.group(1), m.group(2)
        if code == "PASS":
            continue
        try:
            entry_date = datetime.strptime(date_str, "%Y-%m-%d")
        except ValueError:
            continue
        if entry_date < cutoff:
            continue

        raw_counts[code] += 1
        behavior = CODE_MAP.get(code, "UNMAPPED")
        if behavior in SKIP_CODES or code in SKIP_CODES:
            continue
        if behavior == "UNMAPPED":
            unmapped_codes[code] += 1
        counts[behavior] += 1
        last_seen[behavior] = max(last_seen.get(behavior, ""), date_str)

    total = sum(counts.values())
    sorted_behaviors = sorted(counts, key=lambda b: counts[b], reverse=True)
    generated_at = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")

    result = {
        "generated_at": generated_at,
        "days": days,
        "total_violations": total,
        "by_behavior": {
            b: {"count": counts[b], "last_seen": last_seen.get(b, "unknown")}
            for b in sorted_behaviors
        },
        "top_3": sorted_behaviors[:3],
    }

    # Always write JSON file
    METRICS_JSON.write_text(json.dumps(result, indent=2))

    if json_mode:
        print(json.dumps(result, indent=2))
        return

    print(f"=== Behavior Violation Breakdown (last {days} days) ===")
    print(f"Generated: {generated_at}")
    print(f"Total violations: {total}\n")
    print(f"{'BEHAVIOR':<10} {'COUNT':>6}  LAST SEEN")
    print("-" * 35)
    for b in sorted_behaviors:
        if b == "UNMAPPED":
            continue
        print(f"{b:<10} {counts[b]:>6}  {last_seen.get(b, 'unknown')}")
    if "UNMAPPED" in counts:
        print(f"\n  {counts['UNMAPPED']} entries unmapped — top unknown codes:")
        for code, n in sorted(unmapped_codes.items(), key=lambda x: -x[1])[:5]:
            print(f"    {code}: {n}")

if __name__ == "__main__":
    run()
