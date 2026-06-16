# PAP Restart Validation Checklist
## Created: 2026-05-09
## Use this for every restart to verify each change works before proceeding to the next.

---

## Before Any Restart

- [ ] Create backup: `cp ~/marvin-bot/bot.js ~/marvin-bot/bot.js.bak-$(date +%Y%m%d-%H%M%S)`
- [ ] Confirm no agents currently in-flight: `cat ~/pap-workspace/channel-state/*.json | python3 -c "import sys,json; data=[json.loads(l) for l in sys.stdin if l.strip()]; [print(d.get('channelId'), d.get('agentPid')) for d in data if d.get('agentPid')]"`
- [ ] Run syntax check: `node --check ~/marvin-bot/bot.js`
- [ ] Run restart: `~/marvin-bot/safe-restart.sh`

---

## Change 1 — Model Routing

**What it does:** Parses `model:` frontmatter in agent files, passes `--model` flag to Claude CLI. PM sweeps run on Haiku instead of Sonnet.

**Verify:**
1. Ask Marvin in #pap-chat: "Are you there?" → should respond
2. Wait for next PM sweep (within 15 min)
3. Check event-stream: `tail -20 ~/pap-workspace/event-stream.jsonl | python3 -c "import sys,json; [print(json.loads(l).get('event'),json.loads(l).get('model','')) for l in sys.stdin]"`
4. PM sweep should show `model: haiku`

**Rollback trigger:** Bot doesn't respond within 60 seconds of restart.
**Rollback:** `cp ~/marvin-bot/bot.js.bak-[timestamp] ~/marvin-bot/bot.js && ~/marvin-bot/safe-restart.sh`

---

## Change 2 — PM→Engineer File Trigger

**What it does:** PM writes `pm-engineer-trigger.json` instead of posting "run engineer" to Discord. bot.js watches this file and spawns engineer automatically.

**Verify:**
1. Check bot is running (ask "Are you there?")
2. Manually write trigger file: `echo '{"task":"test trigger","queued_at":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' > ~/pap-workspace/pm-engineer-trigger.json`
3. Within 10 seconds, engineer should spawn and post to #pap-status
4. engineer-queue.md item should be cleared

**Rollback trigger:** Writing trigger file produces no engineer spawn after 30 seconds.

---

## Change 3 — Checkpoint Preservation (Auto-Resume)

**What it does:** Stops bot.js from clearing checkpoint on agent spawn. Dead agents resume from last checkpoint step instead of starting over.

**Verify:**
1. Start a multi-step task in any workspace channel
2. Wait for it to write a checkpoint (check channel-state JSON, `checkpoint.currentStep` > 0)
3. Kill the agent manually: `kill $(cat ~/pap-workspace/channel-state/[channel_id].json | python3 -c "import sys,json; print(json.load(sys.stdin).get('agentPid',''))")`
4. Re-send your original message in that channel
5. Agent should pick up from the checkpoint step, not step 0

**Rollback trigger:** Agent always restarts from step 0 regardless of checkpoint.

---

## Change 4 — Thread Support

**What it does:** Detects Discord thread channel types (11/12), routes replies to correct parent channel context. All ACK/UPDATE messages go inside the thread.

**Verify:**
1. Send a message in #general
2. Reply in the thread that bot creates
3. Bot should respond inside the same thread, not in the main channel
4. ACK and UPDATE messages should be in the thread, not visible in main channel

**Rollback trigger:** Thread replies create new top-level messages in the main channel.

---

## Change 5 — Auto Context Reset

**What it does:** Counts user messages per channel. At threshold 15, compacts state into ACTIVE-STATE.md and starts fresh spawn with that summary at the top of context.

**Verify:**
1. In #pap-chat, send 15 messages (can be short "test 1" through "test 15")
2. 16th message should trigger a fresh spawn
3. Fresh spawn should reference ACTIVE-STATE.md content accurately
4. Conversation should continue coherently despite the context switch

**Rollback trigger:** Bot loses context or behaves incorrectly after the 15-message threshold.

---

## After All Changes

- [ ] Ask Marvin: "Run through the restart validation checklist and confirm all 5 changes are working."
- [ ] Check marvin.log for any ERROR lines: `grep ERROR ~/marvin-bot/marvin.log | tail -20`
- [ ] Check event-stream for unexpected event types: `tail -50 ~/pap-workspace/event-stream.jsonl`
- [ ] Send a test message to options-helper and confirm it picks up Chunk A from checkpoint

---

## If Something Breaks

1. Identify which change number caused the break (binary search — test change 3 by itself, etc.)
2. Restore the backup for that specific change
3. Note the failure in engineer-context.md under KNOWN BUGS
4. Post to #pap-chat: "Change N failed — [what happened]"

For Claude.ai debugging session, provide:
- This checklist
- `~/marvin-bot/marvin.log` (last 100 lines)
- `~/pap-workspace/event-stream.jsonl` (last 50 lines)
- The specific bot.js change that was applied
