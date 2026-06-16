#!/usr/bin/env python3
"""self-reflect.py — Pre-post self-reflection gate (AGENT-SELF-REFLECTION-001 + SELF-REFLECT-COVERAGE-001)

Called by discord-post.sh before DELIVER (✅) and UPDATE (⏳) messages are posted.
Routes through Haiku (Sonnet fallback) to auto-correct violations. Never blocks delivery.

Covers:
  DELIVER: B-17 (filler-density, not word count), B-22 (future action lists), schema fields, B-06 (approval-seeking)
           B-13/B-14 (missing CAPABILITIES/SKILLS in checkpoint notes for impl tasks)
           RESEARCH-QUALITY ((inference)-only or bare 'purely mechanical')
           Q&A GATE (unanswered user questions detected via channel-state)
           B-24 (options list with no recommendation)
  UPDATE:  vagueness_flag ("still working", "almost done" with no new info)
           ACTION-NEEDED-FIELDS (missing "Why this matters:" / "Context:" in [ACTION_NEEDED:] messages)
  BLOCK:   B-BLOCK-OVERUSE (⏸ used when work is still continuing — should be [ACTION_NEEDED:] instead)
           ACTION-NEEDED-FIELDS (same field check applied to BLOCK messages)

Usage: python3 self-reflect.py "message text" [channel_id]
Output (stdout): JSON {"approved": true} OR {"approved": false, "rewritten": "..."}
"""

import json
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

CLAUDE_BIN = "/Users/{{USER_HOME}}/.local/bin/claude"
FRICTION_LOG = Path.home() / "helm-workspace" / "system" / "friction-log.md"
CHANNEL_STATE_DIR = Path.home() / "helm-workspace" / "channel-state"

# Schema fields required in every DELIVER
REQUIRED_FIELDS = ["PUSHBACK:", "VERIFICATION_REQUIRED:", "PROACTIVE_NEXT:", "Docs updated:"]

# B-22 patterns: lists of future planned actions (things not yet done)
B22_PATTERNS = [
    r"(?m)^[-*]\s+.*(will|todo|upcoming|planned|next step|to be done|schedule|queue)",
    r"(?m)Next steps?:.*\n([-*]\s+.+\n){2,}",
    r"(?m)(Should I|Want me to|Shall I|Would you like me to)",
]

APPROVAL_SEEKING = re.compile(
    r"\b(Should I\?|Want me to\?|Shall I\?|Would you like me to\?|Do you want me to\?)", re.I
)

# B-17 filler-density patterns: hedging, restatement, throat-clearing
FILLER_PATTERNS = [
    r"\bI have successfully\b",
    r"\bI wanted to let you know\b",
    r"\bAs I mentioned\b",
    r"\bAs mentioned (above|earlier|previously)\b",
    r"\bJust wanted to\b",
    r"\bPlease let me know\b",
    r"\bFeel free to\b",
    r"\bHope this helps\b",
    r"\bI hope that (helps|clarifies)\b",
    r"\bTo summarize what I did\b",
    r"\bIn conclusion\b",
    r"\bAll in all\b",
    r"\bBasically\b",
    r"\bEssentially\b",
    r"\bIt's worth noting that\b",
    r"\bI should note that\b",
    r"\bIt should be noted\b",
]

# vagueness_flag patterns for UPDATE messages
VAGUENESS_PATTERNS = [
    (r"\bstill working\b", "still working"),
    (r"\balmost done\b", "almost done"),
    (r"\bjust about finished\b", "just about finished"),
    (r"\bnearly complete\b", "nearly complete"),
    (r"\bworking on it\b", "working on it"),
]

# Implementation task indicators for B13/B14 detection
IMPL_INDICATORS = re.compile(
    r"Files changed:|Commit [0-9a-f]{6,}|\.js\b|\.sh\b|\.py\b|bot\.js|impl|implement|built|added gate|commit hash",
    re.I,
)


def detect_phase(message: str) -> str:
    """Detect message phase from leading emoji."""
    stripped = message.lstrip()
    if stripped.startswith("✅"):
        return "deliver"
    if stripped.startswith("⏳"):
        return "update"
    if stripped.startswith("👍"):
        return "ack"
    if stripped.startswith("⏸"):
        return "block"
    # Fallback: schema fields present → deliver
    if "PUSHBACK:" in message and "VERIFICATION_REQUIRED:" in message:
        return "deliver"
    return "unknown"


def count_body_words(message: str) -> int:
    """Count words in the DELIVER body only (before schema fields)."""
    body = message
    for field in REQUIRED_FIELDS:
        idx = message.find(field)
        if idx != -1:
            body = message[:idx]
            break
    return len(body.split())


def check_schema_fields(message: str) -> list[str]:
    missing = []
    for field in REQUIRED_FIELDS:
        if field not in message:
            missing.append(field)
    return missing


def check_b22(message: str) -> bool:
    """Returns True if B-22 (future action list) pattern detected."""
    for pat in B22_PATTERNS:
        if re.search(pat, message, re.I):
            return True
    return False


def check_b13_b14(message: str, channel_id: str = None) -> list[str]:
    """Check if implementation DELIVER is missing CAPABILITIES/SKILLS evidence.

    Reads checkpoint notes from channel-state JSON if channel_id provided.
    Only flags for implementation DELIVERs (commits, file changes).
    """
    violations = []

    # Only flag for implementation DELIVERs
    if not IMPL_INDICATORS.search(message):
        return violations

    # Check if message body or RESEARCH mentions capabilities/skills checks
    msg_lower = message.lower()
    has_capabilities_in_msg = "capabilities:" in msg_lower
    has_skills_in_msg = "skills:" in msg_lower

    if has_capabilities_in_msg and has_skills_in_msg:
        return violations  # Both documented in the message

    # Check checkpoint notes from channel state
    has_capabilities_in_notes = False
    has_skills_in_notes = False
    if channel_id:
        state_path = CHANNEL_STATE_DIR / f"{channel_id}.json"
        try:
            if state_path.exists():
                state = json.loads(state_path.read_text())
                cp = state.get("checkpoint") or {}
                notes = (cp.get("notes") or "").lower()
                has_capabilities_in_notes = "capabilities:" in notes
                has_skills_in_notes = "skills:" in notes
        except Exception:
            pass

    if not has_capabilities_in_msg and not has_capabilities_in_notes:
        violations.append(
            "B-13: implementation DELIVER with no CAPABILITIES check evidence "
            "(missing from message body and checkpoint notes)"
        )
    if not has_skills_in_msg and not has_skills_in_notes:
        violations.append(
            "B-14: implementation DELIVER with no SKILLS check evidence "
            "(missing from message body and checkpoint notes)"
        )

    return violations


def check_research_quality(message: str) -> list[str]:
    """Check RESEARCH: field for quality violations."""
    violations = []

    # Extract RESEARCH: field value
    match = re.search(r"RESEARCH:\s*(.+?)(?:\n[A-Z][A-Z _]+:|$)", message, re.S)
    if not match:
        return violations  # schema check handles missing field

    research_val = match.group(1).strip()

    # Bare "(inference)" with no real source
    if re.search(r"\(inference\)", research_val, re.I) and not re.search(
        r"\(web\)|\(2nd-brain\)", research_val, re.I
    ):
        violations.append(
            "RESEARCH-QUALITY: RESEARCH field is (inference)-only — must cite (web) or (2nd-brain) source, "
            "or use 'none — mechanical [reason]' for purely mechanical tasks"
        )

    # "purely mechanical" with no reason (just "none — purely mechanical" with nothing after)
    if re.search(r"purely mechanical\s*$", research_val, re.I):
        violations.append(
            "RESEARCH-QUALITY: 'purely mechanical' has no reason — must be "
            "'none — mechanical [specific reason why no research was needed]'"
        )

    # Bare "none" alone (no explanation) — schema fields sometimes written this way
    if re.fullmatch(r"none\.?\s*", research_val, re.I):
        violations.append(
            "RESEARCH-QUALITY: RESEARCH: 'none' with no explanation — must explain why "
            "(e.g. 'none — mechanical: file edit with no factual claims')"
        )

    return violations


def check_recommendation_presence(message: str) -> list[str]:
    """B-24: DELIVER with a list of options must include a recommendation sentence.

    Catches pattern: numbered list of choices with no 'I recommend' / 'Go with' / 'Option X is better'.
    """
    violations = []
    # Only check DELIVER body (before schema fields)
    body = message
    for field in REQUIRED_FIELDS:
        idx = message.find(field)
        if idx != -1:
            body = message[:idx]
            break

    # Detect numbered-list-of-options pattern (2+ numbered items, words like Option/Path/Approach)
    option_pattern = re.search(
        r"(?m)^(\d+\.|[-*])\s+(Option|Path|Approach|Choice|Alternative|Solution)\s+[A-Z0-9]",
        body, re.I
    )
    # Also detect simple numbered lists with 3+ items mentioning trade-offs
    numbered_list = re.findall(r"(?m)^\d+\.\s+\*\*", body)

    if not option_pattern and len(numbered_list) < 2:
        return violations  # Not a decision-list pattern

    # Check for recommendation language
    recommendation_pattern = re.search(
        r"\b(I recommend|recommend(?:ation)?:?\s+Option|Go with|Best option|My suggestion|"
        r"Option [A-Z] is (better|preferred|best)|I'd go with|Suggest[: ]Option|"
        r"The right call|Preferred|I lean toward|I favor)\b",
        body, re.I
    )
    if not recommendation_pattern:
        violations.append(
            "B-24: DELIVER presents options with no recommendation — "
            "add 'I recommend Option X because [reason]' before the list so {{USER_JERRY}} has a starting point"
        )

    return violations


def check_research_citation_format(message: str) -> list[str]:
    """Check RESEARCH field for proper QMD citation format.

    If RESEARCH mentions QMD/searched but lacks query=... or score=, flag it.
    """
    violations = []

    match = re.search(r"RESEARCH:\s*(.+?)(?:\n[A-Z][A-Z _]+:|$)", message, re.S)
    if not match:
        return violations

    research_val = match.group(1).strip()

    # If mentions QMD or 'searched' but no query="..." pattern
    if re.search(r"\bQMD\b|searched QMD|checked 2nd.brain|2nd-brain", research_val, re.I):
        has_query = re.search(r'query\s*=\s*["\']', research_val, re.I)
        has_score = re.search(r'score\s*=', research_val, re.I)
        if not has_query and not has_score:
            violations.append(
                "RESEARCH-QUALITY: QMD cited without query string or score — "
                "format must be: QMD: query=\"[exact phrase]\" → top result: [title] (score=[X])"
            )

    return violations


def check_filler_density(message: str) -> list[str]:
    """B-17: Scan DELIVER body for filler phrases (hedging/restatement/throat-clearing).

    Replaces the 200-word hard limit. Flags messages with 3+ filler phrases.
    """
    violations = []
    body = message
    for field in REQUIRED_FIELDS:
        idx = message.find(field)
        if idx != -1:
            body = message[:idx]
            break

    hits = []
    for pattern in FILLER_PATTERNS:
        if re.search(pattern, body, re.I):
            hits.append(pattern)

    if len(hits) >= 3:
        violations.append(
            f"B-17: DELIVER body has {len(hits)} filler phrases (hedging/throat-clearing). "
            "Remove filler; keep only sentences that answer a question, state a decision, or provide evidence."
        )
    return violations


def check_qa_gate(message: str, channel_id: str) -> list[str]:
    """Q&A GATE: Check if user asked a question that the DELIVER body doesn't address.

    Reads lastUserContent from channel-state. For each question line, checks if any
    3-word phrase from the question appears in the DELIVER body.
    """
    violations = []
    if not channel_id:
        return violations

    cs_file = CHANNEL_STATE_DIR / f"{channel_id}.json"
    if not cs_file.exists():
        return violations

    try:
        cs = json.loads(cs_file.read_text())
        last_user_msg = (cs.get("lastUserContent") or "").strip()
    except Exception:
        return violations

    if not last_user_msg or len(last_user_msg) < 10:
        return violations

    # Extract question lines
    question_lines = [l.strip() for l in re.split(r"[\n.!]", last_user_msg) if l.strip().endswith("?")]
    if not question_lines:
        return violations

    # Build DELIVER body (before schema fields)
    deliver_body = message.lower()
    for field in REQUIRED_FIELDS:
        idx = message.lower().find(field.lower())
        if idx != -1:
            deliver_body = message[:idx].lower()
            break

    for q_line in question_lines:
        words = re.sub(r"[^a-z0-9 ]", "", q_line.lower()).split()
        if len(words) < 3:
            continue
        found = False
        for i in range(len(words) - 2):
            phrase = " ".join(words[i:i+3])
            if phrase in deliver_body:
                found = True
                break
        if not found:
            violations.append(
                f"Q&A GATE: question appears unanswered — \"{q_line[:80]}\" "
                "— add a direct answer before posting"
            )

    return violations


def check_vagueness(message: str) -> list[str]:
    """Check UPDATE messages for vagueness patterns with no new concrete info."""
    violations = []

    for pattern, label in VAGUENESS_PATTERNS:
        if re.search(pattern, message, re.I):
            # Treat as violation only if total word count is low (pure vague phrase, no new info)
            word_count = len(message.split())
            if word_count < 45:
                violations.append(
                    f"vagueness_flag: UPDATE contains '{label}' with insufficient new information — "
                    "report a specific finding, file name, or tool result instead"
                )
                break  # One vagueness violation is enough

    return violations


def check_block_overuse(message: str) -> list[str]:
    """Detect ⏸ BLOCK used when [ACTION_NEEDED:] is more appropriate.
    A BLOCK is overused when the agent is continuing other work while waiting on one input.
    """
    violations = []
    # Signals that work is continuing (not totally stuck)
    continuing_patterns = [
        r"\b(continuing|proceeding|still working|can still|will continue|rest of the work)\b",
        r"\b(other (items?|tasks?|work|steps?)|remaining (items?|tasks?|work))\b.*\b(proceed|continue|done|complete)\b",
        r"\b(all other|everything else|other parts?)\b.{0,50}\b(complete|done|ready|working)\b",
        r"\bneed(s)? (only|just|one|your) (approval|input|call|decision|answer)\b",
        r"\bjust (need|waiting for|require) (one|your|a)\b.{0,30}\b(input|call|answer|decision)\b",
    ]
    # Signals that it IS a total blocker (suppress false positives)
    total_blocker_patterns = [
        r"\bcannot (proceed|continue|move forward|go forward)\b",
        r"\bno (way forward|path forward|path to proceed)\b",
        r"\bcompletely (stuck|blocked|unable)\b",
        r"\bunrecoverable\b",
        r"\btried (2|two|3|three) (approaches?|alternatives?|options?)\b",
    ]
    is_total_blocker = any(re.search(p, message, re.I) for p in total_blocker_patterns)
    if not is_total_blocker:
        is_partial = any(re.search(p, message, re.I) for p in continuing_patterns)
        if is_partial:
            violations.append(
                "B-BLOCK-OVERUSE: ⏸ BLOCK used but work appears to be continuing — "
                "use [ACTION_NEEDED:] with [CONFIRM:] for a partial input needed, "
                "reserve ⏸ BLOCK for when no work can proceed at all"
            )
    return violations


def check_action_needed_fields(message: str) -> list[str]:
    """Check that [ACTION_NEEDED:] messages include required 'Why this matters:' and 'Context:' fields."""
    violations = []
    if re.search(r'\[ACTION_NEEDED:', message, re.I):
        has_why = bool(re.search(r'Why this matters:', message, re.I))
        has_context = bool(re.search(r'Context:', message, re.I))
        if not has_why and not has_context:
            violations.append(
                "ACTION-NEEDED-FIELDS: [ACTION_NEEDED:] message missing both 'Why this matters:' and 'Context:' — "
                "add: 'Why this matters: [one sentence]' and 'Context: [1-2 sentences]'"
            )
        elif not has_why:
            violations.append(
                "ACTION-NEEDED-FIELDS: [ACTION_NEEDED:] message missing 'Why this matters:' — "
                "add: 'Why this matters: [one sentence]'"
            )
        elif not has_context:
            violations.append(
                "ACTION-NEEDED-FIELDS: [ACTION_NEEDED:] message missing 'Context:' — "
                "add: 'Context: [1-2 sentences]'"
            )
    return violations


def log_violation(violation_type: str, detail: str):
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    line = f"{ts} SELF-REFLECT-{violation_type}: {detail}\n"
    try:
        with open(FRICTION_LOG, "a") as f:
            f.write(line)
    except Exception:
        pass


def call_llm_rewrite(message: str, violations: list[str], phase: str = "deliver") -> str | None:
    """Call Haiku (Sonnet fallback) to auto-fix the message. Returns corrected text or None."""
    violation_summary = "\n".join(f"- {v}" for v in violations)

    if phase == "update":
        prompt = f"""You are a protocol validator for HELM agent messages. Fix this UPDATE message to be more specific and informative. Return ONLY the corrected message — no explanation, no preamble. The rewritten message must read as if it were the original the user sees for the first time: NEVER reference that it was corrected, rewritten, revised, or adjusted. Do not add phrases like "corrected", "revised version", "updated", "I've fixed", "on second thought", or any meta-commentary about the edit. The user never sees the pre-rewrite version, so any mention of a change makes them feel they missed a message.

Rules to enforce:
- UPDATE messages must contain new, specific information (file name, finding, tool result, line number)
- Replace vague phrases like "still working", "almost done" with what was actually done or found
- Keep the ⏳ prefix and Gate status line if present
- Keep the message concise (under 50 words is fine)
- If [ACTION_NEEDED:] is present, ensure "Why this matters:" and "Context:" fields follow it

Detected violations:
{violation_summary}

Message to fix:
{message}"""
    elif phase == "block":
        prompt = f"""You are a protocol validator for HELM agent messages. Fix this ⏸ BLOCK message. Return ONLY the corrected message — no explanation, no preamble. The rewritten message must read as if it were the original the user sees for the first time: NEVER reference that it was corrected, rewritten, revised, or adjusted. Do not add phrases like "corrected", "revised version", "updated", "I've fixed", "on second thought", or any meta-commentary about the edit. The user never sees the pre-rewrite version, so any mention of a change makes them feel they missed a message.

Rules to enforce:
- B-BLOCK-OVERUSE: If agent is continuing other work while waiting on one input, rewrite as [ACTION_NEEDED:] inside an ⏳ UPDATE instead of a full ⏸ BLOCK
- ACTION-NEEDED-FIELDS: If [ACTION_NEEDED:] is present, add "Why this matters: [one sentence]" and "Context: [1-2 sentences]" if missing
- Correct format for partial input needed: ⏳ [Agent: name] UPDATE — [context]\n[ACTION_NEEDED: specific question]\nWhy this matters: [sentence]\nContext: [1-2 sentences]\n[CONFIRM: Yes|No]
- Keep ⏸ BLOCK only if the agent CANNOT proceed at all (no work is possible without user input)

Detected violations:
{violation_summary}

Message to fix:
{message}"""
    else:
        prompt = f"""You are a protocol validator for HELM agent messages. Fix this DELIVER message to comply with all rules. Return ONLY the corrected message — no explanation, no preamble. The rewritten message must read as if it were the original the user sees for the first time: NEVER reference that it was corrected, rewritten, revised, or adjusted. Do not add phrases like "corrected", "revised version", "updated", "I've fixed", "on second thought", or any meta-commentary about the edit. The user never sees the pre-rewrite version, so any mention of a change makes them feel they missed a message.

Rules to enforce:
- B-17: DELIVER body must not contain filler phrases (hedging, restatement, throat-clearing like "I have successfully", "As I mentioned", "Feel free to"). Remove filler — never cut substance or answers to questions.
- B-22: DELIVER body must NOT contain lists of future planned actions. Remove or move to PROACTIVE_NEXT.
- Schema: All 4 fields must be present: PUSHBACK:, VERIFICATION_REQUIRED:, PROACTIVE_NEXT:, Docs updated:.
  Add any missing ones with "none — [reason]".
- No approval-seeking: Remove "Should I?", "Want me to?", "Shall I?" from the body.
- RESEARCH-QUALITY: If RESEARCH field is "(inference)" only, change to "none — mechanical [reason]"
  or add the actual source. Never leave RESEARCH as bare "none" or "(inference)" alone.
- B-13/B-14: If flagged for missing CAPABILITIES/SKILLS, add to RESEARCH field:
  "CAPABILITIES: not checked — [reason]; SKILLS: not checked — [reason]"
- B-24: If flagged for missing recommendation, prepend one sentence before the options list:
  "I recommend Option [X] because [brief reason]." Do not pad — one sentence is enough.
- RESEARCH-QUALITY citation: If QMD cited without query/score, rewrite as:
  QMD: query="[infer likely query from context]" → result unknown (score not recorded)

Detected violations:
{violation_summary}

Message to fix:
{message}"""

    for model in ["haiku", "sonnet"]:
        try:
            result = subprocess.run(
                [CLAUDE_BIN, "--model", model, "--print", prompt],
                capture_output=True, text=True, timeout=6,
            )
            out = result.stdout.strip()
            if out:
                if model == "sonnet":
                    log_violation("HAIKU-FALLBACK", "Haiku unavailable — Sonnet used for rewrite")
                return out
        except subprocess.TimeoutExpired:
            # PERF-SELFREFLECT-LATENCY-001: do not chain a second model after a timeout
            # (was 30s haiku + 30s sonnet = 60s/message tax). Bail to passthrough.
            return None
        except (OSError, Exception):
            continue
    return None


# Keep old name as alias for backward compatibility
call_haiku_rewrite = call_llm_rewrite


def main():
    if len(sys.argv) < 2:
        print(json.dumps({"approved": True}))
        return

    message = sys.argv[1]
    channel_id = sys.argv[2] if len(sys.argv) > 2 else None

    phase = detect_phase(message)

    # --- UPDATE phase: check vagueness + ACTION_NEEDED field completeness ---
    if phase == "update":
        violations = check_vagueness(message)
        violations.extend(check_action_needed_fields(message))
        if not violations:
            print(json.dumps({"approved": True}))
            return

        for v in violations:
            log_violation("INTERCEPT", v)

        rewritten = call_llm_rewrite(message, violations, phase="update")
        if rewritten and len(rewritten) > 20:
            log_violation("REWRITE", f"vagueness/action_needed auto-corrected in UPDATE")
            print(json.dumps({"approved": False, "rewritten": rewritten, "violations": violations}))
        else:
            log_violation("REWRITE-FAILED", f"UPDATE rewrite unavailable, posting original")
            print(json.dumps({"approved": True, "violations": violations}))
        return

    # --- BLOCK phase: check for overuse (partial instead of total blocker) + ACTION_NEEDED fields ---
    if phase == "block":
        violations = check_block_overuse(message)
        violations.extend(check_action_needed_fields(message))
        if not violations:
            print(json.dumps({"approved": True}))
            return

        for v in violations:
            log_violation("INTERCEPT", v)

        rewritten = call_llm_rewrite(message, violations, phase="block")
        if rewritten and len(rewritten) > 20:
            log_violation("REWRITE", f"BLOCK overuse auto-corrected to ACTION_NEEDED")
            print(json.dumps({"approved": False, "rewritten": rewritten, "violations": violations}))
        else:
            log_violation("REWRITE-FAILED", f"BLOCK rewrite unavailable, posting original")
            print(json.dumps({"approved": True, "violations": violations}))
        return

    # --- DELIVER phase: full suite of checks ---
    if phase != "deliver":
        print(json.dumps({"approved": True}))
        return

    violations = []

    # B-17: filler-density (replaces 200-word hard limit per SELF-REFLECT-QA-B17-UPDATE-001)
    violations.extend(check_filler_density(message))

    # Q&A GATE: unanswered user questions
    violations.extend(check_qa_gate(message, channel_id))

    # B-22: future action lists
    if check_b22(message):
        violations.append("B-22: DELIVER body contains future planned actions (not yet done)")

    # Schema fields
    missing = check_schema_fields(message)
    if missing:
        violations.append(f"SCHEMA: missing fields: {', '.join(missing)}")

    # B-06: approval-seeking
    if APPROVAL_SEEKING.search(message):
        violations.append("B-06: approval-seeking phrase detected in DELIVER body")

    # B-13/B-14: implementation tasks missing CAPABILITIES/SKILLS evidence
    violations.extend(check_b13_b14(message, channel_id))

    # RESEARCH-QUALITY: bare inference or missing reason
    violations.extend(check_research_quality(message))

    # RESEARCH-QUALITY: QMD citation format missing query/score
    violations.extend(check_research_citation_format(message))

    # B-24: options list with no recommendation
    violations.extend(check_recommendation_presence(message))

    if not violations:
        print(json.dumps({"approved": True}))
        return

    for v in violations:
        log_violation("INTERCEPT", v)

    rewritten = call_llm_rewrite(message, violations, phase="deliver")
    if rewritten and len(rewritten) > 50:
        log_violation("REWRITE", f"{len(violations)} violation(s) auto-corrected")
        print(json.dumps({"approved": False, "rewritten": rewritten, "violations": violations}))
    else:
        log_violation("REWRITE-FAILED", f"rewrite unavailable, posting original ({len(violations)} violations)")
        print(json.dumps({"approved": True, "violations": violations}))


if __name__ == "__main__":
    main()
