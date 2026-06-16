# Grill Me Pattern Implementation Spec
**Status:** Pending Engineer Review  
**Priority:** Medium (high-leverage, improves spec clarity across 3 critical domains)  
**Effort Estimate:** 3–4 hours  
**Date Created:** 2026-06-12  

---

## Executive Summary

Implement a conversational **context-sharpening loop** (Grill Me pattern) across three critical HELM domains to reduce iteration cycles and prevent fuzzy specifications from entering build phases.

**Core Pattern:** Ask N domain-specific questions, checkpoint after each answer, aggregate into a structured output document, save to canonical location.

**Why:** Specs that enter engineer queue with thin detail (missing edge cases, vague success criteria, unstated constraints) cause rework. A 15–30 min upfront grilling session crystallizes requirements, compressing "70% readiness → 90% readiness" before engineering starts.

**ROI:** Prevents one rework cycle per 3–5 specs, saving 4–6 hours of work per month.

---

## Domain Breakdown

### Domain 1: Discovery (Curiosity Agent)
**Location:** `~/.claude/agents/curiosity.md` — Phase 1 (intake interview)  
**Mandatory:** YES — grilling always happens after initial idea capture  
**Timing:** After user answers "what's the problem?"  
**Length:** 15–20 minutes  
**Output Location:** `~/pap-workspace/brainstorms/[topic].md`

**Question Framework:**
```
1. Problem statement — User describes the pain in their own words (not the solution)
2. Desired outcome — What does "fixed" look like?
3. Constraints/timeline — Budget, timeline, who's affected, integrations needed?
4. Success criteria — How will we know this worked? (measurement)
5. Edge cases — What could break? What's NOT in scope?
```

**Implementation Detail:**
- After intake Opening message, before offering workspace creation
- Post Q1, wait for user answer → checkpoint locally
- Post brief ack ("Got it — [one-line summary]") → post Q2
- After Q5 answered → aggregate into structured output
- Save as `~/pap-workspace/brainstorms/[topic-slug].md` with frontmatter:
  ```yaml
  ---
  topic: [user's topic]
  created_at: [timestamp]
  discovery_phase: complete
  ---
  
  ## Problem Statement
  [Q1 answer]
  
  ## Desired Outcome
  [Q2 answer]
  
  ## Constraints & Timeline
  [Q3 answer]
  
  ## Success Criteria
  [Q4 answer]
  
  ## Edge Cases & Out-of-Scope
  [Q5 answer]
  
  ## Key Highlights
  [PM extracts 3–5 key insights]
  ```
- Then post "Spec locked — ready for workspace creation. [BUTTON: Create workspace|create; Review first|review]"

**Checkpointing:**
- Save to `~/pap-workspace/channel-state/[channel_id].json` key `grill_me_checkpoint`:
  ```json
  {
    "domain": "discovery",
    "topic": "[topic]",
    "questions_answered": 3,
    "total_questions": 5,
    "next_question_index": 4,
    "answers": {
      "q1_problem": "[answer text]",
      "q2_outcome": "[answer text]",
      "q3_constraints": "[answer text]"
    },
    "ts": "ISO timestamp"
  }
  ```
- On resume (bot restart): read checkpoint, skip to Q4. Post: "We got Q1–Q3. Now Q4: [question]"

**Triggering Logic:**
- Curiosity agent: always grill after Opening (non-negotiable)
- No user opt-in needed (this is the standard intake flow)

---

### Domain 2: PM Backlog (PM Agent)
**Location:** `~/helm-workspace/system/pm-jobs.md` — T2-B section  
**Mandatory:** NO — selective, opt-in  
**Timing:** When queuing high-cost items  
**Length:** 15–30 minutes  
**Output Location:** `~/helm-workspace/specs/[item-id]-spec.md` + work-items.json `spec:` field

**Decision Gate:**
- Run before queuing any item from MASTER-BACKLOG or work-items.json
- Trigger: `item.estimated_effort_min > 30 AND item.spec.length < 3 sentences`
- Offer: "This item costs [N] hours + design is thin. Grill first (15 min) or queue as-is?"
- User may decline — queuing without grilling is valid (user's call)

**Question Framework:**
```
1. Business case / why now? — What problem does this solve? Why now vs. 3 months from now?
2. Success metric — How do we measure "this worked"? (quantified if possible)
3. Acceptance criteria — What's the definition of done? (specific, testable)
4. Dependencies — What depends on this? Who else is affected?
5. Timeline — Is [estimated_effort_min] realistic? Any hard deadline?
```

**Implementation Detail:**
- Post all Qs as a bundled set (don't split across turns)
- After Q5 answered → draft spec to `~/helm-workspace/specs/[item-id]-spec.md`:
  ```markdown
  # [Item Title] — Spec
  Drafted: [date] by PM grilling  
  Item ID: [id]
  
  ## Business Case
  [Q1 answer]
  
  ## Success Metric
  [Q2 answer]
  
  ## Acceptance Criteria
  [Q3 answer]
  
  ## Dependencies & Stakeholders
  [Q4 answer]
  
  ## Timeline & Effort Reality Check
  [Q5 answer] — Estimated [X] min, confirmed with user
  
  ## Status
  Draft spec complete — ready to queue.
  ```
- Update work-items.json `spec:` field: link to the spec document
- Update `status: queued` and queue to engineer-queue.md
- Offer: "Spec drafted + queued. Engineer will review and start [timeline]."

**Checkpointing:**
- Save to work-items.json `[item_id].grill_checkpoint`:
  ```json
  {
    "domain": "pm_backlog",
    "item_id": "[id]",
    "questions_answered": 2,
    "total_questions": 5,
    "answers": {...}
  }
  ```

**Triggering Logic:**
- PM offers during T2-B, only when conditions met (cost + spec thinness)
- User always has opt-in choice
- Decline → queue as-is; Accept → grill now

---

### Domain 3: Workspace Phase A (Workspace Agent)
**Location:** `~/pap-workspace/[workspace]/CLAUDE.md` — Phase A section  
**Mandatory:** NO — conditional  
**Timing:** Before posting mockup (if design is unclear)  
**Length:** 10–15 minutes  
**Output Location:** `~/pap-workspace/[workspace]/SPEC-LOCKED.md` (update workspace CLAUDE.md `brief:` field)

**Decision Gate:**
- Before Phase A mockup post
- Trigger: brief lacks 2+ of: clear success criteria, integration constraints, edge cases, timeline
- Offer: "Brief is thin on [X] and [Y]. Quick 15-min grill to lock it down, or proceed with mockup?"
- If user declines → proceed with Phase A as-is
- If user accepts → grill now, update brief, then post mockup

**Question Framework:**
```
1. Core workflow — What's the main path the user takes? (step-by-step)
2. Current pain — Exactly where does it break today?
3. Desired state — What should change in that workflow?
4. Success measure — How will we know it's better? (specific metric or observable)
5. Edge case to avoid — What could go wrong? What's the biggest risk?
```

**Implementation Detail:**
- Post Qs as bundled set
- After Q5 → update workspace CLAUDE.md `brief:` section with grilled details:
  ```yaml
  brief: |
    ## Workflow
    [Q1 answer]
    
    ## Current Pain
    [Q2 answer]
    
    ## Desired State
    [Q3 answer]
    
    ## Success Measure
    [Q4 answer]
    
    ## Key Risk to Mitigate
    [Q5 answer]
    
    **Status:** Brief locked by grilling on [date]
  ```
- Post: "Brief updated. Ready for Phase A mockup? [BUTTON: Proceed|proceed; Review first|review]"

**Checkpointing:**
- Save to workspace channel-state `grill_checkpoint` (same structure as discovery)

**Triggering Logic:**
- Workspace agent: conditional offer before mockup post
- Only if brief is detectably thin (2+ missing details)
- Never force grilling if brief looks complete

---

## Implementation Mechanics (Engineer Task)

### Step 1: Curiosity Agent Changes (~1 hour)
Edit `~/.claude/agents/curiosity.md`:

1. **Add Grilling Section** after "Opening" section:
   ```markdown
   ## Intake Grilling Loop
   
   **When triggered:** Immediately after user answers Opening question (problem statement captured)
   
   **Sequence:**
   1. Read ACTIVE-STATE.md. If `process: curiosity_grilling` exists → resume from checkpoint.
   2. Load checkpoint from channel-state if exists (grill_me_checkpoint key)
   3. For each question (1–5, using framework above):
      - Post question with context
      - User answers
      - Checkpoint: save answer + timestamp
      - Post brief 1-line ack: "Got it — [paraphrase]"
      - Post next question
   4. After Q5 → build brainstorms/[topic].md file
   5. Clear checkpoint on exit
   ```

2. **Add Checkpoint Management:**
   ```python
   # Before grilling loop
   def load_or_init_checkpoint(channel_id):
       state_path = f"~/pap-workspace/channel-state/{channel_id}.json"
       if os.path.exists(state_path):
           data = json.load(open(state_path))
           if data.get("grill_me_checkpoint"):
               return data["grill_me_checkpoint"]
       return {"questions_answered": 0, "answers": {}}
   
   # After each question answered
   def checkpoint_answer(channel_id, q_index, answer_text):
       state = json.load(open(state_path))
       state["grill_me_checkpoint"]["answers"][f"q{q_index}"] = answer_text
       state["grill_me_checkpoint"]["questions_answered"] = q_index
       json.dump(state, open(state_path, "w"))
   ```

3. **Add File Output:**
   ```python
   def write_brainstorms_doc(topic_slug, questions_dict, key_highlights):
       doc = f"""---
   topic: {topic_slug}
   created_at: {now_iso}
   discovery_phase: complete
   ---
   
   ## Problem Statement
   {questions_dict['q1']}
   
   ... [etc for Q2–Q5]
   
   ## Key Highlights
   {key_highlights}
   """
       path = f"~/pap-workspace/brainstorms/{topic_slug}.md"
       write_file(path, doc)
       return path
   ```

### Step 2: PM Agent Changes (~1.5 hours)
Edit `~/helm-workspace/system/pm-jobs.md`:

1. **Add T2-B Grilling Section** after T2-A definition:
   ```markdown
   ### T2-B: Backlog grilling (pre-queue shallow specs)
   
   When queuing work from MASTER-BACKLOG or work-items.json:
   1. For each unqueued item: check `estimated_effort > 30 min` AND `spec.length < 3 sentences`
   2. If both true: offer grilling
   3. User declines → queue as-is (L2, auto-execute, log it)
   4. User accepts → grilling loop (use same checkpoint structure as discovery)
   5. Output → ~/helm-workspace/specs/[item-id]-spec.md
   6. Queue the item after spec is written
   ```

2. **Add PM-Specific Grilling Questions** (must be PM-specific, not copy-paste from discovery):
   ```python
   BACKLOG_GRILL_QUESTIONS = [
       "What problem does this solve? Why is it urgent *now*?",
       "How will we measure success? (metric, observable, testable?)",
       "What's the definition of done? (specific acceptance criteria)",
       "Who depends on this? Any blocking dependencies?",
       "Is [X] hours realistic? Any hard deadline?"
   ]
   ```

### Step 3: Workspace Phase A Changes (~1 hour)
Edit `~/pap-workspace/workspaces/[NAME]/CLAUDE.md` for each active workspace (options-helper, etf-tracker, financial-review, daily-brief):

1. **Add Pre-Phase-A Gate** in Phase A section:
   ```markdown
   ## Phase A — Grilling Check (conditional)
   
   If the `brief:` section lacks any of these: success criteria, integration constraints, 
   edge case risks, explicit timeline → offer a 15-min grilling session to lock details down.
   
   **Triggering logic:**
   - Count lines in brief: `brief.split('\n').length`
   - If < 10 lines AND (success criteria missing OR edge cases missing) → offer grilling
   - User can decline; Phase A proceeds either way
   ```

2. **Add Grilling Questions** (workspace-specific):
   For options-helper example:
   ```python
   WORKSPACE_GRILL_QUESTIONS = [
       "Walk me through the core workflow — how does the user move through the app step by step?",
       "What's broken about the current approach? Where does it fail?",
       "What should happen instead? (Be specific about the change)",
       "How will we *know* it's working? (metric, observable behavior, user reaction)",
       "What's the riskiest part? What could break?"
   ]
   ```

3. **Integrate into Phase A flowchart:**
   - On spawn → check brief completeness
   - If thin + user accepts grilling → run loop
   - Update `brief:` in CLAUDE.md with grilled answers
   - Post mockup AFTER brief is locked

### Step 4: Shared Grilling Loop Function (~30 min)
Create `~/.claude/agents/grilling-loop.sh` — reusable checkpoint + Q&A logic:

```bash
#!/bin/bash
# Shared grilling loop runner
# Usage: source grilling-loop.sh; run_grilling_loop "discovery" "topic-name" "$QUESTIONS_ARRAY"

function run_grilling_loop() {
    local domain=$1
    local context=$2
    local questions_json=$3
    
    # Load checkpoint
    local checkpoint=$(get_checkpoint "$domain" "$context")
    local questions_answered=$(echo "$checkpoint" | jq .questions_answered)
    
    # Loop through questions
    for ((i=questions_answered; i<${#questions[@]}; i++)); do
        post_question_to_discord "$domain" "$context" "$i" "${questions[$i]}"
        read -r answer
        checkpoint_answer "$domain" "$context" "$i" "$answer"
    done
    
    # Build output doc
    build_output_doc "$domain" "$context" "$checkpoint"
}
```

This allows reuse without code duplication.

---

## Integration Points

### Checkpoint Format (Unified)
All three domains use the same JSON structure in channel-state:
```json
{
  "grill_me_checkpoint": {
    "domain": "discovery|pm_backlog|workspace_phase_a",
    "context": "[topic|item-id|workspace-name]",
    "questions_answered": [0–5],
    "total_questions": 5,
    "answers": {
      "q1": "...",
      "q2": "...",
      ...
    },
    "output_path": "~/pap-workspace/brainstorms/[name].md",
    "ts_started": "ISO",
    "ts_last_updated": "ISO"
  }
}
```

### Output Locations
| Domain | Output | Used By |
|--------|--------|---------|
| Discovery | `~/pap-workspace/brainstorms/[topic].md` | curiosity DELIVER, referenced in work-items.json |
| PM | `~/helm-workspace/specs/[item-id]-spec.md` | work-items.json `spec:` field, engineer-queue.md |
| Workspace | `~/pap-workspace/[workspace]/CLAUDE.md brief:` section | workspace agent Phase A, user reference |

### Resume Logic (Bot Restart)
On resume after bot restart:
1. Agent reads ACTIVE-STATE.md: if `process: curiosity_grilling` or `process: pm_grilling` is set → resume
2. Agent loads checkpoint from channel-state
3. Skip to question `questions_answered + 1`
4. Post: "We paused at Q[X]. Resuming with Q[X+1]: [question]"
5. Continue from there

---

## Success Criteria

✅ **Done when:**
1. All three domains have grilling integrated + tested
2. Discovery grilling always runs (non-negotiable)
3. PM grilling runs on high-cost items (opt-in, offered before queue)
4. Workspace Phase A can offer grilling when brief is thin (conditional)
5. Checkpoints persist across bot restarts
6. Output documents are in canonical locations
7. Engineer queued items from grilled specs show improved clarity vs. prior specs
8. No "why?" pushbacks on queued items from grilled specs in first 3 nightly runs

**Measurement:** Compare PUSHBACK fields in engineer DELIVERs for:
- Items queued without grilling: "spec vague on X"
- Items queued after grilling: (should be lower clarity issues)

---

## Rollback Procedure

If issues discovered during engineer run:

1. **Option A (minimal rollback):** Remove grilling from PM backlog + workspace Phase A; keep Discovery grilling (lowest risk)
   - Delete T2-B section from pm-jobs.md
   - Remove Phase A pre-check from workspace CLAUDEs
   - Keep curiosity.md grilling intact

2. **Option B (full rollback):** Remove all grilling
   - Revert curiosity.md to pre-grilling version
   - Revert pm-jobs.md
   - Revert all workspace CLAUDEs
   - Delete brainstorms/, specs/ docs written during grilling runs
   - Recovery time: ~30 min

---

## Testing Approach

1. **Unit test (discovery):** Run intake → answer 5 Q's → verify brainstorms/[topic].md is created with all 5 answers
2. **Integration test (PM):** Queue a 45-minute item with 1-sentence spec → offer grilling → answer 5 Q's → verify specs/[item-id]-spec.md + queue entry
3. **Workspace test:** Options-helper Phase A with thin brief → offer grilling → answer 5 Q's → verify CLAUDE.md brief: updated + mockup posts
4. **Resume test (all three):** Start grilling → answer Q1–Q3 → simulate bot restart → verify resume at Q4 (not Q1)
5. **User opt-out test:** PM grilling offer → user declines → item queues without grilling (no error)

---

## Open Questions for Engineer

1. **Shared grilling loop function:** Should this be a bash script, a Python utility, or inline in each agent file? (Current spec assumes shared bash script for DRY.)
2. **Output formatting:** Are markdown files the right format for brainstorms/ and specs/, or should these be JSON for easier parsing?
3. **Checkpointing:** Should checkpoint cleanup happen on successful output, or remain in channel-state for audit?
4. **Rate limiting:** Any Discord API limits on posting many Q&A messages in succession? (Current spec posts 5–6 messages for grilling.)

---

## Dependencies

- No new external tools required
- Uses existing: markdown file writes, Discord post, channel-state JSON
- Compatible with: bot.js, existing agent structure, checkpoint recovery

---

## Priority & Timeline

- **If approved:** Engineer can start immediately (no blockers)
- **Expected completion:** 1 engineer session, 3–4 hours
- **Deploy path:** Commit to main, queue-restart.sh for nightly 2am deploy
- **Go-live:** Next morning (2am nightly run)
- **User comms:** Morning digest (2am report) includes note: "Discovery intake now includes 15-min requirement grilling — unlocks better specs."
