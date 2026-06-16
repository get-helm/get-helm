# Workspace Architecture: Three-Layer Continuity System

Implemented 2026-05-27 to fix workspace agent memory loss and timeout recovery.

---

## Layer 1: Checkpoint Protocol Enforcement (Foundation)

**Goal:** Every checkpoint must contain detailed, structured notes so resumed agents know exactly what's done and what's next.

**Mandatory format for checkpoint `notes` field:**
```
Done: [item 1], [item 2], [item 3]. In progress: [item]. Next: [item A], [item B].
```

**Why this matters:**
- Old pattern: "Step 3/7 — working through fixes" → agent resumes, re-reads last message, asks for the list again
- New pattern: "Done: Bug 1, Bug 2. In progress: Bug 3 (found syntax error in line 42). Next: Bug 4, Bug 5." → agent resumes, reads checkpoint, knows exactly where to pick up

**Enforcement points (workspace agents):**
1. Before writing checkpoint: validate that `notes` contains all three sections: `Done:`, `In progress:`, `Next:`
2. If validation fails: do NOT write checkpoint. Post BLOCK to user: "Checkpoint validation failed — notes must include Done/In progress/Next sections."
3. Every UPDATE message auto-saves to checkpoint notes by bot.js — UPDATE must include specific findings, not vague status

**Validation rule (add to workspace agent CLAUDE.md):**
```
CHECKPOINT VALIDATION GATE (mandatory before every checkpoint write):
1. notes field must contain "Done: ", "In progress: ", and "Next: " (case-insensitive)
2. Each section must list at least one item or be empty with a reason: "Done: [none yet]"
3. Do NOT write checkpoint with vague strings like "working on it" or empty notes
4. If checkpoint is empty or vague: post BLOCK — ask user for clarification, do not proceed

Invalid: notes = "" or "Step 3/7 — working" or "fixing some bugs"
Valid: notes = "Done: Bug-001. In progress: Bug-002 (found issue in line 42). Next: Bug-003, Bug-004."
Valid: notes = "Done: [none yet]. In progress: initial setup. Next: create config file, test login."
```

---

## Layer 2: work-items.json (Persistent State)

**Goal:** Single source of truth for all work items in a workspace. Survives 20 agent restarts.

**File location:** `~/pap-workspace/workspaces/[workspace-name]/work-items.json`

**Schema:**
```json
{
  "workspace": "options-helper",
  "created_at": "2026-05-27T15:30:00Z",
  "last_updated": "2026-05-27T16:15:00Z",
  "items": [
    {
      "id": "BUG-001",
      "title": "Syntax error in Scanner.py line 42",
      "description": "Optional context about the bug",
      "status": "done",
      "created_at": "2026-05-27T15:30:00Z",
      "status_updated_at": "2026-05-27T16:00:00Z",
      "assigned_to": "workspace_agent",
      "checkpoint_ref": "session_127_step_2",
      "verified_by": "test result: pytest Scanner.py passed",
      "blocked_by": null,
      "notes": "Fixed via..."
    },
    {
      "id": "BUG-002",
      "title": "Chain calculation returns NaN",
      "description": "When values array is empty",
      "status": "active",
      "created_at": "2026-05-27T15:35:00Z",
      "status_updated_at": "2026-05-27T16:05:00Z",
      "assigned_to": "workspace_agent",
      "checkpoint_ref": "session_128_step_1",
      "verified_by": null,
      "blocked_by": null,
      "notes": "Found root cause in chain_calc() — empty array check missing"
    },
    {
      "id": "BUG-003",
      "title": "Output values discrepancy",
      "description": null,
      "status": "queued",
      "created_at": "2026-05-27T15:40:00Z",
      "status_updated_at": "2026-05-27T15:40:00Z",
      "assigned_to": null,
      "checkpoint_ref": null,
      "verified_by": null,
      "blocked_by": "BUG-002",
      "notes": null
    }
  ]
}
```

**Status values:**
- `queued` — waiting to be worked on (no agent assigned)
- `active` — currently being worked on (assigned_to is set)
- `done` — completed with evidence in verified_by
- `blocked` — waiting on another item (blocked_by is set)
- `shelved` — paused by decision, do not work on

**Key rules:**
1. Workspace agent updates work-items.json after completing each item
2. Workspace PM reads work-items.json to decide what to assign next
3. When agent resumes: it reads checkpoint notes ("Done: Bug-001, Bug-002. Next: Bug-003.") AND work-items.json (sees Bug-003 status: active or blocked) → knows exactly what to do
4. verified_by must contain actual evidence: `"file:line number"` or `"test output: X"` or `"grep result: Y"` — never just "done" or "fixed"

**Update rules (for workspace agent):**
- After completing an item: set status=`done`, populate verified_by with evidence
- Before starting an item: set status=`active`, set assigned_to=agent name
- If blocking on external dependency: set status=`blocked`, populate blocked_by
- Every status change must update status_updated_at to current timestamp

---

## Layer 3: Workspace PM Agent

**Goal:** Manage continuity, queue work, validate completion, handle resume scenarios.

**Spawning logic:**
1. User posts 12 bugs in #options-helper → workspace PM reads them
2. Workspace PM creates 12 items in work-items.json with status=`queued`
3. Workspace PM spawns workspace agent with: "12 items queued. Start with Bug-001. See work-items.json for full list."
4. Workspace agent sees clear assignment, picks it up

**On agent timeout/resume:**
1. Workspace PM reads checkpoint notes: "Done: Bug-001, Bug-002. Next: Bug-003."
2. Workspace PM reads work-items.json: sees Bug-003 status=`active`
3. Workspace PM spawns resumed agent with: "Resuming Bug-003 from checkpoint. Last notes: [from checkpoint]. Continue from there."
4. Agent resumes with full context, no need to ask user for the list again

**On agent DELIVER:**
1. Workspace PM reads DELIVER message
2. Extracts verified_by evidence (e.g., "test passed", "code:line 42")
3. Updates work-items.json: status=`done`, verified_by=[evidence], status_updated_at=now
4. Counts completed items, posts summary to workspace channel
5. If there are blocked items that are now unblocked: updates status, assigns next item

**Template location:** `~/pap-workspace/workspace-agent-templates/workspace-pm.md`

---

## Implementation for Existing Workspaces

**Step 1: Create work-items.json**
For each workspace (options-helper, financial-review, daily-brief):
```bash
python3 << 'EOF'
import json, time
from datetime import datetime

workspace_name = "options-helper"
# Manually list current open items from the workspace backlog
items = [
    {"id": "BUG-001", "title": "...", "status": "queued", ...},
]

data = {
    "workspace": workspace_name,
    "created_at": datetime.utcnow().isoformat() + "Z",
    "last_updated": datetime.utcnow().isoformat() + "Z",
    "items": items
}

path = f"~/pap-workspace/workspaces/{workspace_name}/work-items.json"
with open(path, 'w') as f:
    json.dump(data, f, indent=2)
print(f"Created {path}")
EOF
```

**Step 2: Update workspace agent CLAUDE.md**
Add this section to the workspace agent file:
```markdown
## WORKSPACE CONTINUITY SYSTEM (mandatory for Phase B+ workspaces)

Read these in order on every spawn or resume:
1. work-items.json → know what's queued, active, blocked
2. checkpoint notes → know what was done and what's next
3. Recent messages → get additional context

Do NOT ask the user for the work list — it's in work-items.json.

On every work-items.json update:
- After completing an item: set status=done, populate verified_by with evidence
- Before starting an item: set status=active
- Update the last_updated timestamp

Checkpoint notes format (mandatory):
"Done: [item], [item]. In progress: [item]. Next: [item], [item]."
```

**Step 3: Create workspace PM trigger**
Add to workspace agent spawn logic:
```bash
# Check if workspace has a workspace-pm template
if [ -f ~/pap-workspace/workspace-agent-templates/workspace-pm.md ]; then
  # Spawn workspace PM first to queue work, then spawn workspace agent
  spawn_workspace_pm "options-helper"
else
  # Fall back to direct workspace agent spawn (old behavior)
  spawn_workspace_agent "options-helper"
fi
```

---

## Implementation for New Workspaces (Scaffolder)

**Step 1: Update scaffolder.md**
When creating a new workspace, scaffolder should:
1. Create workspace directory structure
2. Create work-items.json template (empty, ready for user to populate)
3. Create a workspace-pm.md symlink or copy
4. Update workspace CLAUDE.md to include the continuity system section

**Step 2: Scaffold structure for new workspace**
```bash
~/marvin-bot/scaffolder.md "new-workspace-name"

# This should create:
# - ~/pap-workspace/workspaces/new-workspace-name/
# - ~/pap-workspace/workspaces/new-workspace-name/CLAUDE.md (with continuity section)
# - ~/pap-workspace/workspaces/new-workspace-name/work-items.json (template)
# - Channel in Discord (#new-workspace-name)
```

---

## Quick Reference: Workspace Agent Resume Flow

**User posts:** "⚡ Agent went quiet — picking it back up automatically." (or /resume)

**Workspace agent resumes:**
1. Read checkpoint notes
2. Read work-items.json
3. Identify next active item (or next queued if current is blocked)
4. Resume from there
5. Do NOT ask user for the work list

**If agent loses track:**
- Checkpoint notes are the source of truth
- work-items.json is the fallback
- Only ask user if both are corrupted (very rare)

---

## Rollout Plan

**Phase B-1 (proof of concept): options-helper**
- Create work-items.json for current open items
- Update workspace agent CLAUDE.md with continuity section
- Run one full release cycle (12 bugs → completed) with workspace PM
- Verify agent doesn't ask for list again on resume
- Verify all items marked done with evidence

**Phase B-2 (rollout): financial-review, daily-brief**
- Apply same process to each workspace
- Train workspace PMs to queue and delegate

**Phase B-3 (new workspaces):**
- Update scaffolder.md to create work-items.json + workspace PM integration automatically
- New workspaces ship with continuity system built-in

---
