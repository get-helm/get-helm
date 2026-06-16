---
name: PUSHBACK-NO-OBLIGATION pattern
description: Agents name concrete PUSHBACK alternatives ("instead", "should", "needs to") without taking action or escalating
type: agent-behavioral
severity: high
duration: 4-5 consecutive days
occurrences: 40+ in last 100 friction entries
---

## Pattern
Agents write PUSHBACK field with trigger phrases ("instead," "should have," "the fix is," "needs to," "worth doing") that name a specific alternative or action, but then fail to:
1. Build the alternative (if Level 0-3)
2. Post [CONFIRM] for the alternative (if Level 4+)
3. Explicitly defer with a reason

Result: PUSHBACK names a "better way" but leaves it as advice instead of converting it to action.

## Root cause
Agents are treating PUSHBACK as "observations about the user's request" instead of "accountability for the alternative I just named." Once you name a concrete fix, you're obligated to act, propose, or defer — not leave it hanging.

## Correction
Every agent PUSHBACK field must pass the escalation gate BEFORE posting:
- Trigger words ("instead," "should," "needs to," "better approach," "worth doing") require action or escalation
- No named alternative without a decision: build (L0-3) / [CONFIRM] (L4+) / explicit defer
- The phrase "explicitly defer" in PROACTIVE_NEXT or DELIVER body counts as action

## Prevention
Add to DELIVERABLE pre-flight (turn-protocol.md § PRE-SEND SELF REVIEW item 5.5):
> **Check 5.5: PUSHBACK escalation gate** — if PUSHBACK contains "instead," "better approach," "the fix is," "should," "needs," or "worth doing," verify the message also contains ONE of: [build code], [CONFIRM], or "explicitly deferring." Missing all three = validation_failure.

Agents: if you cannot name an action or decision for a PUSHBACK alternative, remove the naming and reframe as a risk ("this could fail because") instead.
