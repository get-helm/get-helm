# [ARCHIVED — Orchestrator removed 2026-06-10]
# Orchestrator History Review — Full Timeline + Recommendation
**Date:** 2026-06-09 | **Requested by:** {{USER_JERRY}} (#helm-improvements thread)
**Question:** Is the orchestrator the right solution for "know what every agent is doing + resume seamlessly after disruption" — or should it be replaced?

---

## Timeline (verified against memory, postmortem, specs, bot.js)

| Date | Event |
|---|---|
| 2026-05-13 | Mastra orchestrator designed, built, integrated into bot.js, tested with 2 real tasks. Pushback recorded same day: blast radius (one broken orchestrator breaks all in-flight tasks), state-persistence circularity, over-engineering risk ("might be fixable with cleaner instructions + SQLite checkpointing"). |
| 2026-05-13 (overnight) | Edge-case tests passed; {{USER_JERRY}} approved auto-routing. |
| 2026-06-05 | Node path bug fixed; component self-test 4/4 (deps load, expand runs, Discord posts). Components only — not the live routing path. |
| 2026-06-07 | **Major outage.** Root causes (postmortem): (1) ACK-phase auto-routing false positives — normal status messages routed into orchestrator; (2) queue divergence — engineer-queue.md vs task-registry.jsonl both claimed authority; (3) silent recovery failure — PM narrated "healthy" while work was stalled. Resolution: `ORCHESTRATOR_ENABLED=false` + manual restart. |
| 2026-06-08 | **Recurrence/cascade.** Led to Architecture v2/v3: ACK-phase routing removed entirely, sentinel-only trigger, mandatory fallback (orchestrate.sh fails → agent continues directly), universal agent ledger, PID watchdog. |
| 2026-06-09 (today) | Flag still `false`. bot.js additionally requires a valid `orchestrator-level4-approved.json` to re-enable (bot.js:5910-5923). All [ORCHESTRATE:] sentinels currently fall through to direct agent handling (bot.js:5469). |

## Contradiction flagged (this week's work)

The threshold-lowering CLAUDE.md change and FIX-ORCHESTRATOR-002 (expand/decompose rubric) both target a **disabled** system. Agents emitting [ORCHESTRATE:] today get silently routed to direct handling. Neither change is wrong, but neither has any effect until the flag question is decided.

## Key insight: tracking ≠ execution

{{USER_JERRY}}'s goal is PM-style visibility: who's working, on what, how far, resume after disruption. The orchestrator conflates that with *executing* the work. A PM doesn't do the team's work to see it — the team reports to a shared board.

Both outages came from the **routing layer** (deciding what goes through the orchestrator), never from step execution. Every attempt to widen routing so "everything is tracked" recreates the June 7 failure mode.

## What already exists (live, all agents, orchestrator-independent)

1. **agent-ledger.jsonl** — every spawn/deliver/block/kill with task text + PID, written by bot.js (469 entries, confirmed writing today)
2. **Checkpoint protocol** — per-channel JSON with taskPlan, currentStep, notes; read on auto-resume; FIX-RESTART-001 warns on empty notes
3. **PID-alive watchdog extension** — checks process before killing (ORCHESTRATOR-STEP-LEDGER-001 Part 2, live in bot.js ~1522/1595)
4. **Pre-spawn dedup gate** — lastDeliverAt vs lastUserMsgAt prevents duplicate respawns
5. **task-registry.jsonl** — queue history

## What's missing for the PM-board experience

1. **A live board view** — nothing joins ledger + checkpoints into "what's running right now, how far along, what's stuck." QUEUE-VIEW.md covers platform work items, not live agent tasks. This is a read-only generator (~1-2h engineer work): for each active spawn without a later deliver, show agent, task, checkpoint step N/M, notes, age.
2. **Checkpoint compliance** — machinery is live but agents skip mid-task currentStep updates (B-03). Enforcement/measurement gap, not a build gap.
3. **Resume-reads-ledger** — v3 decision #1 (respawn reads prior ledger entry before starting from scratch) — partially implemented; verify coverage.

## Recommendation

**Keep both, separate their jobs:**
- **Tracking layer** = ledger + checkpoints + new board view. Works for ALL agents, no routing decision, no single point of failure. This answers {{USER_JERRY}}'s actual ask.
- **Orchestrator** = opt-in execution engine for genuinely complex multi-step tasks only (sentinel with 3+ typed steps — already the v3 gate). Re-enable later, only behind the FIX-ORCHESTRATOR-002 rubric and the L4 approval file, after the board exists.

**Do not** route everything through the orchestrator to get visibility — that's the pattern that caused both outages.

## Decision presented to {{USER_JERRY}}

A) Tracking-first (recommended): build live board + checkpoint compliance, keep orchestrator off for now.
B) Also re-enable orchestrator sentinel-only now (requires L4 approval file + rubric built first).

---

## FINAL: REMOVED 2026-06-10 ({{USER_JERRY}} approved)

{{USER_JERRY}} approved full removal. Executed by PM agent:
- bot.js: classifyOrchTask/classifyTaskLevel/runOrchestrator, !orchestrate trigger, [ORCHESTRATE:] handoff, startup gate, orchRoutedAt — all removed. A minimal sentinel stripper remains so stray [ORCHESTRATE:] text never leaks to Discord.
- .env: ORCHESTRATOR_ENABLED line deleted. safe-restart.sh re-enable guard deleted. helm-init.sh template line deleted. grab-logs.sh orchestrator sections deleted. RECOVERY-RUNBOOK.md Scenario 1 retired.
- Code archived (not destroyed): ~/marvin-bot/archive/orchestrator-removed-20260610/
- Replacement stack: agent ledger + checkpoints (existing) + agent board (AGENT-BOARD-001, live) + checkpoint compliance gate (ACK-seeds-notes + orphaned-ACK exit detection, added 2026-06-10).
