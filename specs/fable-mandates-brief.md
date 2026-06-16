# [ARCHIVED — Orchestrator removed 2026-06-10]
# Fable Brief — 22 Mandates Behavior Overhaul
# Created 2026-06-09 — for use during Fable 5 trial window (through June 22)
# Companion to: specs/helm-architecture-v3-design.md (Session 133, approved decisions in memory)

## How to use this brief
Paste the Goal + Phase sections into the mandates channel (or this thread) one phase at a time.
Fable runs best on whole phases with hard done-criteria — not micro-tasks, not one mega-prompt.

---

## Goal
Make the 22 mandates (B-01 through B-22) actually enforced instead of aspirational.
Authority: v3 architecture spec already maps every mandate to one of 3 layers:
1. Agent self-check (in prompt, before posting)
2. Bot.js silent detection (observe, log, never block)
3. PM pattern loop (3+ hits/week → queued fix)

## Why patchwork failed (context Fable needs)
Prior fixes assumed agents would follow new rules. They didn't reliably. The 2026-06-03
session captured the root insight: infrastructure fixes were proposed when the real problem
was agent behavior + enforcement layering. Fixes were never validated by violation data,
so we couldn't tell if a patch worked. v3 fixes the structure; this brief executes it.

## Hard rules for every phase
- Every claim requires evidence: file read-back, grep output, or a fired test. No narration.
- Each phase ends with a written phase report: what changed, proof it works, what's still open.
- No new mandates, no scope additions. 22 mandates, 3 layers, as specced.
- User path is sacred: nothing may block a message from reaching {{USER_JERRY}}.

---

## Phase 1 — Ground-truth audit (do this first, ~1 session)
For each of the 22 mandates, determine its ACTUAL current state:
- ENFORCED: code exists, name the file + line, show the detection firing on a test string
- PARTIAL: detection exists but response is wrong (e.g., visible reply where v3 says silent log)
- ASPIRATIONAL: prompt text only, nothing detects or measures it
Output: one table, 22 rows, with evidence column. No fixes yet.
Done-criteria: every row has a code citation or an explicit "nothing found after grepping X, Y".

## Phase 2 — Layer 2 implementation (bot.js silent detection)
Implement the v3 detection table exactly: B-04/05/09/10/17/18/19/20/21 with the
two-tier visibility rules (Tier 1 silent, Tier 2 silent-recovery, Tier 3 visible).
Includes the ghost-code removals from v3 Part 1 (ACK-phase orchestrator routing,
14 visible msg.reply violations → silent appendEvent, checkpoint-restore-on-schema-fail).
Done-criteria: each detector has a test message that triggers it and a log line proving it;
removed code is verified gone by grep; commit + queue-restart (NOT force).

## Phase 3 — Layer 1 (agent self-check gates) + Layer 3 (PM pattern loop)
- Verify the 4 hard gates (B-01, B-17, B-22, CLAIM-VERIFY) appear in turn-protocol and
  every agent file that posts to Discord. Add where missing.
- Build violation-summary.json aggregation + PM sweep step: 3+ same-type hits/week →
  engineer-queue item, weekly top-3 patterns digest to #helm-improvements.
Done-criteria: a simulated week of violation events produces the digest and one queued fix.

## Phase 4 — Measurement (proves the whole thing worked)
Baseline violation counts per mandate from existing friction-log history, then weekly
comparison. The success metric for this entire effort: violation rate trending down
within 2 weeks, visible in the PM digest. If a mandate's rate doesn't move, the fix
for that mandate failed — reopen it with the data attached.
