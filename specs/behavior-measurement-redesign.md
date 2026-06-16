# Behavior Measurement Redesign — Session 133

Generated: 2026-06-08
Status: LOCKED ({{USER_JERRY}} approved 30/mo targets + redesign direction)

---

## Core Redesign: Three Measurement Paradigms

| Paradigm | Description | Behaviors |
|----------|-------------|-----------|
| **Structural** | bot.js blocks or auto-detects | B-17 (word count), B-19 (path exposure), B-02 (overrun timer), B-22 (pause patterns) |
| **Pattern** | Scan RESEARCH/PUSHBACK/PROACTIVE_NEXT fields for keywords | B-01, B-06, B-07, B-08, B-11 (partial), B-12 (partial), B-13, B-14 |
| **Semantic** | Daily Haiku review of message content — the key unlock | B-09, B-10, B-11, B-12, B-15, B-16, B-17 (impact), B-18 |

**Key insight:** We've been stuck in Paradigms 1-2. The behaviors {{USER_JERRY}} cares most about (B-09 proactive CPO, B-15 real pushback, B-11/B-12 autonomous research) require Paradigm 3.

**Daily Haiku review:** Each morning at 6am, Haiku reviews previous day's DELIVER messages and scores 5 behaviors (1-5 scale). Cost ~$0.01/day. This produces the first real signal on whether behaviors are improving.

---

## Per-Behavior Measurement Redesign

### B-01 Truthfulness
- **Current:** CLAIM-UNVERIFIED (catches file claims without Verified: line)
- **Gap:** Catches formal claims, not semantic ones
- **Improvement:** When DELIVER includes file in `Docs updated:` → bot.js checks for `Verified:` line in body. Hard gate.
- **Target:** ≤30/mo violations
- **Measurement:** violation count

### B-02 Estimates/Cadence
- **Current:** B02_OVERRUN (elapsed > estimate × 1.5)
- **Root cause:** Agents structurally underestimate (1 tool call = 30-90s, agents say "1 min")
- **Improvement:** bot.js detects ACK with estimate < 4 min AND task has tool calls predicted → auto-bump to 4 min minimum. Log original estimate vs actual.
- **Suggestion for {{USER_JERRY}}:** The fix is a hard minimum (4 min for any tool-heavy task) enforced at ACK, not post-hoc detection.
- **Target:** ≤30/mo overruns
- **Measurement:** violation count

### B-03 Task Management
- **What we actually measure:** EMPTY_CHECKPOINT_NOTES
- **What it should mean:** agent maintains live task list (writes checkpoint after each step, updates currentStep)
- **What it is NOT:** orchestrator use
- **Improvement:** Track: (a) checkpoint writes per multi-step task, (b) missing currentStep updates after each completed step
- **Target:** ≤30/mo missing checkpoints
- **Measurement:** violation count

### B-04 No Sleeping
- **Current:** ORPHANED-ACK (ACK without subsequent DELIVER or UPDATE)
- **{{USER_JERRY}}'s concern:** 50 yesterday felt high — possibly false positives from API latency
- **Investigation needed:** watchdog fires at 5 min; if API call takes 4 min, orphaned-ack fires even when working
- **Improvement:** Raise orphaned-ack threshold to 8 min to reduce API-latency false positives. Add context: was there a tool call in progress?
- **Target:** ≤30/mo true sleep events
- **Measurement:** violation count (after false-positive filter)

### B-05 Seamless Restart
- **Current:** THREAD-MISROUTING (poor proxy)
- **Better:** Count resumes where agent posted ACK but NOT "what were we working on?" or "can you remind me" patterns
- **Positive measure:** "resumed from checkpoint" events / total resumes
- **Target:** >80% clean resumes (no context-request)
- **Measurement:** positive rate

### B-06 Proactive
- **{{USER_JERRY}}'s concern:** PROACTIVE_NEXT filled ≠ proactive. Agents list next steps and ask "go ahead?"
- **Current detection:** PROACTIVE-NEXT-QUESTION catches "should I?" in the field
- **Gap:** Detects the field violation, not the underlying pattern of listing work and waiting
- **Improvement:** Detect phrases like "want me to", "shall I", "should I proceed" in DELIVER body (not just schema field). Also: semantic review (Haiku) for "agent described L0-3 work as optional"
- **Target:** ≤30/mo violations + Haiku score ≥3.5/5
- **Measurement:** violation count + semantic score

### B-07 Overcome Blockers
- **Current:** B07-BLOCK-NO-EVIDENCE (BLOCK without "What I tried" field)
- **{{USER_JERRY}}'s note:** seeing more violations, may not have full picture
- **Improvement:** Also track: how many BLOCKs per channel per day (high BLOCK rate = agent gives up too easily)
- **Target:** ≤30/mo gate violations
- **Measurement:** violation count

### B-08 No Passback
- **{{USER_JERRY}}'s note:** Context loss → agents ask for re-sent attachments or old convos
- **Detection gap:** b08_passback_flag catches some but can't determine if "can you X" is passback or legitimate
- **Link to 2nd brain:** Attchment loss is a 2nd brain problem — if all attachments are auto-saved to disk (B-16-context rule), agents shouldn't need to ask
- **Improvement:** (a) detect "can you send/share/re-send" patterns; (b) once 2nd brain ingestion improves, track how often agent finds the file vs asks for it
- **Target:** ≤30/mo
- **Measurement:** violation count

### B-09 PM Drives Product (CPO Proactivity)
- **Current:** 0 measured — no detection at all
- **{{USER_JERRY}}'s core frustration:** Never seen a case where PM prompted with something new without being asked
- **Measurement approach:** POSITIVE count. PM logs each proactive action to pm-unsolicited.log with timestamp. Weekly review: how many proactive proposals/actions without prior user ask?
- **Detection:** PM step T2-K must write to pm-unsolicited.log when acting without a user request
- **Target:** ≥5 proactive PM actions/week (start here, raise over time)
- **Measurement:** POSITIVE count

### B-10 Product Management Accuracy
- **Current:** 0 measured — no detection
- **{{USER_JERRY}}'s suggestion:** Mission-control page with backlog/queue by product, audit for accuracy
- **Measurement approach:** Weekly accuracy audit — sample 5 work items, compare stated status vs actual state on disk. Score = % accurate.
- **Target:** >90% accuracy on weekly audit
- **Measurement:** audit score (human review + automated cross-check)
- **Engineer item:** mission-control workspace adds a "Backlog" tab showing HELM + workspace work items by stage

### B-11 Research (Web)
- **Current:** RESEARCH-QUALITY catches "research=purely mechanical" on complex tasks
- **{{USER_JERRY}}'s note:** Never seen an agent do web research without being told
- **True picture:** Agents almost never use WebFetch/WebSearch proactively
- **Measurement:** POSITIVE rate — % of DELIVER messages where RESEARCH field contains "web", "WebFetch", "WebSearch", or "searched"
- **Target:** ≥25% of DELIVER messages include web research when applicable (Haiku review determines "applicable")
- **Measurement:** positive rate

### B-12 2nd Brain / QMD
- **Current:** Counts RESEARCH-QUALITY for skipped research — misses most cases
- **{{USER_JERRY}}'s note:** Never seen agents check QMD without direction
- **True picture:** QMD queries are near-zero in unprompted turns
- **Measurement:** POSITIVE rate — % of DELIVER messages where RESEARCH field contains "QMD:"
- **Target:** ≥25% of DELIVER messages include QMD query
- **Measurement:** positive rate (add "QMD:" pattern check to bot.js RESEARCH parser)

### B-13 Capabilities Check
- **Current:** No detection
- **Measurement:** POSITIVE rate — % of DELIVER messages where RESEARCH field contains "CAPABILITIES: checked"
- **Enforcement:** bot.js prompts RESEARCH field format: "CAPABILITIES: checked [what] — [found/not found]"
- **Target:** ≥50% of technical DELIVER messages include capabilities check
- **Measurement:** positive rate

### B-14 Skills Check
- **Current:** No detection
- **Measurement:** POSITIVE rate — % of DELIVER messages where RESEARCH field contains "SKILLS:"
- **Same approach as B-13**
- **Target:** ≥50% of applicable DELIVER messages include skills check
- **Measurement:** positive rate

### B-15 Pushback Quality
- **Current:** Counts DELIVER-MISSING-PUSHBACK (field absent) and PUSHBACK-RECUR (same pushback twice)
- **{{USER_JERRY}}'s concern:** PUSHBACK field is rarely useful pushback; it's often boilerplate
- **Root problem:** "none — checked X" pattern is technically compliant but provides no value
- **Improvement:** Haiku daily review scores PUSHBACK quality 1-5:
  - 1: "none — checked X" with no substance
  - 3: Names a risk but doesn't challenge the premise
  - 5: Specific alternative with evidence, challenges the user's assumption
- **Target:** ≤30/mo field violations + Haiku pushback quality score ≥3.5/5 weekly average
- **Measurement:** violation count + semantic score

### B-16 Curious / Context Questions
- **Current:** assumption_skip catches some; vagueness_flag
- **{{USER_JERRY}}'s note:** Rarely sees questions asked before proceeding
- **Measurement:** POSITIVE rate — % of conversations where agent asked ≥1 clarifying question before proceeding on ambiguous task
- **Target:** ≥25% of applicable messages (Haiku determines "applicable" = ambiguous task)
- **Measurement:** positive rate

### B-17 Communication Quality / Impact
- **Current:** B17-LENGTH catches word count >200
- **{{USER_JERRY}}'s concern:** Impact > word count. A 500-word message with 5 decisions > a 199-word useless one
- **Measurement redesign:** Two-part score
  1. Format compliance: word count, headers, code blocks in non-workspace channels (bot.js structural check — existing)
  2. Impact score: daily Haiku review rates message on "decisions enabled / information value" (1-5)
- **Target:** ≤30/mo format violations + impact score ≥3.5/5 weekly average
- **Measurement:** violation count + semantic score

### B-18 Rich UI
- **Current:** B18-PROSE-QUESTION (question in prose when [CONFIRM:] should be used)
- **{{USER_JERRY}}'s concern:** Rarely sees rich UI except the color embed; buttons used incorrectly (not for choices)
- **Gap:** Detecting when buttons are cosmetic (list decoration) vs functional (actual choice)
- **Improvement:** Add detection for [BUTTON:] or [CONFIRM:] without corresponding response pathway. Haiku review for "did agent present a choice without buttons?"
- **Target:** ≤30/mo prose-question violations
- **Measurement:** violation count + Haiku spot-check

### B-19 Doc Sharing / No Internal Paths
- **Current:** B19-PATH-EXPOSED — detects "/" followed by path patterns
- **{{USER_JERRY}}'s concern:** False positives from "/" in commands, code blocks, option names
- **Fix:** Exclude "/" in code blocks (``` fences) and command examples. Context check: is "/" in backtick context?
- **Target:** ≤30/mo true path exposures
- **Measurement:** violation count (after false-positive reduction)

### B-20 No Timelines
- **Current:** b20_timeline detection — working
- **Target:** ≤30/mo
- **Measurement:** violation count

### B-21 Spawning Reliability
- **Current:** DUPLICATE-REPORTED (poor proxy)
- **{{USER_JERRY}}'s note:** Hard to notice from outside
- **Measurement:** Track spawn attempt → spawn success rate in event-stream. If spawn fired but no agent ACK in 120s → log B21-SPAWN-FAIL
- **Target:** <5 spawn failures/mo
- **Measurement:** event-stream analysis

### B-22 No Pause to Ask
- **Current:** B22-ENUM, B22-NO-PAUSE
- **{{USER_JERRY}}:** Still seeing it a lot, new measurement needed
- **Improvement:** Add detection for "which of these should I", "which one first", "where should I start", "which would you prefer I tackle" patterns in bot body scan
- **Target:** ≤30/mo
- **Measurement:** violation count

---

## Daily Haiku Review — The Key Unlock

Each morning at 6am, a Haiku agent reviews yesterday's DELIVER messages and produces scores for:

| Behavior | Question asked | Score |
|----------|----------------|-------|
| B-09 | Did any agent act proactively without being asked? | count |
| B-11 | Did this agent do web research when appropriate? | Y/N per message |
| B-12 | Did this agent check QMD when appropriate? | Y/N per message |
| B-15 | Is the PUSHBACK field substantive or boilerplate? | 1-5 per message |
| B-17 | Did this message contain decision-relevant info? | 1-5 per message |

Output: `~/pap-workspace/daily-quality-score.json` — read by PM weekly sweep.
Cost: ~$0.01/day (Haiku pricing).

**Engineer items needed:**
1. daily-quality-review.py — Haiku script that reviews yesterday's messages from marvin.log
2. Integrate score into behavior-metrics.json weekly rollup
3. PM T2-L reads daily-quality-score.json and includes in weekly report

---

## Mission-Control Mandates Tab

**Spec for mission-control workspace (add to their task backlog):**

Add a "Mandates" tab to the web dashboard. Data source: `~/pap-workspace/behavior-metrics.json` (served via existing backend/server.py).

Tab shows:
- Per-behavior: name, measure type (violation/positive-rate), current count/rate, target, trend arrow
- Color: green (on target), yellow (within 20%), red (over)
- Updated daily via cron at 6am

**Instructions for mission-control agent:**
1. Add `/api/mandates` endpoint to server.py — reads and returns behavior-metrics.json
2. Add "Mandates" tab to index.html — table with columns: Behavior | Measure | Current | Target | Status
3. Auto-refresh every 5 min

---

## Update Mechanism

**Recommended approach (B-10 / mission-control as canonical):**

1. Cron at 6am daily: runs `~/marvin-bot/behavior-metrics.sh --json` → writes `~/pap-workspace/behavior-metrics.json`
2. Mission-control serves it via `/api/mandates` — becomes primary live view
3. Google Sheet → optional export (not canonical). Keep for historical reference.
4. PM weekly sweep reads metrics.json and posts summary to #helm-improvements

**Why not Sheet as canonical:** mission-control is already Phase B. Duplicating the data pipeline to maintain a Sheet adds complexity. The Sheet becomes useful for sharing externally or historical tracking, but daily operational view lives in mission-control.

---

## Cron Entry to Add

```
0 6 * * * /usr/bin/python3 ~/marvin-bot/behavior-metrics.sh --json > /tmp/bm-run.log 2>&1
```

Plus: `0 7 * * * /usr/bin/python3 ~/marvin-bot/daily-quality-review.py > /tmp/dqr-run.log 2>&1`
(daily-quality-review.py is the engineer item to build)
