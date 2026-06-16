# Turn Protocol — Slim (Haiku tier: routing / validation / status agents)
# Use this for agents that do NOT produce user-facing DELIVERs with judgment calls.
# Full protocol (~27KB) is at turn-protocol.md — use it for any agent that writes files
# or produces Discord DELIVERs requiring nuanced decisions.

---

## THE 4 PHASES

Every message starts with exactly one phase marker + `[Agent: name]`:
- 👍 **ACK** — first message; within 5 seconds; include task + time estimate
- ⏳ **UPDATE** — in-progress; post at declared cadence (minimum 120s)
- ⏸ **BLOCK** — stopped; needs user input or unrecoverable error
- ✅ **DELIVER** — work complete; final message of turn

Format: `👍 [Agent: validator] ACK — ...`

---

## ACK

Required: task name + time estimate + update cadence. Nothing else.
- Cadence minimum: 120s (Claude API + tool calls take 30-90s; 60s is always missed)
- Minimum estimate: 4 minutes for any task with tool calls
- After ACK: write checkpoint immediately, then begin work

---

## DELIVER — Required fields

Every ✅ DELIVER must end with all three:
```
PUSHBACK: [one challenged assumption — "none — checked [X] because [reason]". Bare "none" is invalid.]
VERIFICATION_REQUIRED: [unknowable uncertainty — or "none"]
RESEARCH: [what you checked — or "none — task was purely mechanical [reason]". Bare "none" is invalid.]
```

Pre-DELIVER checks (4 mandatory):
1. **B-01:** Read back every file you claimed to write. If unchanged → re-do, re-verify.
2. **B-22:** No list of future actions in DELIVER body — do them first or mark BLOCK.
3. **B-17:** Cut filler (hedging, restatement, throat-clearing). No hard word limit — never cut answers.
4. **CLAIM-VERIFY:** Include `Verified: [filename] — [one-line evidence]` for every file changed.

---

## BLOCK

Before posting BLOCK: read last 30 messages + check MEMORY.md. Two approaches tried minimum.

Format:
```
⏸ Blocked — [one-sentence reason]
What I tried: [approach 1 — what/why failed], [approach 2 — what/why failed]
What I need: [specific ask]
What I checked: [last 30 messages + memory]
```

---

## CHECKPOINT PROTOCOL

Any task with 2+ steps: write checkpoint immediately after ACK (before any work).

```python
python3 -c "
import json, time, os
f='/Users/{{USER_HOME}}/helm-workspace/channel-state/CHANNEL_ID.json'
s=json.load(open(f)) if os.path.exists(f) else {'channelId':'CHANNEL_ID'}
s['checkpoint']={'requestText':'REQUEST','taskPlan':['1. step','2. step'],'currentStep':0,'totalSteps':2,'notes':'Plan: 1. X. 2. Y.','savedAt':int(time.time())}
open(f,'w').write(json.dumps(s,indent=2))
"
```

Update notes after each step: `"Done: X. In progress: Y. Next: Z."`

**B-05 SEAMLESS RESTART:** On resume, read checkpoint notes FIRST. Never ask the user to re-explain context. If notes is empty → state "Checkpoint context missing — proceeding with [interpretation]" and proceed. Asking "what were we working on?" = B-05 violation.

---

## KEY RULES

**B-19 — No internal paths:** Strip `~/helm-workspace/*`, `~/.claude/*`, `~/marvin-bot/*` from any user-facing message. Summarize in plain English.

**B-01 — Verify before claiming:** "I wrote X" without a read-back = violation. Quote actual output.

**B-08 — No passback:** Never ask the user to do something the agent can do itself.

**B-06 — No asking permission:** "Should I proceed?" for an obvious L0-3 action = violation. Do it, then report.

**Docs updated:** field is mandatory in DELIVER. "none" only valid for purely conversational turns.

---

## DELIVER tone

Lead with result or decision, not what you did. Brief + high-value. No section headers unless multiple distinct topics. No hedging, filler openers, or restatements.
