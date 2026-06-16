# [ARCHIVED — Orchestrator removed 2026-06-10]
# HELM Engineer Run — June 8 Spec
# Based on: helm-architecture-v3-design.md + {{USER_JERRY}}'s Q&A feedback (Session 133)
# Status: APPROVED — implement tonight
# Rollback tag: v3-stable-pre-jun8-run

---

## Rollback Instructions (read first)

```bash
# If anything breaks:
git -C ~/marvin-bot checkout v3-stable-pre-jun8-run
~/marvin-bot/safe-restart.sh --force
```

That tag captures the state after last night's Phase 0-3 deploy.
Revert to it and the system returns to exactly where it was at 10:40pm June 7.

---

## What's Already Live (do not re-implement)

- Phases 0-3 from v3: silent violations, violation tracker, checkpoint heartbeat, sparse-sentinel guard
- Orchestrator: disabled unless ORCHESTRATOR_ENABLED=true (already gated)
- helm-improvements: extended to 15-min silence threshold

---

## Tonight's 5 Phases (ordered by impact, run sequentially with QA between each)

---

### Phase 1: Ghost Code Removal (~45 min)

Removes code that fights the v3 design. Highest impact — do this first.

**What to remove from bot.js:**

1. ACK-phase orchestrator routing (~lines 3488–3506):
   The `orchIntentConfirmed` block including `isConversational`, `orchLongEstimate`,
   `orchMultiStep`, and the `setImmediate(() => runOrchestrator(...))` call.
   Replace with nothing — orchestrator is now sentinel-only.

2. All 14 `msg.reply()` violation responses:
   Lines ~3591, 3627, 3671-3679, 3697, 3827, 3881, 3910, 3948, 3977, 4014, 4040, 4087, 4136, 4185, 4284.
   Replace EACH with: `appendEvent(channelId, { type: 'violation_detected', ... })` only.
   No react. No reply. Violations are silent.

3. Checkpoint restore on DELIVER schema failure (~line 3539):
   The block that restores checkpoint so agent can "retry" after a schema violation.
   Replace with: log violation to friction-log, let turn end. Next user message starts clean.

**QA for Phase 1:**
- Send a test message to any workspace channel
- Confirm no 🤖 reaction appears
- Confirm no violation reply message appears
- Confirm event appears in friction-log.md if violation triggered

---

### Phase 2: Universal Agent Ledger (~60 min)

Every agent spawn is tracked. Every completion is recorded. Pre-spawn check prevents redundant work.

**New file: ~/pap-workspace/channel-state/agent-ledger.json**

Structure:
```json
{
  "entries": [
    {
      "entryId": "uuid",
      "channelId": "1234567890",
      "pid": 39037,
      "spawnedAt": 1780898135072,
      "task": "first 200 chars of agent prompt",
      "status": "in_progress",
      "deliveredAt": null,
      "killedAt": null,
      "completedSteps": []
    }
  ]
}
```

**Bot.js changes:**

On agent spawn:
- Append entry to agent-ledger.json with status: "in_progress"
- Include `task` (truncated prompt, first 200 chars)
- Include `pid` (child process PID)

On DELIVER received:
- Find entry by `channelId + pid`
- Update: `status: "delivered"`, `deliveredAt: now`

On timeout kill:
- Find entry by `channelId + pid`
- Update: `status: "killed"`, `killedAt: now`

On agent respawn (recovery from silence/timeout):
- Read last ledger entry for this channelId
- Inject into agent context: `[Prior session: task='...', status='killed', completedSteps=[...]]`
- Agent reads this before starting — picks up rather than restarting

**Pre-spawn check:**
Before spawning a new agent for a channel:
- Check if last ledger entry for that channelId has `status: "delivered"` AND same task fingerprint
- If yes: skip spawn. Log: "skipped respawn — task already delivered"

**QA for Phase 2:**
- Spawn an agent with a simple task
- Kill it manually (`kill -TERM <pid>`)
- Check agent-ledger.json shows `status: "killed"`
- Send same message again
- Confirm new agent sees prior session context in its prompt
- Complete a task normally
- Confirm agent-ledger.json shows `status: "delivered"`

---

### Phase 3: PID Watchdog + Dynamic Timeouts (~45 min)

Current gap: watchdog only watches Discord silence. Adding PID check and ETA-based dynamic thresholds.

**Bot.js changes (watchdog tick, runs every 30s):**

Step 1 — PID check:
```
if agentPid exists in channel state:
  run: ps -p agentPid (no output needed, just exit code)
  if exit code != 0 (PID gone):
    if lastAgentMsgPhase != "deliver":
      mark channel: agentOrphaned=true, orphanedAt=now
      trigger recovery spawn (same as silence recovery)
    else:
      clear agentPid (clean exit, deliver already posted)
```

Step 2 — Dynamic timeout:
Parse ACK message for:
- `"About N min"` → ETA = N × 60 sec
- `"updates every M sec"` or `"updates every M min"` → cadenceSec = M
- `"Estimate uncertain"` → use defaults (ETA=300, cadence=90)

Kill threshold logic:
```
if ETA declared:
  warnAt = ETA × 1.2
  killAt = ETA × 1.5
elif cadenceSec declared:
  warnAt = cadenceSec × 2
  killAt = cadenceSec × 3
else:
  warnAt = 180s (current default)
  killAt = 270s (current default)
```

**QA for Phase 3:**
- Spawn agent that declares "About 2 min, updates every 45 sec"
- Wait — confirm warn triggers at ~2.4 min (144s), kill at ~3 min (180s)
- Spawn agent, manually kill PID, confirm watchdog detects within 30s and respawns

---

### Phase 4: Daily PM Mandate Digest (~20 min)

{{USER_JERRY}}'s call: PM works on mandates every day. Not weekly.

**Changes:**

1. Find PM sweep cron (likely in bot.js PM_TRIGGER_INTERVAL or a cron entry)
   Change violation digest from weekly to daily

2. PM daily digest format (posted to helm-improvements):
   ```
   ⏳ Daily mandate check
   Violations since yesterday: [N total across [M] types]
   Top pattern: [violation type] — [X] occurrences
   Action: [queued engineer fix / PM improving prompt / within threshold]
   ```

3. Threshold for PM action: if same violation type appears 3+ times in 24h (not 7 days)

**QA for Phase 4:**
- Check PM cron schedule is daily
- Verify violation-summary.json gets read on each PM sweep
- Manually trigger a PM sweep and confirm it posts digest format

---

### Phase 5: Gate Checks Visible in Updates (~30 min)

{{USER_JERRY}}'s call: gate checks should align with updates. Tell the user what's happening every time.

**Turn protocol change:**

Before every ⏳ UPDATE, agent adds a one-line gate status:
Format: `⏳ Gate: B-01 ✓ | B-22 ✓ | [what I'm doing now]`

If a gate check fails:
Format: `⏳ Gate: B-01 blocked (file not verified yet — verifying now) | then: [task]`

**Agent prompt change (in turn-protocol.md):**
Add under "UPDATE (Phase 2)" section:

```
UPDATE format: ⏳ Gate: [B-01 status] | [B-22 status] | Currently [verb] [object].
B-01 status: ✓ (last claim verified) or blocked (verifying now)
B-22 status: ✓ (no multi-step list pending) or n/a (not near DELIVER yet)
```

**QA for Phase 5:**
- Post a multi-step task to any channel
- Watch for UPDATE messages
- Confirm gate status line appears before each update
- Confirm gate shows blocked state when B-01 issue detected

---

## QA Master Checklist (run after all 5 phases)

After all phases deployed, run these 5 end-to-end tests:

1. Simple task → no 🤖 reactions, no violation replies
2. Multi-step task → agent-ledger.json gets written, gate checks in updates
3. Kill agent mid-task → watchdog detects within 30s, respawn reads prior ledger entry
4. ETA-declared task → dynamic kill threshold used (not hardcoded 8 min)
5. Violate B-01 in test → friction-log.md gets entry, no user-visible message

---

## File Change Summary

| File | What changes |
|---|---|
| ~/marvin-bot/bot.js | Ghost code removal, PID watchdog, dynamic timeouts, ledger writes, daily PM digest |
| ~/.claude/agents/turn-protocol.md | Gate check format in UPDATE section |
| ~/pap-workspace/channel-state/agent-ledger.json | New file, created on first spawn |

---

## Open Items (not in tonight's run)

- B-19 violation: helm-architecture-v3-design.md should be on GitHub (not local path)
  Action: engineer pushes to pap-config repo, post URL to {{USER_JERRY}}
- Orchestrator end-to-end test: do a real orchestrated task once core system is stable
