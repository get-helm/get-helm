# HELM User/Core Partition Design
## Created: 2026-06-08 | Status: IMPLEMENTING

---

## The Problem

HELM grew organically — files for Core system behavior and User-specific data ended up
in the same flat directory with no distinction. When we add user 2, there's no
automated way to know which files to copy (Core) vs. leave alone (User data).

---

## The Three Categories

### 1. Core HELM (owned by pap-config repo)
These files are the same across all HELM instances. A new user gets them from the repo.
Updates flow from pap-config → instance via `helm-update.sh`.

- `CLAUDE.md`, `behaviors.md` — agent instructions
- `CAPABILITIES.md` — starts as template, instance can add entries
- All agent files (`~/.claude/agents/*.md`)
- All shell scripts (`~/marvin-bot/*.sh`)
- `specs/` — architecture specs (read-only reference)
- `knowledge/` — reference docs (read-only for agents)
- `recovery/RECOVERY-GUIDE.md`, `recovery/RECOVERY-AI-PROMPT.template.md`

### 2. User Data (instance-specific, never overwritten by updates)
These files are specific to the user. New user starts from a blank template.
Updates to pap-config NEVER touch these.

- `CONFIG.md` — Discord tokens, email, timezone
- `ABOUT-ME.md` — user identity
- `VOICE-AND-STYLE.md` — user preferences
- `knowledge/USER-PROFILE.md` — user profile (future: `user/PROFILE.md`)
- `workspaces/` — all workspace data
- `second-brain/` — user's personal knowledge base
- `channel-state/` — Discord channel state
- `data/` — user's data files

### 3. Runtime State (generated, transient, never committed)
These files are created at runtime by agents. Never committed to pap-config.

- `system/pm-log.md`, `system/friction-log.md`, `system/decisions-log.md`
- `system/engineer-queue.md`, `system/queue-audit.log`
- `ACTIVE-STATE.md`
- `system/steward-findings.md`, `system/synthesizer-findings.md`
- `recovery/RECOVERY-AI-PROMPT.md` (generated from template)

---

## The Controls

### Control 1: PARTITION.json manifest
A machine-readable manifest at `~/pap-workspace/PARTITION.json` declaring each file's category.
Used by update and validation scripts.

### Control 2: helm-partition-check.sh
Validates that files are in the right category. Runs before every update.
Outputs warnings — never blocks automatically (audit mode).

### Control 3: helm-update.sh (future)
Safe update script that:
- Pulls pap-config changes
- Updates Core files (agents, scripts, CLAUDE.md)
- Skips User data files entirely
- Merges CAPABILITIES.md (append-only, never clobber)
- Runs partition check before and after

### Control 4: .gitignore in pap-config/workspace/
Prevents User data and Runtime files from being accidentally committed.

---

## Directory Enforcement

The new directory structure (from HELM-RESTRUCTURE-001) enforces this naturally:
- `system/` = Runtime State → gitignore *.md in system/ except reference docs
- `knowledge/` = Core reference (except USER-PROFILE.md which is User)
- `product/` = Core product planning (VISION-TRACKER, BUILD-ROADMAP)
- `recovery/` = Core templates + generated runtime
- `specs/` = Core architecture specs
- `workspaces/` = User data → gitignore entirely
- `second-brain/` = User data → gitignore entirely

---

## User Data Migration Path (for user 2 onboarding)

When setting up user 2:
1. Clone pap-config repo
2. Copy `pap-config/workspace/` → `~/pap-workspace/` (Core files only)
3. Run `helm-init.sh` — creates User data stubs from templates
4. User fills in `CONFIG.md`, `ABOUT-ME.md`, `VOICE-AND-STYLE.md`
5. Done — User data is separate, Core files are from repo

---

## Next Steps (engineer queue items)

- [ ] Create `PARTITION.json` manifest (this session)
- [ ] Create `helm-partition-check.sh` validation script (this session)
- [ ] Create `helm-init.sh` new-user bootstrap script (future)
- [ ] Create `helm-update.sh` safe update script (future)
- [ ] Update `pap-config/workspace/` to reflect new directory structure (future)
