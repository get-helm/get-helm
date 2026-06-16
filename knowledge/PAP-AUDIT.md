# PAP System Audit
## Conducted: 2026-05-11
## Scope: pap-workspace (docs + configs), marvin-bot (scripts + plists), ~/.claude (agents + skills)

---

## What's Running on the Mac Mini (LaunchAgents)

10 plists registered under `~/Library/LaunchAgents/com.pap.*`:

| Label | Script | Interval | Status |
|-------|---------|----------|--------|
| com.pap.marvin | bot.js | KeepAlive | Running (PID 98278) |
| com.pap.watchdog | pap-watchdog.sh | 120s | Loaded |
| com.pap.heartbeat | pap-heartbeat.sh | 120s | Loaded |
| com.pap.github-heartbeat | pap-github-heartbeat.sh | 600s | Loaded |
| com.pap.marvin.heartbeat | marvin-discord-heartbeat.sh | 3600s | Loaded |
| com.pap.pm.sweep | pm-trigger-schedule.sh | 900s | Loaded |
| com.pap.pm.heartbeat | pm-trigger-heartbeat.sh | Daily 2AM | Loaded |
| com.pap.pm-heartbeat | pm-heartbeat.sh | 3600s | Loaded |
| com.pap.etf-pending-tickers | process_pending_tickers.sh | 300s | Loaded |
| com.pap.etf-monthly-pull | run_monthly_pull.sh | 1st/month 6AM | Loaded |

### What each actually does

- **com.pap.marvin** — bot.js main process, KeepAlive restarts on crash
- **com.pap.watchdog** — every 2 min, checks if bot.js is running + not zombie; auto-restarts if silent >5 min; alerts #pap-status
- **com.pap.heartbeat** — every 2 min, pings VPS health endpoint at {{USER_VPS_TAILSCALE_IP}}:9876 (Tailscale IP)
- **com.pap.github-heartbeat** — every 10 min, posts a dispatch event to GitHub Actions; a health-check.yml workflow monitors for silence
- **com.pap.marvin.heartbeat** — every hour, posts "💓 Marvin online" to #pap-status Discord
- **com.pap.pm.sweep** — every 15 min, writes pm-trigger.json → bot.js watches this, spawns PM agent
- **com.pap.pm.heartbeat** — 2AM daily, writes pm-trigger.json (daily PM heartbeat variant)
- **com.pap.pm-heartbeat** — every hour, posts ACTIVE-STATE summary directly to Discord using 1Password token fetch
- **com.pap.etf-pending-tickers** — every 5 min, processes any pending ETF ticker additions
- **com.pap.etf-monthly-pull** — 1st of each month at 6AM, runs full ETF data pull

---

## Inconsistencies — Priority Ordered

### 🔴 CRITICAL

**1. com.pap.marvin.plist has invalid XML**
The plist contains literal `&&` (shell `&&` in the ProgramArguments command string), which is invalid XML. plutil reports "Encountered unknown ampersand-escape sequence at line 11." Bot.js is running fine because launchd already loaded it into memory, but any future `launchctl unload/load` or plist read by tooling will fail. Silent time bomb.
- Root cause: The ProgramArguments uses a shell string (`-c "cd /marvin-bot && export $(cat .env) && node bot.js"`) with unescaped `&` characters.
- Fix: Replace `&&` with `&amp;&amp;` in the XML, or restructure to use environment-key plist fields instead of shell inline. Level 2, needs supervised restart.
- Current state: bot runs fine; fix at next planned restart.

**2. Duplicate WORKSPACE in CONFIG.md**
`chain-test` appears twice with different channel IDs (1501319343076540527 and 1501319389881045042). The workspace registry is unreliable. Agents reading it would see two conflicting entries.
- Fix: Remove the duplicate. Confirm which channel was the real chain-test.

### 🟡 MEDIUM

**3. CONFIG.md colors don't match VOICE-AND-STYLE.md**
CONFIG.md: `COLOR_PRIMARY: #2563eb` (blue)
VOICE-AND-STYLE.md: `COLOR_PRIMARY: #4A7C59` (Olive-4, active)
These are supposed to match. Two sources of truth for the same setting.
- Fix: Update CONFIG.md colors to match Olive-4, or remove colors from CONFIG.md entirely (VOICE-AND-STYLE is the canonical source).

**4. pm-heartbeat.sh uses wrong channel ID**
pm-heartbeat.sh targets Discord channel `1338934899171135549` — not the same as #pap-status ({{USER_CHANNEL_HELM_STATUS}}) used by every other heartbeat script. This is likely a stale channel reference from an early session.
- Fix: Update to {{USER_CHANNEL_HELM_STATUS}}, or confirm the intended channel.

**5. pm-heartbeat.sh fetches token from 1Password; others read from .env**
If the 1Password CLI session expires (common on Mac mini when idle), pm-heartbeat.sh silently fails with no alert. Every other heartbeat reads the token from .env directly.
- Fix: Standardize to .env reads, or add an explicit error alert when 1P fetch fails.

**6. DOC-REGISTRY.md has stale entries**
Multiple entries are now wrong:
- pap-complete.md: says "currently a stub — needs authoring" — it's fully authored
- gate-3-verification-test.md: classified OPERATIONAL — it's test results, should be archived
- Missing from registry: TASKS-INVESTIGATION.md, event-stream.jsonl, scheduler-test.log, work-registry-view.json, PAP-AUDIT.md (this file)
- Fix: Update registry in this same session.

**7. BUILD-ROADMAP.md has stale status**
- P4.3 "pap-complete.md authored" — marked "Not done" → it's done
- P4.4 "DOC-REGISTRY.md" — marked "Not built" → it's built
- Fix: Update status fields.

**8. BACKLOG.md item #1 conflicts with current decision**
Item 1: "Disable startup-recovery — still active, still a crash liability."
{{USER_JERRY}}'s decision (2026-05-11): keep recovery, add a loop guard (3 attempts in 5 min → alert + stop). The "disable" direction is now wrong and will confuse any agent that reads the backlog.
- Fix: Replace with "Recovery loop guard — built, awaiting deploy."

**9. ONBOARDING_COMPLETED: false, HELP_VISITED: false**
Both still false in CONFIG.md after 10+ sessions of active use. Any agent that reads these and acts on them will trigger onboarding flows that aren't appropriate.
- Fix: Set both to true.

### ⚪ LOW / CLEANUP

**10. 4 ghost workspaces in CONFIG.md**
wake-time, bug013-test, chain-test (x2) are all STATUS: designing with no corresponding active work. These are early test workspaces. They clutter the registry and could confuse scaffolder.
- Fix: Archive or remove from CONFIG.md. Keep directories but mark as ARCHIVED.

**11. TASKS-INVESTIGATION.md at workspace root**
Historical investigation file (from 2026-05-07). Not in DOC-REGISTRY. Not operational. Notes that pap-complete.md didn't exist yet — now stale.
- Fix: Archive to archived/ directory with datestamp header.

**12. etf-tracker has 50+ research artifacts**
50+ explore_*, test_* Python scripts in the workspace root. These are research artifacts from the Phase A/B loop work, not production code. They make it hard to find the actual production scripts.
- Fix: Move to /archive subdirectory. Production scripts: pull_real_data.py, run_monthly_pull.sh, process_pending_tickers.sh, build_html.py, pap-sheets-related scripts.

**13. CAPABILITIES.md header date is stale**
Header says "Updated: May 5, 2026" but the file has been updated many times since. The date is supposed to signal currency.
- Fix: Remove the static date or set to "last updated automatically."

**14. pap-all-workflows.md referenced but doesn't exist**
product-manager.md references pap-all-workflows.md as a Level 5 constitutional doc alongside pap-complete.md. It was never created. pap-complete.md now supersedes it.
- Fix: Remove references to pap-all-workflows.md from product-manager.md; replace with pap-complete.md.

---

## Product vs. User Settings Classification

### Product decisions — not user-configurable
These are architectural and should be the same for all users of PAP:
- LaunchAgent structure and scripts
- bot.js routing logic and turn protocol
- Level 0-5 authority scale
- BML loop discipline and enforcement
- Phase marker enforcement
- Agent file structure and contracts
- Checkpoint protocol
- Recovery and watchdog behavior

### User-configurable settings (in CONFIG.md / VOICE-AND-STYLE.md)
These differ per user and are explicitly personal:
- AGENT_NAME, USER_PREFERRED_NAME, GOOGLE_EMAIL, DISCORD_SERVER_ID
- COLOR_PRIMARY, COLOR_ACCENT_1, COLOR_ACCENT_2, DISPLAY_MODE
- TIMEZONE, DATE_FORMAT, TIME_FORMAT, WEEK_STARTS_ON
- TRUST_* settings (calendar/email/drive read/write)
- PROACTIVE_OUTREACH
- IMPROVEMENTS_FREQUENCY, IMPROVEMENTS_MAX_SURFACED
- USAGE_WARNING_THRESHOLD, USAGE_REPORTING_FREQUENCY
- OUTPUT_DESTINATION, OUTPUT_DRIVE_PREFERENCE
- VOICE-AND-STYLE.md: tone, length preference, standing preferences, writing samples, color palette

### Ambiguous — needs explicit classification before Phase 4 (sharing)
- WORKSPACE registry in CONFIG.md — this is personal ({{USER_JERRY}}'s workspaces), but the registry structure itself is product. Should be split: workspace structure = product, workspace list = personal.
- Agent files (CLAUDE.md, ~/.claude/agents/) — product, but may contain {{USER_JERRY}}-specific values that need templating
- ABOUT-ME.md — entirely personal; needs clean templating guide for new users

---

## What's Shareable (for Phase 4)

**PRODUCT files (shareable, need value-templating):**
- CLAUDE.md, pap-complete.md, vision-doc.md (remove session-specific references)
- BUILD-ROADMAP.md, CAPABILITIES.md
- All ~/.claude/agents/*.md files
- All ~/.claude/skills/ directories
- All /specs files
- Marvin-bot scripts (pap-heartbeat.sh, watchdog.sh, safe-restart.sh, rollback.sh, grab-logs.sh, discord-post.sh)
- LaunchAgent plist templates (with placeholder values)

**PERSONAL files (strip before sharing):**
- ABOUT-ME.md, VOICE-AND-STYLE.md, CONFIG.md
- All second-brain content
- All workspace-specific data files (real-data.json, etc.)
- .env file (credentials)

**OPERATIONAL files (not shared):**
- ACTIVE-STATE.md, friction-log.md, marvin.log, heartbeat.log, event-stream.jsonl
- All channel-state/*.json files
- All bot.js.bak-* files

---

## Files Not in DOC-REGISTRY (need to be added)

- PAP-AUDIT.md (this file) → PRODUCT
- TASKS-INVESTIGATION.md → archived (stale)
- event-stream.jsonl → OPERATIONAL
- scheduler-test.log → OPERATIONAL
- work-registry-view.json → OPERATIONAL
- mockup-v3.html, palette-olive.html, palette-options.html, palette-v2.html → OPERATIONAL (UI artifacts, not production)
- wake-button-msg-id.txt → OPERATIONAL
- idea-backlog.md → PERSONAL (already in registry, confirmed)

---

## Recommended Actions (grouped by effort)

### Do now (Level 0-1, in this session)
1. Fix com.pap.marvin.plist (lint + rebuild)
2. Remove duplicate chain-test from CONFIG.md
3. Set ONBOARDING_COMPLETED and HELP_VISITED to true in CONFIG.md
4. Sync colors: update CONFIG.md to Olive-4 values
5. Update DOC-REGISTRY.md (stale entries + missing files)
6. Update BUILD-ROADMAP.md (two stale status flags)
7. Replace BACKLOG.md item #1 with correct recovery guard status
8. Fix pm-heartbeat.sh channel ID
9. Archive TASKS-INVESTIGATION.md

### Do before Phase 4 (before sharing PAP with anyone else)
10. Standardize token fetch to .env in pm-heartbeat.sh
11. Archive ghost workspaces from CONFIG.md
12. Move etf-tracker research artifacts to /archive
13. Remove pap-all-workflows.md references from product-manager.md
14. Audit all product files for {{USER_JERRY}}-specific values (prep templating)
15. Add workspace registry split (product structure vs. personal list)

---

*Audit by: Marvin | 2026-05-11*
*Next audit: before Phase 4 (sharing) begins, or after any major structural change*
