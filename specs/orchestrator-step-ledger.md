# [ARCHIVED — Orchestrator removed 2026-06-10]
# ORCHESTRATOR-STEP-LEDGER — Engineer Spec

## Problem
Agents run as long-lived Claude processes (5-15 min). When they go silent mid-task:
- Watchdog can't tell "alive and working" from "hung" 
- Kills it, spawns resume — which starts from scratch
- Produces duplicate work, duplicate messages, and wasted tokens

The ACK-routing gate exists in bot.js (line 3466) but calls `orchestrate.sh` which doesn't exist.
When the gate fires, it fails silently and the long agent runs anyway — no safety net.

## Root cause (verified 2026-06-07)
1. `~/marvin-bot/orchestrator/` directory does not exist
2. No step ledger (no way to resume mid-task without redoing completed steps)
3. No PID/heartbeat check before killing (watchdog can't distinguish working vs. stuck)

## What to build

### Part 0 — Pre-spawn hard gate (bot.js, highest priority, no orchestrator needed)
**Problem:** An agent completes its DELIVER, user sends a follow-up message, a new agent spawns and re-runs the prior analysis from scratch because it sees an open channel.
**Fix:** At message intake in bot.js (before spawning any agent):
1. Check: is there a DELIVER for this channel after the last user message?
   - Get `lastUserMsgAt` from channel-state
   - Get `lastDeliverAt` from channel-state (set whenever bot posts a ✅ message)
   - If `lastDeliverAt > lastUserMsgAt` → **don't spawn**. The last user message is already answered.
2. Exception: if the message is "Update", "Status?", or similar lightweight status requests → spawn a Haiku status agent that reads thread context only (no re-analysis).
3. This is pure bot.js logic — no orchestrator dependency. Ship this first.

**Where in bot.js:** Message handler, before `launchAgent()`. Check state file, gate on lastDeliverAt vs. lastUserMsgAt.

### Part 1 — orchestrate.sh (unblocks the ACK-routing gate)
Create `~/marvin-bot/orchestrator/orchestrate.sh` that:
- Accepts `--task`, `--channel`, `--skip-expand`, `--skip-decompose`, `--workspace-md`, `--agent` flags (bot.js passes these already)
- Decomposes task into steps using a Haiku call (expand + decompose)
- Spawns one Claude call per step — each is 1-3 min max
- Writes step results to `~/pap-workspace/channel-state/{channelId}-steps.json` after each step
- Posts ⏳ UPDATE to Discord between steps
- Posts ✅ DELIVER when all steps complete
- Reads existing `-steps.json` on entry — skips steps already marked `done`

Step ledger format (`{channelId}-steps.json`):
```json
{
  "channelId": "...",
  "task": "...",
  "createdAt": 1234567890,
  "steps": [
    { "id": 1, "desc": "...", "status": "done", "result": "...", "completedAt": 1234567890 },
    { "id": 2, "desc": "...", "status": "in_progress", "startedAt": 1234567890 },
    { "id": 3, "desc": "...", "status": "pending" }
  ]
}
```

### Part 2 — Heartbeat / PID check before watchdog kill
In bot.js silence watchdog (around line 1173 where the kill fires):
- Before SIGTERM, check if `agentPid` process is still alive: `process.kill(pid, 0)` (doesn't kill, just checks)
- If alive: post ⏳ "Agent is still running — giving it more time" and extend the threshold 60s
- If dead: proceed with kill + auto-resume (current behavior)
- Cap: max 3 extensions per agent spawn to prevent infinite hangs

### Part 3 — Duplicate post dedup (idempotency key)
Already partially covered by ENG-WATCHDOG-DEDUP-001 (10s delay).
Remaining gap: if two DELIVER messages slip through within 30s on same channel, suppress the second.
In bot.js DELIVER handler: check `lastDeliverAt[channelId]`. If < 30s ago, drop and log.

## Success criteria
- Agent with 4-step ACK gets decomposed into 4 separate Claude calls
- Kill of any one step → resume reads ledger, skips done steps, continues from step N+1
- No duplicate DELIVERs on same channel within 30s
- Watchdog extends instead of killing an alive-but-slow agent (up to 3x)

## Priority: HIGH
## Estimated build time: 3-4 engineer sessions
## Depends on: nothing (bot.js wiring already done)
