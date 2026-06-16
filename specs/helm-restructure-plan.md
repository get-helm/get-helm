# HELM Restructure Plan
## Created: 2026-06-08 | Status: PROPOSED — awaiting approval

---

## Phase 1: Safe Deletes — COMPLETE ✅

11 items deleted:
- 3 test workspaces (test-workspace-bb, test-workspace-phase-b, test-continuous-exec)
- 2 standard .bak files (pm-scratch.md.bak, system-state.md.bak)
- 3 non-standard backup files (engineer-context.md.bak-*, engineer-queue.md.backup-*, engineer-queue.md.bak-*)
- 3 stale spec files (helm-architecture-v2.md, morning-brief-2026-05-13.md, PM-REVIEW-SNAPSHOT-2026-05-15.md)

---

## Phase 2: File Taxonomy Restructure

### Proposed Directory Structure

```
pap-workspace/
│
├── [ROOT — stays here, required by agents/Claude/bot.js]
│   CLAUDE.md          ← Claude requires root
│   behaviors.md       ← CLAUDE.md @includes it
│   CONFIG.md          ← agents read constantly
│   ABOUT-ME.md        ← agent identity
│   VOICE-AND-STYLE.md ← discord-post.sh reads from root
│   ACTIVE-STATE.md    ← agents read on resume
│   CAPABILITIES.md    ← agents check before approaching
│   work-items.json    ← PM reads every sweep
│   pm-jobs.md         ← PM reads every sweep
│   channel-registry.json ← bot.js reads via WORKDIR
│
├── system/            ← NEW: agent runtime + operational files
│   engineer-queue.md
│   engineer-context.md
│   friction-log.md
│   friction-analysis.md
│   behaviors-status.md
│   pm-ledger.md
│   pm-log.md
│   decisions-log.md
│   pm-pending-decisions.json
│   validation-daily.md
│   queue-audit.log
│   queue-convergence-state.json
│   port-registry.json
│   DONE-ARCHIVE.md
│   QUEUE-VIEW.md
│   pm-scratch.md
│
├── knowledge/         ← NEW: reference docs agents read, rarely write
│   pap-complete.md
│   PAP-FACTS.md
│   USER-PROFILE.md
│   DOC-MATRIX.md
│   DOC-REGISTRY.md
│   PM-ORCHESTRATOR-CONTRACT.md
│   ORCH-02-worker-contract.md
│   WORKSPACE-ARCHITECTURE.md
│   MULTI-TENANT-DESIGN.md
│   MEMORY-CAPABILITIES.md
│   PAP-AUDIT.md
│
├── product/           ← NEW: product planning, PM agent domain
│   VISION-TRACKER.md
│   BUILD-ROADMAP.md
│   MASTER-BACKLOG.md
│   CHALLENGED-ITEMS.md
│   idea-backlog.md
│   idea-queue.md
│   design-tracker.md
│   MULTI-USER-BACKLOG.md
│   project-backlog.md
│
├── recovery/          ← NEW: recovery system files
│   RECOVERY-AI-PROMPT.md
│   RECOVERY-AI-PROMPT.template.md
│   RECOVERY-GUIDE.md
│   RECOVERY-IMPLEMENTATION-STATUS.md
│   helm-recovery-implementation-status.md
│   context-reset-prompt.md
│
├── specs/             ← RENAME: helm-specs → specs
│   (all existing helm-specs/ content)
│   PLUS from root:
│   P5.1-ONBOARDING-SPEC.md
│   P5.2-HELP-SYSTEM-SPEC.md
│   P5.3-WORKSPACE-DASHBOARD-SPEC.md
│   P5.4-PREFERENCES-CHANNEL-SPEC.md
│   mission-control-behaviors-spec.md
│   second-brain-ingestion-spec.md
│   DES-ONBOARD-FLOW.md
│   INF-07-DESIGN.md
│   settings-registry.md
│   TASK-069-implementation-plan.md
│   TASKS-INVESTIGATION.md
│
├── [existing dirs — keep as-is]
│   channel-state/     workspaces/     history/
│   second-brain/      transcripts/    logs/
│   scripts/           data/           events/
│   orchestrator/      mockups/        research/
│   specs/             proposals/
```

---

## Code Changes Required

### Bot.js (~35 lines)
- `pm-log.md` → `system/pm-log.md` (line 14)
- `friction-log.md` → `system/friction-log.md` (~25 lines using process.env.HOME + /pap-workspace/)
- `engineer-queue.md` → `system/engineer-queue.md` (lines 3923, 5567, 5709)
- `RECOVERY-GUIDE.md` → `recovery/RECOVERY-GUIDE.md` (line 3403)

### Shell Scripts (4 files)
- `pm-pre-queue-check.sh` line 9: CHALLENGED-ITEMS.md → `product/CHALLENGED-ITEMS.md`
- `generate-recovery-prompt.sh` line 5: template path → `recovery/RECOVERY-AI-PROMPT.template.md`
- `pap-recovery-test.sh` line 156: RECOVERY-GUIDE.md → `recovery/RECOVERY-GUIDE.md`
- `self-improve.sh`: pap-complete.md → `knowledge/pap-complete.md`

### Agent Files (1 file)
- `~/.claude/agents/product-manager.md` line 262: VISION-TRACKER.md → `product/VISION-TRACKER.md`

### Total reference updates: ~42 changes across 6 files

---

## Migration Sequence (safe — no downtime)

1. Create new directories (`mkdir system/ knowledge/ product/ recovery/ specs/`)
2. Copy (not move) files to new locations
3. Update all references in bot.js, shell scripts, agent files
4. Run test: `pm-pre-queue-check.sh`, `generate-recovery-prompt.sh`, bot.js start
5. Delete old files after tests pass

---

## Phase 3: Additional Cleanup (after Phase 2)

**Additional deletions (with note on why safe):**
- `pm-incident-postmortem.md` — historical log, no active references
- `orchestrator-selftest-log.md` — one-off test log, not referenced
- `pap-status-brief.md` — check if still generated or manual
- `synthesizer-findings.md` — check if still written to

**Defer to later (in-use but worth reviewing):**
- `TASK-069-implementation-plan.md` — active spec referenced in bot.js + work items
- `TASKS-INVESTIGATION.md` — referenced in engineer-context.md

---

## Phase 4: Bot.js Modularization (separate L4 decision)

Bot.js is 5,256 lines handling 6 distinct concerns:
1. Discord event routing
2. Channel state management  
3. Protocol validation (B-01, B-06, etc.)
4. UI sentinel parsing (CONFIRM, BUTTON, etc.)
5. Agent spawning + watchdog
6. PM/nightly triggers

**Proposed split:**
- `bot.js` — Discord event loop + routing only (~1,500 lines)
- `lib/validation.js` — Protocol checks (~1,200 lines)
- `lib/state.js` — Channel state management (~800 lines)
- `lib/ui-parser.js` — Sentinel parsing (~600 lines)
- `lib/scheduler.js` — Nightly/periodic triggers (~400 lines)

**Risk:** High. Shared mutable state between sections means this is a careful refactor,
not a simple cut-and-paste. Should be a dedicated engineer session with a rollback tag.

---

## Summary: Files at root BEFORE vs AFTER

| | Before | After |
|---|---|---|
| Root .md files | 64 | ~10 |
| Root .json files | 18 | ~5 |
| Total root files | 82+ | ~15 |
| Directories | flat mess | 5 named dirs |

---

*All moves are reversible. No bot.js deploy until after tests pass.*
