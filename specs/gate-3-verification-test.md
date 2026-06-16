# Gate 3 Verification Test — PM Responds to DELIVER

**Status:** Final confirmation needed before Tasks 4-5 deploy

**What Gate 3 does:** When an agent posts a DELIVER in a workspace channel, bot.js marks it as `deliver_validated` and triggers a PM sweep.

**What we verified so far:** 
- deliver_validated events ARE being logged (13 total in event-stream)
- PM spawn logic IS wired in bot.js (lines 843-850)
- PM idle gate works (7 confirmed pm_skip events)

**What we still need:** Confirmation that PM actually POSTS in #pap-improvements when triggered by a DELIVER.

---

## Test Procedure (5 minutes)

### Prerequisites
- No other agents currently running or queued
- #pap-improvements channel is available
- marvin.log is tailable in a terminal

### Steps

1. **Open a terminal and tail the log:**
   ```bash
   tail -f ~/marvin-bot/marvin.log | grep -E "deliver_validated|pm_trigger|pm_skip"
   ```

2. **In Discord, queue a test DELIVER to a workspace channel.**
   
   Example: post this to #options-helper channel (or #etf-tracker):
   ```
   ✅ Test DELIVER — Gate 3 Verification
   
   What I did:
   - Read the gate 3 verification test instructions
   - Confirmed PM responds to DELIVER events
   
   Files changed:
   - gate-3-verification-test.md (this file)
   
   Verification:
   - PM should post a response within 5 minutes
   
   PUSHBACK: none
   VERIFICATION_REQUIRED: This is a test of the PM response gate
   
   Stopping. Ready for PM feedback.
   ```

3. **Observe marvin.log:**
   - Should see: `deliver_validated [channel_id] [message_id]`
   - Should see within 30s: `pm_trigger source=deliver_validated`
   - Should see within 60s: `pm_spawn [pm_pid]`
   - Should NOT see: `pm_skip` immediately after

4. **Check #pap-improvements for a PM response:**
   - Expected: PM posts a message responding to the DELIVER test
   - Within: 5 minutes of test DELIVER posting
   - Format: Should include timestamp, the delivery message reference, any findings

5. **Check decisions-log.md for PM's entry:**
   - Look for: `## YYYY-MM-DD HH:MM:SS`
   - Should contain: `Decision: Deliver gate verification test`
   - Should show: PM actually ran (not skipped)

---

## Success Criteria

✅ **PASS** if ALL of these occur:
- [ ] marvin.log shows `deliver_validated` event
- [ ] marvin.log shows `pm_trigger source=deliver_validated` within 30s
- [ ] marvin.log shows `pm_spawn` (no pm_skip)
- [ ] PM posts a message in #pap-improvements within 5 min
- [ ] decisions-log.md has a PM entry for this trigger

❌ **FAIL** if ANY of these occur:
- [ ] marvin.log shows `pm_skip` instead of pm_spawn
- [ ] No PM message appears in #pap-improvements after 5 minutes
- [ ] marvin.log shows `pm_spawn` but agent exits immediately (crash)
- [ ] decisions-log.md entry shows "no action — reason unclear"

---

## If Test PASSES

✅ Clear to deploy Tasks 4-5. Gate 3 is working.

Document in friction-analysis.md:
```
## Gate 3 Test — PASSED 2026-05-09 [time]
Verified: PM responds to DELIVER within 5 min
All three gates working (Gate 1: idle skip, Gate 3: deliver response, timing verified)
Checkpoint test next, then Tasks 4-5 cleared for engineer.
```

Then run checkpoint test (checkpoint-auto-resume-test.sh).

---

## If Test FAILS

❌ Block Tasks 4-5. Debug first.

Check these:

1. **Did PM spawn at all?**
   ```bash
   tail -50 ~/marvin-bot/marvin.log | grep pm_
   ```
   If no pm_spawn: bot.js isn't wired correctly (unlikely, it's in the code)

2. **Did PM crash?**
   ```bash
   tail -100 ~/marvin-bot/marvin.log | grep -A2 "pm_spawn"
   ```
   Look for Error or exit code != 0

3. **Did PM skip instead?**
   ```bash
   tail -50 ~/marvin-bot/marvin.log | grep pm_skip
   ```
   If this appears: PM idle gate is firing incorrectly (would need to check event-stream timing)

4. **Check PM's entry in decisions-log.md:**
   ```bash
   tail -30 ~/pap-workspace/decisions-log.md
   ```
   Look for the sweep entry. What decision did PM make?

If stuck here: post findings to #pap-improvements and wait for help.

---

## When to run this test

- **Timing:** After startup-recovery disable (Level 4 approval), before Tasks 4-5 deploy
- **Bot state:** Stable, no other tasks running
- **Backlog:** Checkpoint test is separate and comes after this one

---

**Run when ready. Report results in friction-analysis.md.**
