# Google Drive HELM Folder — Canonical Structure

Status: spec approved by {{USER_JERRY}} 2026-06-10 ("clean up and organize that folder, then put in place rules that ensure agents don't make a mess of it again").
Enforcement: behaviors.md B-19 placement rule + nightly drift check (DRIVE-CLEANUP-001).

## Canonical layout (HELM folder root)

```
HELM/
├── Backups/          # VPS + bot backups (ENG-VPS-BACKUP-DRIVE-001 writes here)
│   └── vps/
├── Dashboards/       # Sheets dashboards (Mandates dashboard lives here)
├── Reports/          # Generated reports, briefs shared with {{USER_JERRY}}
│   └── YYYY-MM/      # one subfolder per month — no loose files in Reports/
├── Specs/            # Design docs shared for {{USER_JERRY}} review
├── Workspaces/       # one subfolder per workspace (etf-tracker/, options-helper/, ...)
└── Archive/          # anything superseded — move, never delete
```

## Placement rules (all agents)

1. **Never create a file in HELM root.** Every file goes in one of the six folders above. No exceptions.
2. **No new top-level folders** without a [CONFIRM] to {{USER_JERRY}}. Six folders is the contract.
3. **Workspace outputs** → `Workspaces/[workspace-name]/`. Create the subfolder if missing.
4. **Naming:** `YYYY-MM-DD-short-name` for dated artifacts; plain descriptive names for living docs. No internal IDs (TASK-XXX) in filenames.
5. **Supersede, don't duplicate:** updating a doc → update the same file. A v2 file next to a v1 = violation; move v1 to Archive/ if a new file is truly needed.
6. **Multi-user:** for any additional user's Drive, replicate this exact template under their HELM folder. Structure is per-user identical; never mix users' files.

## Enforcement

- behaviors.md B-19 carries the placement rule (agent self-check surface).
- Nightly drift check (engineer item DRIVE-CLEANUP-001): list HELM root — any loose file or unknown top-level folder → auto-move to best-match folder, log to helm-audit.log, friction-log `DRIVE-DRIFT` entry.
- PM T2 sweep: review DRIVE-DRIFT entries; 3+ in a week from same agent class → queue fix.

## Initial cleanup (one-time, part of DRIVE-CLEANUP-001)

1. Inventory current HELM folder (all files + folders, with mtimes).
2. Create the six canonical folders.
3. Move every existing file to its best-match folder (Archive/ if unclear).
4. Post before/after summary to helm-improvements — one message, no per-file noise.
