# PAP Doc Registry
## Every file in pap-workspace, classified
## Updated: 2026-05-11

---

## How to read this

**Type:**
- `PRODUCT` — part of the shareable PAP package; anyone who runs PAP gets this
- `PERSONAL` — {{USER_JERRY}}'s config; stays with {{USER_JERRY}}, not shared by default
- `OPERATIONAL` — runtime state; not human-authored, resets/overwrites itself
- `WORKSPACE` — lives under a specific workspace, not at root level

---

## Root files

| File | Type | What it is |
|------|------|-----------|
| CLAUDE.md | PRODUCT | Agent operating instructions (dispatcher, routing, protocols) |
| ABOUT-ME.md | PERSONAL | {{USER_JERRY}}'s profile, PAP identity, contact info |
| VOICE-AND-STYLE.md | PERSONAL | Communication preferences, colors, standing prefs |
| CONFIG.md | PERSONAL | Feature flags, schedule settings, per-user config |
| pap-complete.md | PRODUCT | Constitutional doc — fully authored (2026-05-11) |
| vision-doc.md | PRODUCT | Full vision + HMW principles (Session 11) |
| BUILD-ROADMAP.md | PRODUCT | Synthesis → concrete build phases (this document's sibling) |
| BACKLOG.md | OPERATIONAL | Engineer task queue |
| ACTIVE-STATE.md | OPERATIONAL | Current in-flight state (auto-reset) |
| CAPABILITIES.md | PRODUCT | What PAP can actually do (PROVEN/FAILED registry) |
| engineer-context.md | OPERATIONAL | Active task IDs, current sprint |
| engineer-queue.md | OPERATIONAL | Queued engineer requests |
| decisions-log.md | PRODUCT | Architectural decisions + rationale |
| friction-log.md | OPERATIONAL | Auto-logged friction events |
| friction-analysis.md | PRODUCT | Patterns from friction log (human-reviewed) |
| idea-backlog.md | PERSONAL | {{USER_JERRY}}'s idea queue |
| context-reset-prompt.md | PRODUCT | Prompt for fresh session with full context |
| pap-status-brief.md | OPERATIONAL | Current health snapshot |
| IMPROVEMENT-SUMMARY.md | OPERATIONAL | Recent self-improvement summary |
| RECOVERY-GUIDE.md | PRODUCT | Step-by-step recovery instructions |
| DOC-REGISTRY.md | PRODUCT | This file |
| DOC-MATRIX.md | PRODUCT | Per-agent documentation requirements matrix — enforces which docs must be updated for each action class |
| PAP-AUDIT.md | PRODUCT | Full system audit — inventory, inconsistencies, product vs. user classification |
| TASKS-INVESTIGATION.md | ARCHIVED | Historical task investigation (2026-05-07) — stale, see pap-complete.md |
| event-stream.jsonl | OPERATIONAL | Live event stream (bot.js writes) |
| scheduler-test.log | OPERATIONAL | Test artifact |
| work-registry-view.json | OPERATIONAL | Runtime registry snapshot |
| wake-button-msg-id.txt | OPERATIONAL | Discord message ID for wake button |

## /specs

| File | Type | What it is |
|------|------|-----------|
| auto-reset-spec.md | PRODUCT | Spec for ACTIVE-STATE auto-reset behavior |
| debugging-guide.md | PRODUCT | How to debug PAP issues |
| engineer-auto-trigger-spec.md | PRODUCT | How engineer agent auto-triggers |
| quota-handling-spec.md | PRODUCT | Claude API quota handling design |
| restart-engineering-spec.md | PRODUCT | Safe restart architecture |
| restart-validation-checklist.md | PRODUCT | Pre-restart verification steps |
| rich-discord-ui-spec.md | PRODUCT | Discord embed design patterns |
| thread-support-spec.md | PRODUCT | Discord thread handling spec |
| gate-3-verification-test.md | OPERATIONAL | Test results, not a spec |

## /second-brain

| File | Type | What it is |
|------|------|-----------|
| 2026-*.md | PERSONAL | {{USER_JERRY}}'s saved articles/videos/links |

## /workspaces

Each workspace has its own subdirectory. All workspace files are WORKSPACE type.
Standard structure: CLAUDE.md, SPEC.md, TASKS.md, ASSUMPTIONS.md, DECISIONS.md, LEARNINGS.md, RESEARCH-LOG.md

---

## What goes in a shareable PAP package

All `PRODUCT` files — excluding any file that contains {{USER_JERRY}}-specific values (user IDs, email addresses, Discord server IDs). Before sharing:
1. Templatize ABOUT-ME.md (replace values with `YOUR_NAME`, `YOUR_EMAIL`, etc.)
2. Clear CONFIG.md to defaults
3. Clear VOICE-AND-STYLE.md to defaults
4. Strip personal data from VOICE-AND-STYLE.md writing samples

---

*This file should be updated whenever a new .md is created at root level or in /specs.*
