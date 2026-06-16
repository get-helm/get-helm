# PAP Debugging Guide
## For {{USER_JERRY}} + Claude.ai sessions when things break
## Created: 2026-05-09

Use this when PAP stops working and you need to diagnose it.
Start at Step 1, stop when you find the problem.

---

## STEP 1 — Is the bot running?

Ask Marvin: "Are you there?"

- Gets a response → bot is running. Skip to Step 3.
- No response within 60 seconds → go to Step 2.

---

## STEP 2 — Restart the bot

SSH into the Mac Mini (or use Terminal directly):

```
~/marvin-bot/safe-restart.sh
```

Wait 30 seconds, then ask "Are you there?" again.

- Now responding → you're done.
- Still nothing → check the log:

```
tail -50 ~/marvin-bot/marvin.log
```

Look for lines with ERROR or "Cannot read" or "Token" — paste them into a Claude.ai session with this file.

---

## STEP 3 — Is the agent responding with the right format?

Every Marvin message should start with: 👍 ⏳ ⏸ or ✅

If a message has none of those, or Marvin just says "working on it" — that's a protocol violation.
Not an emergency, but note the channel and message if you want to report it.

---

## STEP 4 — Did an agent time out?

Signs: ❌ or ⚠️ message from the system, or "Re-trigger to retry."

**What to do:**
1. Check the channel where it happened
2. Read the last message — it will say what the agent was doing last
3. Reply in that channel: just re-send your original request

If it keeps timing out on the same task → the task is too big.
Break it into a smaller ask (one change, not five).

---

## STEP 5 — Agent said it did something but nothing happened

Check the channel-state file for the affected channel:

```
cat ~/pap-workspace/channel-state/<channel_id>.json
```

Look at:
- `lastAgentMsgPhase` — should say "deliver" if it finished
- `agentPid` — should be null if the agent isn't running
- `checkpoint.currentStep` — if this is 0, the checkpoint was never written (auto-resume is broken)

**Checkpoint bug symptoms:** agent dies, you re-send, agent starts over from the beginning instead of resuming.
Current status: KNOWN BUG — fix is in the next restart batch.

---

## STEP 6 — PM is posting but nothing is happening

Signs: #pap-improvements shows sweep reports, engineer doesn't run.

**Root cause:** PM→Engineer trigger gap. PM posts "run engineer" to Discord, bot ignores it.
**Fix:** bot.js restart batch includes PM file trigger fix. Will resolve at next restart.

Until then: if you want engineer to run something, send the request to #pap-chat directly.

---

## STEP 7 — ETF tracker or VPS isn't loading

Check the VPS from the Mac Mini:

```
curl -s https://etf.{{USER_DOMAIN}}/health
```

- Returns JSON → Flask is running. Problem is somewhere else.
- Connection refused / timeout → Flask is down.

Restart Flask on the VPS:

```
ssh {{USER_EMAIL}}[VPS IP] "sudo systemctl restart etf-tracker"
```

VPS IP is in PAP Vault as "Hostinger Root".

---

## STEP 8 — Nothing above helped. Open a Claude.ai session.

Upload these files to the Claude.ai session:
1. This file (debugging-guide.md)
2. ~/pap-workspace/ACTIVE-STATE.md
3. ~/marvin-bot/marvin.log (last 100 lines)
4. The channel-state JSON for the broken channel

Tell Claude: "PAP is broken. [Describe what's happening.] Help me diagnose and fix it using these files."

---

## KNOWN ISSUES (as of 2026-05-09)

| Issue | Status | Workaround |
|-------|--------|------------|
| Auto-resume broken (checkpoint cleared on spawn) | Fix at next restart | Re-send request |
| Model routing ignored (all agents use Sonnet) | Fix at next restart | None needed |
| PM→Engineer trigger dead | Fix at next restart | Send request directly |
| DELIVER reposted multiple times (BUG-035) | Open | Ignore duplicates |
| Timeout warn shows "0 min" (BUG-042b) | Open | Cosmetic only |
| options-helper times out on large tasks | Scoped to Chunk A | Use small task scope |

---

## RESTART BATCH — PENDING FIXES

These are written and ready to deploy at the next restart:

1. Checkpoint preservation (auto-resume fix)
2. Model routing (Haiku for PM sweeps = ~60% token reduction)
3. PM→Engineer trigger (PM writes file, bot watches it)
4. options-helper timeout threshold extended (900s vs 270s)

---

## ESCALATION PATH

1. Try to fix it yourself with this guide
2. Ask Marvin in #pap-chat
3. Open a Claude.ai session with this file + marvin.log
4. If bot won't start at all: SSH to Mac Mini, check launchd: `launchctl list | grep pap`
