# Task Ledger — Unified Lifecycle Tracking Spec
# Draft 2026-06-10 — Level 4 proposal, awaiting {{USER_JERRY}} approval

## Problem (root cause, evidenced)

Six trackers built in ~6 weeks, all rotted the same way:

| Tracker | Created | Status today |
|---|---|---|
| MASTER-BACKLOG.md | early | demoted to read-only archive |
| work-items.json (WI-001, "single source of truth") | 2026-05-25 | last_updated 2026-06-08 — stale; engineer-queue items since then absent |
| QUEUE-VIEW.md | ~2026-06-03 | header now reads "⚠️ STALE, DO NOT TRUST" |
| engineer-queue.md | ongoing | works, but had "stale re-queue (7th+ time)" items — state not trusted |
| workstreams.json | 2026-06 | alive (PM-only, evidence rule helps) |
| idea-queue / idea-backlog / project-backlog / design-tracker | various | fragmented concept-stage tracking |

**The one tracker that never rotted: agent-ledger.jsonl (416+ entries).** It is written
by bot.js code on events (spawn/DELIVER/BLOCK/exit), not by agents following prompt rules.

**Root cause: every failed tracker depended on agent discipline (prompt-level rules) to
stay current. Every surviving tracker is written by code. Prompt-enforced tracking rots;
code-enforced tracking survives.**

Secondary cause: stores and views were conflated. QUEUE-VIEW was a hand-maintained view —
views must be generated artifacts, never hand-edited.

## Design

### 1. One store: system/task-ledger.jsonl (append-only events)

Event types: `created`, `spec_written`, `approved`, `queued`, `picked_up`, `progress`,
`blocked`, `unblocked`, `done_claimed`, `verified`, `shelved`, `reopened`.

Event shape:
```json
{"ts":"<date -u>","task_id":"TL-001","event":"picked_up","actor":"engineer",
 "workspace":"platform|etf-tracker|...","detail":"...","evidence":"file:line or log ref"}
```

Current state of any task = fold of its events. No state field to go stale.

**All writes go through ONE script: `task-event.sh`** which:
- validates the transition (can't go queued→verified without picked_up + done_claimed)
- stamps timestamp via `date -u` (kills fabricated-timestamp class, see workstreams note)
- requires `evidence` for `done_claimed` and `verified` (extends verified_by rule from work-items.json)
- appends atomically (flock)

bot.js ALSO emits events automatically where it has signal:
- engineer spawn on a queue item → `picked_up` (code, not agent discretion)
- DELIVER referencing a task_id → `done_claimed`
- silence-watchdog kill mid-task → `blocked` with detail=watchdog

### 2. Views: generated only, never hand-written

On every ledger append, bot.js regenerates:
- `system/TASK-BOARD.md` — full board: Pipeline (concept/design/queued/in-progress/blocked/waiting-on-{{USER_JERRY}}/done-this-week) + Running Now (joined from agent-ledger + checkpoints)
- **ONE pinned Discord message per surface, edited in place** (proven pattern: DECISION-DIGEST-001):
  - mission-control (or designated tracking channel 1514116690319900735): full board, plain English, no internal IDs without translation
  - each workspace channel: pinned board filtered to `workspace==<name>`

Pinned-edited-in-place beats new posts (no scroll archaeology, always current) and beats
files ({{USER_JERRY}} is mobile-first, can't open files).

### 3. Enforcement (why this one sticks)

- **Claim gate (bot.js, extends CLAIM-VERIFY at ~4109):** DELIVER text claiming
  queued/built/done/fixed with no matching ledger event in last 15 min → violation log +
  🤖 reaction. Narration without state transition becomes detectable — this is the S132
  "queue reality gap" fix at the structural level.
- **Staleness daemon (nightly):** queued >48h with no pickup, in-progress >24h with no
  progress event → auto-flagged ⚠️ on the board (no agent judgment involved).
- **Workspace adoption for free:** scaffolder template includes task-event.sh usage;
  workspace items are namespaced rows in the same ledger. Future workspaces inherit
  tracking with zero new files.

### 4. Migration (one-time)

1. Freeze: idea-queue, idea-backlog, project-backlog, design-tracker, work-items.json,
   QUEUE-VIEW → superseded headers pointing at TASK-BOARD.md.
2. Import open items (work-items.json open + engineer-queue pending/proposed + workstreams
   active) as `created`+current-state events with `detail:"migrated"`.
3. engineer-queue.md remains the engineer's work order format short-term; queue-write.sh
   gains a task-event.sh call so both stay in sync until queue is folded in (phase 2).
4. workstreams.json (PM board) stays — it tracks PM lines-of-work, not task lifecycle;
   streams reference task_ids.

### Conflict note

AGENT-BOARD-001 (queued HIGH, pending) covers only "running right now." This spec absorbs
it — TASK-BOARD.md includes that section. On approval: replace AGENT-BOARD-001 with
TASK-LEDGER-001 (build script+gates) and TASK-BOARD-002 (views+pins) to avoid double-build.

### Build estimate

- task-event.sh + ledger + migration: ~90 min, no restart
- bot.js board regen + pinned message editing + claim gate: ~120 min, queue-restart
- scaffolder template update: ~20 min, no restart
