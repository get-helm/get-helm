# [ARCHIVED — Orchestrator removed 2026-06-10]
# HELM Architecture v3 — Full Design
# Session 133 — Post-Incident Redesign
# Status: DESIGN ONLY — no implementation until {{USER_JERRY}} approves
# Authored: 2026-06-08

---

## Framing: What We're Actually Building

This isn't "how do we fix violations." It's "how do we build a system that gets work done reliably while continuously improving its own behavior."

The 22 mandates are a desired behavior profile. The question is: at which layer does each behavior get enforced, and what happens when enforcement fails?

Three design principles before anything else:

1. **User path is sacred.** Nothing — compliance detection, validation, correction — ever blocks a message from reaching {{USER_JERRY}}. If enforcement fails, the violation is logged. The message still posts.

2. **Self-correcting > externally policed.** An agent that checks itself before posting is more reliable than bot.js checking after. Bot.js is a data collector, not a cop.

3. **Patterns beat incidents.** One violation is noise. Five of the same violation in a week is a bug to fix. PM acts on patterns. {{USER_JERRY}} never hears about individual violations.

---

## Part 1: Ghost Code Audit — What to Remove

"Ghost" = code that was written for a feature we're redesigning. If we keep it, it will fight the new design.

### Remove from bot.js

**ACK-phase orchestrator routing (lines ~3488–3506)**
What it does: intercepts agent ACKs, classifies them as "implementation tasks," and silently hands them to the orchestrator. This is what caused yesterday's cascade.
Why remove: orchestrator v2 is opt-in via [ORCHESTRATE:] sentinel only. ACK-phase routing is the root cause of the silent failure mode. Nothing in the new design needs it.
Code to remove: the entire `orchIntentConfirmed` block including `isConversational` check, `orchLongEstimate`, `orchMultiStep`, and the `setImmediate(() => runOrchestrator(...))` call.

**All `msg.reply()` violation responses (14 locations)**
What they do: post visible 🤖 messages in {{USER_JERRY}}'s channel when violations are detected.
Why remove: violations should be silent. Only B-04 (silence) and B-21 (spawn fail) remain visible.
Lines to update: 3591, 3627, 3671-3679, 3697, 3827 (DELIVER incomplete schema), 3881, 3910, 3948, 3977, 4014, 4040, 4087, 4136, 4185, 4284.
Replace each with: `appendEvent(...)` only. No react, no reply.

**Checkpoint restore on DELIVER schema failure (line ~3539)**
What it does: restores the checkpoint so the agent can "retry" the DELIVER after a schema violation.
Why remove: this triggers the watchdog which re-spawns the agent which re-fails which spawns again. Cascade is the B-22 incident.
Replace with: log the violation and let the turn end. Next user message starts clean.

**`orchRoutedAt` reset logic (line 3545)**
Still needed for the sentinel path — keep this one.

### Keep in bot.js (detection logic is good, just change the response)

- All violation detection patterns (B-06, B-07, B-08, B-10, B-17, B-18, B-19, B-20, B-22)
- `appendEvent()` calls — these feed friction-log.md which PM reads
- B-04 silence watchdog — keep (just change from "post to channel" to "spawn recovery silently")
- B-21 spawn failure alert — keep (this one IS user-visible, it's a Tier 3 alert)
- SPAWN_DEPTH_CAP (line 296) — keep, but add a visible message when it fires (currently silent)
- Checkpoint mtime tracking (new addition)

### Remove from orchestrate.sh

**Haiku decomposition step** (the `claude -p --model claude-haiku-4-5...` decompose call)
Why remove: this was fragile and produced vague step names. Agents that emit [ORCHESTRATE:] should provide the step breakdown themselves in the sentinel context. Orchestrator v2 trusts the context it receives.

### Keep in orchestrate.sh

- Step ledger (CHANNEL_STATE_DIR/{channelId}-steps.json) — this is the right resume mechanism
- `RESUMING=true` path — already works correctly
- Per-step Claude call — this is the right approach for long tasks

---

## Part 2: 22 Mandates → 3-Layer Mapping

Each mandate belongs to exactly one primary layer. Secondary detection is noted.

### Layer 1 — Agent Self-Check (in prompt, before posting)

These are behavioral. Bot.js can't reliably detect them from message content. Agents must own them.

| Mandate | What the agent checks | Self-check question |
|---|---|---|
| **B-01** TRUTHFULNESS | Did the action actually happen? | "Did I read back every file I claimed to write? Grep the queue?" |
| **B-02** ESTIMATES | Did I give a time estimate + cadence? | "Does my ACK have: About N min, updates every M sec?" |
| **B-03** TASK MGMT | Did I write a task plan with steps? | "Is my checkpoint non-empty with taskPlan?" |
| **B-06** PROACTIVE | Did I do the obvious next thing? | "Am I about to ask 'should I?' for something Level 0-3?" |
| **B-07** OVERCOME BLOCKERS | Did I try 2 different approaches? | "Does my BLOCK have 'What I tried: [approach 1], [approach 2]'?" |
| **B-08** NO PASSBACK | Am I asking {{USER_JERRY}} to do something I can do? | "Does my message ask {{USER_JERRY}} to run a command or navigate somewhere?" |
| **B-11** RESEARCH | Did I search before deciding? | "Is my RESEARCH field non-empty with source + finding?" |
| **B-12** 2ND BRAIN | Did I check QMD? | "QMD query result: [score] / 0.7 threshold met?" |
| **B-13** CAPABILITIES | Did I check PROVEN/FAILED? | "CAPABILITIES.md checked — pattern found / not found / blocked?" |
| **B-14** SKILLS | Did I check the skills list? | "Relevant skill found and used / improvising because?" |
| **B-15** PROVOCATIVE | Did I challenge the premise? | "Did I name one thing that could be wrong with the request?" |
| **B-16** CURIOUS | Am I missing context that would change my approach? | "What do I have / what's missing?" |
| **B-22** NO PAUSE | Am I about to ask which step to start first? | "Does my DELIVER list options and ask which to do first?" |

**Enforcement mechanism:** Hard gates embedded in turn protocol. These 4 appear as explicit yes/no questions the agent answers before every DELIVER:
- B-01: "Did I read back every claimed file?" → if no → do it now before posting
- B-17: "Is this under 200 words?" → if no → trim now
- B-22: "Am I listing options + asking which first?" → if yes → do all L0-3 now
- CLAIM-VERIFY: "Did I verify every claim?" → if no → verify now

### Layer 2 — Bot.js Silent Detection (observe, log, never block)

These are structural/format. Bot.js can reliably detect them from message content.

| Mandate | What bot.js detects | Response |
|---|---|---|
| **B-04** NO SLEEPING | Agent quiet >5 min after ACK with no DELIVER | ⚡ Recovery spawn (silent to user unless spawn fails) |
| **B-05** SEAMLESS RESTART | Agent respawns but doesn't resume from checkpoint | Log to friction-log: "agent restarted without reading checkpoint" |
| **B-09** AGENTS DRIVE PRODUCT | PM didn't self-trigger after last DELIVER | PM self-wake timer (already implemented) |
| **B-10** PRODUCT MGMT | DELIVER mentions completing items not in task-registry | Log to friction-log — PM reviews |
| **B-17** COMMS | Message >220 words | Log to friction-log — PM escalates at 5+/week |
| **B-18** RICH UI | DELIVER ends with question but no [CONFIRM/BUTTON/SELECT] | Log to friction-log — PM escalates at 3+/week |
| **B-19** DOC SHARING | Message contains ~/pap-workspace path | Log — exception for code blocks (already handled) |
| **B-20** NO TIMELINES | DELIVER contains date/time promise | Log to friction-log |
| **B-21** SPAWN | Agent fails to post first message within 90s | **VISIBLE ALERT** — ⚠️ posted in channel |

**Two-tier visibility:**
- Tier 1 (always silent): B-05, B-09, B-10, B-17, B-18, B-19, B-20
- Tier 2 (silent recovery, visible only on failure): B-04
- Tier 3 (always visible): B-21

### Layer 3 — PM Pattern Loop (improve the system)

PM reads violation-summary.json each sweep. This layer converts data into fixes.

| Mandate | PM action at 3+ hits/week |
|---|---|
| **B-01** high frequency | Add explicit file-read step to agent prompt template |
| **B-06** | Tighten "obvious next step" language in behaviors.md |
| **B-17** | Add word count self-check to hard gates |
| **B-18** | Tighten sentinel trigger in turn protocol |
| **B-22** | Add specific "before listing options" check to DELIVER gate |

PM weekly digest to #helm-improvements: "Top 3 violation patterns this week" — no individual violations, patterns only.

---

## Part 3: Orchestrator v2 Design

### What Orchestrator Is For (Clarified)

Orchestrator is for **multi-step tasks where step results feed into subsequent steps** — where the output of Step 1 is the input to Step 2.

It is NOT for:
- Simple sequential tasks (agent can handle these with checkpoint)
- Parallel independent sub-tasks (these don't need handoff context)
- Single-agent tasks, even complex ones (checkpoint is enough)

Good orchestrator trigger: "Build a morning briefing: (1) fetch calendar events, (2) fetch urgent emails, (3) synthesize into a 3-item briefing, (4) post to Discord." Step 3 needs the outputs of Steps 1 and 2.

Wrong orchestrator trigger: "Write the spec for the ETF tracker." That's a single task with sub-steps the agent manages itself.

### Design Principles

**1. Opt-in, never ambient**
`[ORCHESTRATE: ...]` is the ONLY trigger. No ACK-phase classification. No keyword detection. Agent explicitly decides to orchestrate.

**2. Context-forward, not task-passing**
When an agent emits [ORCHESTRATE:], they pass rich context — what workspace, what files, what phase, what each step needs to accomplish. Orchestrator doesn't infer; it executes what it was given.

Minimum useful sentinel:
```
[ORCHESTRATE: workspace=morning-briefing channel=1234567890 
  steps=[
    "1. Fetch today's calendar events from {{USER_JERRY}}'s Google Calendar → store in /tmp/cal.json",
    "2. Search Gmail for urgent/unread from last 24h → store in /tmp/mail.json", 
    "3. Read /tmp/cal.json + /tmp/mail.json → write 3-item briefing to /tmp/briefing.md",
    "4. Post /tmp/briefing.md content to Discord channel 1234567890"
  ]]
```

Sparse sentinel (fewer than 3 steps specified) → orchestrator stripped, agent handles directly.

**3. Each step is atomic**
Every step:
- Receives a typed context object: `{channelId, stepId, task, inputFiles, outputFile, workspacePath, priorStepSummary}`
- Writes its output to a declared output file
- Marks itself done in the step ledger before exiting
- Posts ⏳ with step number (so {{USER_JERRY}} sees progress)

**4. Non-blocking failure**
If any step fails: post ⏸ BLOCK with which step, what failed, what was accomplished so far. Never silent failure. The step ledger preserves what succeeded — if resumed, completed steps are skipped.

**5. Orchestrator doesn't post DELIVER**
Each step posts its own ⏳ UPDATE. The final step posts ✅ DELIVER. Orchestrator is infrastructure, not agent.

### Scenario Walk-Through: Morning Briefing

```
User: "Set up a morning briefing for me"
   ↓
Curiosity: intake → handoff.json
   ↓
Scaffolder: creates workspace, writes CLAUDE.md
   ↓
(Next day, 7:55am cron fires)
Bot.js: spawns workspace agent with CLAUDE.md
   ↓
Workspace agent: reads CLAUDE.md, writes checkpoint
   → checkpoint: {task: "morning briefing", steps: ["cal", "mail", "synthesize", "post"], phase: A}
   → ACK: "👍 Starting morning briefing — ~3 min"
   → emits: [ORCHESTRATE: ...4 steps with typed context...]
   ↓
Bot.js: strips sentinel, spawns orchestrate.sh
   ↓
orchestrate.sh Step 1: cal fetch
   → writes /tmp/cal.json
   → marks step 1 done in ledger
   → posts: "⏳ Calendar fetched (3 events today)"
   ↓
orchestrate.sh Step 2: email fetch
   → reads step 1 output from ledger context
   → writes /tmp/mail.json
   → marks step 2 done
   → posts: "⏳ Email scanned (2 urgent)"
   ↓
orchestrate.sh Step 3: synthesize
   → reads /tmp/cal.json + /tmp/mail.json
   → writes /tmp/briefing.md
   → marks step 3 done
   ↓
orchestrate.sh Step 4: post
   → reads /tmp/briefing.md
   → posts briefing to Discord
   → marks step 4 done
   → posts: "✅ DELIVER — Morning briefing ready..."
```

### Scenario Walk-Through: Orchestrator Step Fails

```
...Step 2: email fetch FAILS (Gmail auth expired)
   ↓
orchestrate.sh:
   → does NOT mark step 2 done
   → posts: "⏸ BLOCK — step 2 (email fetch) failed: Gmail token expired.
              Step 1 (calendar) completed. Resume after re-auth."
   ↓
{{USER_JERRY}} re-auths, sends "/resume"
   ↓
orchestrate.sh: reads ledger → step 1 = done, step 2 = pending
   → resumes from step 2, skips step 1
   → continues normally
```

**Key design insight:** The step ledger is what makes orchestrator valuable. Without it, a failure at step 3 of 5 means starting over. With it, only the failed step reruns.

### Scenario Walk-Through: Agent Emits Sparse Sentinel

```
Agent: "I'll handle this directly" + writes [ORCHESTRATE: do the thing]
   ↓
Bot.js: sentinel has <3 steps
   → strips sentinel
   → agent continues executing directly
   → orchestrator never invoked
```

This is the right fallback. If an agent isn't sure orchestrator helps, a sparse sentinel gracefully degrades.

---

## Part 4: Long Task Continuity

### Current Gap

Bot.js tracks `lastAgentMsgAt`. Watchdog fires at 5-min silence. Problem: an agent writing large files or doing complex reasoning can take >5 min without posting. Watchdog can't tell "working slowly" from "crashed silently."

### Heartbeat Design: Checkpoint Mtime

Every checkpoint write = a heartbeat. Agents already write checkpoints every 1-2 steps. Bot.js already knows the checkpoint file path per channel.

**Watchdog logic change:**

```
Current:
  if (now - lastAgentMsgAt > 5min) → respawn

New:
  checkpointMtime = mtime of channel-state/{channelId}.json
  if (now - lastAgentMsgAt > 5min):
    if (now - checkpointMtime < 3min):
      → agent is working (wrote checkpoint recently) → extend grace 3min
      → post: "⏳ Agent working (last checkpoint: 1 min ago)"
    else:
      → agent is stale → respawn with checkpoint context
```

**Why this works:** Checkpoint writes happen every 1-2 steps. An agent that's working will have updated its checkpoint within the last 3 minutes. An agent that crashed after the last checkpoint write will have a stale mtime. Bot.js can tell the difference.

### Structured Resume Context

When respawning after a crash, the new agent reads the checkpoint `notes` field. This field must contain enough context to resume without re-reading the conversation.

**Minimum viable notes field:**
```json
{
  "notes": "Done: fetched calendar, fetched email. In progress: synthesizing briefing (have 8 events, 3 urgent emails). Next: write to /tmp/briefing.md, then post. Files: /tmp/cal.json (written), /tmp/mail.json (written)."
}
```

**Notes field enforcement:** If checkpoint notes is empty or <20 words when watchdog fires, bot.js logs "checkpoint context too sparse to resume" and posts ⏸ BLOCK instead of spawning. (Currently: bot.js spawns with empty context → agent reruns everything → duplicate work.)

**Checkpoint protocol rule addition:** Notes field must include three sections:
- `Done:` — what's been completed
- `In progress:` — current step and what data exists
- `Next:` — remaining steps
- `Files:` — any temp files written and their paths

### Scenario: Agent Crashes Mid-Task

```
Agent: processing step 3 of 5 — synthesizing briefing
   → has written checkpoint: "Done: cal, email. In progress: synthesize (8 events, 3 emails). Next: post. Files: /tmp/cal.json, /tmp/mail.json"
   → agent crashes (timeout, OOM, API error)
   ↓
Bot.js (3 min later):
   → checkpointMtime = 4 min ago
   → lastAgentMsgAt = 8 min ago
   → checkpointMtime < lastAgentMsgAt → agent crashed after last checkpoint
   → spawn new agent with: {resume: true, checkpoint: {...notes above...}}
   ↓
New agent:
   → reads checkpoint: "Done: cal, email. In progress: synthesize..."
   → reads /tmp/cal.json and /tmp/mail.json (they exist)
   → resumes from step 3 without refetching cal/email
   → posts: "⏳ Resumed — continuing step 3 (synthesize)"
```

### Scenario: Long Task With No Crashes

```
Agent: writing a large spec file (steps: research → outline → draft → review)
   → step 1 (research): 6 min, writes checkpoint every 2 min
   ↓
Bot.js at 5-min mark:
   → lastAgentMsgAt = 5 min ago
   → checkpointMtime = 2 min ago
   → "agent working" grace extended 3 min
   → posts: "⏳ Agent working (last checkpoint: 2 min ago)"
   ↓
Bot.js at 8-min mark:
   → checkpointMtime = 1 min ago (agent wrote another checkpoint)
   → grace extended again
   ↓
Agent completes step 1 at 9 min:
   → posts "⏳ Research done — starting outline"
   → watchdog resets
```

---

## Part 5: Validator as Data Pipeline

### What Validator Becomes

Currently: validator = bot.js pattern detection + reply in channel.
New: validator = bot.js pattern detection + violation-summary.json.

**violation-summary.json format:**
```json
{
  "lastUpdated": "2026-06-08T20:00:00Z",
  "weekStart": "2026-06-02",
  "violations": {
    "B-17": { "count7d": 8, "last": "2026-06-08T15:23:00Z", "examples": ["DELIVER was 287 words", "DELIVER was 312 words"] },
    "B-18": { "count7d": 3, "last": "2026-06-07T10:11:00Z", "examples": ["DELIVER ended with question, no sentinel"] },
    "B-22": { "count7d": 2, "last": "2026-06-06T09:00:00Z", "examples": ["'which of these should I start with?'"] }
  }
}
```

PM reads this each sweep:
- ≥3 same type this week → queue engineer fix
- ≥5 same type this week → queue engineer fix + post L4 notification to #helm-improvements
- {{USER_JERRY}} sees it only as: "Top violation this week: B-17 (word count). Fix queued."

**What this replaces:**
- Every `msg.reply('🤖 B-xx violation...')` → replaced by `appendEvent(...)` + violation-summary.json update
- Every `msg.react('🤖')` on violations → removed (exception: B-21 keeps the reaction, it's a Tier 3 alert)

---

## Part 6: Implementation Sequence

Lean startup order: biggest risk reduction first, smallest blast radius, most reversible.

### Phase 0 — Ghost Removal (~2 hrs, highest risk reduction)
Remove the code identified in Part 1.
1. Remove ACK-phase orchestrator routing from bot.js
2. Replace all 14 `msg.reply()` violation calls with `appendEvent()` only
3. Remove checkpoint-restore on DELIVER failure

**Validation:** After deploy, post a message with a deliberate schema violation (test only). Confirm: no 🤖 reply, friction-log.md receives the entry, message still posts normally.

**Rollback:** git revert single commit.

### Phase 1 — violation-summary.json (~1 hr)
Add writer to bot.js: every `appendEvent()` call also updates violation-summary.json.
PM reads it. Weekly pattern digest to #helm-improvements.

### Phase 2 — Checkpoint Mtime Heartbeat (~2 hrs)
Modify watchdog: read checkpoint mtime, extend grace if fresh.
Add sparse-notes gate: block respawn if notes < 20 words, post BLOCK instead.

**Validation:** Run a 10-min test task. Confirm: watchdog extends grace each time checkpoint updates, doesn't respawn prematurely.

### Phase 3 — Orchestrator v2 (~3 hrs)
Remove Haiku decompose step from orchestrate.sh.
Add typed context JSON at step handoffs.
Add sparse-sentinel guard in bot.js (< 3 steps → agent handles directly).
Enable ORCHESTRATOR_ENABLED for sentinel-only path.

**Validation:** Trigger one real [ORCHESTRATE:] task with 3 typed steps. Confirm: each step posts ⏳, step ledger updates, resume works from step 2 if step 1 is marked done.

### Phase 4 — Hard Gate Self-Checks (~1 hr)
Add the 4 explicit self-check questions to the agent prompt hard gates section.
These are prompt additions, not bot.js changes.

**Validation:** Watch for B-01, B-17, B-22 violation counts in violation-summary.json dropping over 7 days post-deploy.

---

## Summary Table: Before vs. After

| Component | Before (v2) | After (v3) |
|---|---|---|
| Violation response | 🤖 reply in channel | Silent log to violation-summary.json |
| Orchestrator trigger | ACK-phase routing + sentinel | Sentinel only |
| Orchestrator fallback | None | Sparse sentinel → agent handles directly |
| Step resume | From beginning | From last completed step (ledger) |
| Watchdog signal | lastAgentMsgAt only | lastAgentMsgAt + checkpoint mtime |
| Agent crash recovery | Respawn with empty context | Respawn with structured notes |
| Mandate enforcement | Primarily bot.js | Self-check (agent) + silent detect (bot.js) + pattern loop (PM) |
| {{USER_JERRY}} sees violations | Every one | Only B-04 (silence) and B-21 (spawn fail) |
| PM acts on violations | Never | 3+/week triggers engineer queue |

---

## Open Design Questions for {{USER_JERRY}}

1. **Orchestrator scope:** The design says orchestrator = multi-step tasks where steps feed each other. Agree? Or do you want it for all multi-step tasks regardless of dependency?

2. **Silence threshold:** Currently 5 min → respawn. New design: 5 min → check heartbeat, extend up to 3 min. Agree with 5+3 = 8 min max silence before respawn?

3. **Violation digest frequency:** PM weekly to #helm-improvements, or would you prefer daily? Weekly seems right given patterns need 7-day windows.

4. **Hard gate self-checks:** The 4 gates (B-01, B-17, B-22, CLAIM-VERIFY) appear explicitly as yes/no questions before DELIVER. Do you want these visible in agent outputs (agents saying "checking: B-01 yes, B-17 yes...") or internal only?

---

## One Challenge Worth Raising

The architecture assumes agents will write detailed checkpoint notes reliably. Yesterday showed that under context pressure, agents skip or thin out their checkpoints. The sparse-notes gate in Phase 2 enforces this at the watchdog level, but there's a window: an agent can crash before writing any checkpoint at all, in which case the new agent has nothing to resume from.

Mitigation: orchestrate.sh step ledger handles this for orchestrated tasks. For non-orchestrated tasks, first-ACK checkpoint write is the only defense. The ACK protocol already requires this. Enforcement needs to be tighter in the self-check gate.
