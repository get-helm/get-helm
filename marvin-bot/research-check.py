#!/usr/bin/env python3
"""research-check.py — B-11/B-12 research enforcement detector (B11-B12-RESEARCH-ENFORCEMENT-001)

Called by discord-post.sh on every agent message. Detects "ask-before-research" patterns:
messages that pose questions about external facts or prior decisions without citing any
research source (QMD, web search, grep, etc.). Logs violations to friction-log.md as
RESEARCH-SKIPPED category. Never blocks posting — logs only.

Usage: python3 research-check.py "message text"
Exit 0 always (never blocks delivery).
"""

import re
import sys
from datetime import datetime, timezone
from pathlib import Path

FRICTION_LOG = Path.home() / "helm-workspace" / "system" / "friction-log.md"

# Patterns indicating an uncited factual question (agent asking instead of researching)
# Use permissive .{1,30} to match multi-word subjects including version numbers
QUESTION_PATTERNS = [
    # "Is X released/available/out?" — should do web search
    re.compile(r"\bIs\s+.{1,30}\s+(released|available|out|live|ready|published)\?", re.I),
    # "Was X implemented/built/done/shipped?" — should do QMD/impl-check
    re.compile(r"\bWas\s+.{1,30}\s+(implemented|built|done|shipped|added|created|merged)\?", re.I),
    # "Do we have X spec'd/built/done?" — should do QMD
    re.compile(r"\bDo we have\s+.{3,50}\?", re.I),
    # "Does X exist/work/support?" — should check first
    re.compile(r"\bDoes\s+.{1,30}\s+(exist|work|support|have|include)\?", re.I),
    # "Has X been X'd?" — should check
    re.compile(r"\bHas\s+.{1,30}\s+been\s+\w+\?", re.I),
    # "What's the status of X?" — should check state files
    re.compile(r"\bWhat'?s? (the )?status of\s+.{3,40}\?", re.I),
]

# Research citation markers — if any are present, the agent did research
CITATION_MARKERS = [
    "QMD:", "Web:", "RESEARCH:", "Checked:", "Verified:", "grep", "git log",
    "searched", "found in", "confirmed in", "per ", "according to",
    "friction-log", "task-registry", "engineer-queue",
]

# Exclude: messages that start with ⏸ (BLOCK) are allowed to ask questions
# Also exclude short messages (< 100 chars) — they're usually ACKs
MIN_LENGTH = 40


def has_citation(message: str) -> bool:
    msg_lower = message.lower()
    return any(marker.lower() in msg_lower for marker in CITATION_MARKERS)


def find_violations(message: str) -> list[str]:
    if len(message) < MIN_LENGTH:
        return []
    # Skip BLOCK messages — they're allowed to ask questions as part of their format
    if message.lstrip().startswith("⏸"):
        return []
    # Skip if research is cited somewhere in the message
    if has_citation(message):
        return []

    violations = []
    for pattern in QUESTION_PATTERNS:
        m = pattern.search(message)
        if m:
            violations.append(f"B-11/B-12: uncited question detected: '{m.group()}'")
    return violations


def log_violation(violation: str):
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    line = f"{ts} RESEARCH-SKIPPED: {violation}\n"
    try:
        with open(FRICTION_LOG, "a") as f:
            f.write(line)
    except Exception:
        pass


def main():
    if len(sys.argv) < 2:
        sys.exit(0)

    message = sys.argv[1]
    violations = find_violations(message)

    for v in violations:
        log_violation(v)
        print(f"research-check: {v}", file=sys.stderr)

    # Always exit 0 — this check is logging-only, never blocks
    sys.exit(0)


if __name__ == "__main__":
    main()
