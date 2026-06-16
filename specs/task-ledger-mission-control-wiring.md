# Task Ledger → Mission-Control Wiring Handoff
# Handoff spec for the mission-control workspace agent
# {{USER_JERRY}}: paste this into the mission-control channel (1505752160057561149)

## Context

HELM is shipping a unified task-ledger (TASK-LEDGER-001/002/003 in engineer queue, approved 2026-06-13).

- Store: `~/helm-workspace/system/task-ledger.jsonl` — append-only events
- Writer script: `~/marvin-bot/task-event.sh` — only sanctioned writer
- Generated board: `~/helm-workspace/system/TASK-BOARD.md` — bot regenerates on every ledger append
- Pinned surfaces: bot.js auto-edits ONE pinned Discord message per channel (mission-control, helm-improvements, each workspace channel)

Your job: surface the same data on the mission-control web dashboard so {{USER_JERRY}} has a single visual view.

## Wait until ready

Do NOT start until all three queue items are status=done in `~/helm-workspace/system/task-registry.jsonl`:
- TASK-LEDGER-001
- TASK-LEDGER-002
- TASK-LEDGER-003

Verify with: `grep TASK-LEDGER ~/helm-workspace/task-registry.jsonl | grep '"status": "done"'`
Expect 3 matches before proceeding.

## What to build

### 1. Add a Backlog tab to the existing mission-control dashboard
Stage columns matching the ledger lifecycle:
- Concept
- Design
- Queued
- In Progress
- Blocked
- Waiting on {{USER_JERRY}}
- Done (this week)

Per task row: workspace tag, plain-English title, last event timestamp, last actor, latest detail.

### 2. Read from the ledger (do not hand-update)
Source: `~/helm-workspace/system/task-ledger.jsonl`
Backend should read events on a 30-second poll (or use fs.watch). Current state of a task = fold of its events. Do NOT maintain a separate state field — recompute from the event stream.

### 3. Distinguish "Backlog" from "Running Now"
Two visually distinct sections on the dashboard:
- **Backlog** (left/main): pipeline of tracked tasks by stage — concept → done
- **Running Now** (right/sidebar): live agent activity from `~/helm-workspace/agent-ledger.jsonl` (separate file, already exists)

Both views matter. {{USER_JERRY}} called this out explicitly: tracked-pipeline work and ad-hoc-conversation work are different and both need to be visible.

### 4. Plain English only
- Translate internal IDs (TASK-069, INF-23, etc.) to plain English in the UI
- Workspace tags: `etf-tracker`, `options-helper`, `helm-platform`, etc.
- No raw JSONL fields shown to the user
- Mobile-first layout ({{USER_JERRY}} reads on phone)

### 5. Filters
- By workspace (multi-select)
- By stage (chip toggles)
- "Waiting on {{USER_JERRY}}" pinned to top by default

### 6. No write path
The mission-control dashboard is READ-ONLY against the ledger. State changes happen only through `task-event.sh` (called by agents). Do not add a UI for marking tasks done — that breaks the code-enforced tracking guarantee that made this stick.

## Auth

Reuse existing mission-control site auth (PAP Vault entry "{{USER_DOMAIN}} Site Auth"). No new credentials.

## Done criteria

1. Backlog tab loads in under 2s
2. Reflects ledger events within 60s of write
3. Running Now section shows current agent activity (joined from agent-ledger.jsonl)
4. Mobile layout works on iPhone Safari
5. Read-only — no UI write paths to the ledger
6. Posts a one-line completion update to helm-improvements ({{USER_CHANNEL_HELM_IMPROVEMENTS}})

## Estimate

~3 hours total (backend reader + frontend tab + filters + mobile layout + auth wiring).

## Out of scope

- Building the ledger itself (engineer is doing that)
- Pinned Discord boards (bot.js generates those, not mission-control)
- Editing the ledger from the UI
- Replacing the existing mission-control workspaces tab — add a tab, don't replace
