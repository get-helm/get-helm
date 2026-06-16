# [ARCHIVED — Orchestrator removed 2026-06-10]
# Orchestrator Routing Classifier — Decision Matrix
## ORCHESTRATOR-CLASSIFIER (Level 4 — Requires Approval Before Implementation)
## Status: SPEC — awaiting {{USER_JERRY}} approval

---

## Purpose

Currently, HELM sends all multi-step tasks through the orchestrator. The classifier decides when to use orchestrator vs. direct agent spawn — reducing unnecessary orchestrator overhead on simple tasks while ensuring complex work still gets full orchestration.

---

## Decision Matrix

| Factor | Direct Spawn | Orchestrator |
|--------|-------------|--------------|
| Task steps | 1 step | 2+ steps |
| Reversibility | Level 0-2 (safe to auto-run) | Level 3+ (needs oversight) |
| Agent thread | Existing thread active | New task, no active thread |
| File changes | 0-1 files | 2+ files or cross-repo |
| Restart required | No | Yes |

**Rule**: ALL conditions for "Direct Spawn" must be true. One orchestrator condition → route to orchestrator.

---

## Classification Logic (pseudocode)

```
function classifyRoute(task):
  steps = countTaskSteps(task)         # heuristic: count numbered steps in description
  level = task.level || 1
  hasActiveThread = channelState.agentPid != null
  filesChanged = estimateFileCount(task)
  restartRequired = task.restart_required == 'yes'

  if steps >= 2: return 'orchestrator'
  if level >= 3: return 'orchestrator'
  if hasActiveThread: return 'orchestrator'
  if filesChanged >= 2: return 'orchestrator'
  if restartRequired: return 'orchestrator'
  return 'direct'
```

---

## Implementation Plan (pending approval)

1. Add `classifyRoute()` function to bot.js (~L4800, near orchestrator dispatch)
2. Call classifier before `[ORCHESTRATE:` sentinel check — if direct, skip sentinel
3. Log classification decision to event-stream as `routing_classify` event
4. No behavior change for orchestrator path — only direct spawns bypass orchestrator

**Risk**: Miscalibrated classifier could route complex tasks directly, bypassing orchestration. Mitigation: log every classification for PM to review first week.

---

## Approval criteria

- [ ] {{USER_JERRY}} approves decision matrix above
- [ ] {{USER_JERRY}} approves the "ALL conditions must be true for direct" rule
- [ ] Engineer implements after approval (Level 4 gate satisfied)

---
*Spec written: 2026-06-08 — awaiting CONFIRM in helm-improvements before any code change*
