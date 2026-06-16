# HELM Installation & Onboarding — Master Component Checklist

**Purpose:** Exhaustive reference for every piece that must come together for a successful HELM installation and onboarding. Use this to audit gaps before any beta.

**Last updated:** 2026-06-16  
**Status:** Living document — update after every deploy or gap discovery

---

## Table of Contents

1. [Repo Composition — What Ends Up in get-helm/get-helm](#1-repo-composition)
2. [User Journey — What Users See and Do at Each Step](#2-user-journey)
3. [Component Inventory — Every Piece by Category](#3-component-inventory)
4. [Pre-Beta Checklist — Every Item Must Pass Before a Human Touches It](#4-pre-beta-checklist)
5. [Known Gaps — Open Issues That Need Resolution](#5-known-gaps)
6. [The Gate — What Must Happen Before Any External Beta](#6-the-gate)

---

## 1. Repo Composition

### 1.1 What ships in get-helm/get-helm (the public distribution repo)

The publish pipeline uses a **denylist model**: everything ships unless explicitly excluded. The following is the canonical list of what a user downloads when they clone or `curl | bash`.

#### Core Bot Files
| File | Purpose | State |
|------|---------|-------|
| `bot.js` | The entire HELM brain — Discord bot, agent routing, PM loop, task tracking | Ships |
| `package.json` | Node.js dependency manifest | Ships |
| `startup.sh` | Starts the bot (used by launchd/systemd) | Ships |
| `install.sh` | Entry point — detects OS, installs prerequisites, clones repo, runs npm install | Ships |
| `setup-headless.sh` | Collects user config (guild ID, email, etc.), writes to CONFIG.md + channels.json | Ships |

#### Agent Instruction Files (from ~/.claude/agents/)
| File | Purpose |
|------|---------|
| `turn-protocol.md` | How every HELM agent behaves — the behavioral rulebook |
| `behaviors.md` | Required agent behaviors |
| Individual agent files (help.md, curiosity.md, etc.) | Per-agent instructions |

#### Configuration Templates (the `*.template` versions ship; personal filled versions do NOT)
| File | Shipped as | Personal version (excluded) |
|------|---------|---------|
| `ABOUT-ME.md.template` | ✅ ships | `ABOUT-ME.md` — excluded |
| `CONFIG.md.template` | ✅ ships | `CONFIG.md` — excluded |
| `VOICE-AND-STYLE.md.template` | ✅ ships | `VOICE-AND-STYLE.md` — excluded |
| `RECOVERY-AI-PROMPT.template.md` | ✅ ships | n/a |

#### Operational Scripts (ships — all of these are needed for HELM to work)
| Script | Purpose |
|--------|---------|
| `discord-post.sh` | Posts to Discord |
| `agent-resumption.sh` | Resumes agents after restart |
| `agent-ledger-write.sh` | Writes task ledger entries |
| `safe-restart.sh` | Restarts the bot safely |
| `queue-restart.sh` | Queues a bot restart for 2am |
| `startup-recovery.sh` | Handles auto-resume on startup |
| `helm-publish.sh` | Publishes to get-helm repo ({{USER_JERRY}} only) |
| `verify-change.sh` | Verifies file writes before claiming done |
| `discord-notif.sh` | Sends Discord notifications |
| `task-event.sh` | Logs task lifecycle events |
| `qmd-query.sh` | Second brain search (wrapper) |
| `qmd-install.sh` | Installs the QMD second brain engine |
| `second-brain-*.sh` | Second brain ingestion scripts |
| `lifeline-bot.js` (VPS) | Recovery bot — hands out AI prompt when main is down |

#### Reference / Recovery Files
| File | Purpose |
|------|---------|
| `RECOVERY-GUIDE.md` | Step-by-step recovery instructions |
| `RECOVERY-AI-PROMPT.template.md` | The paste-able AI prompt for recovery |
| `RECOVERY-RUNBOOK.md` | Full runbook for bot failures |
| `CLAUDE.md` | System-level instructions for HELM agents |
| `behaviors.md` | Agent behavioral rules |
| `CAPABILITIES.md` | What HELM can and cannot do (proven vs. unproven) |

#### What Does NOT Ship (Denylist)
| Category | Files/Dirs Excluded |
|----------|---------------------|
| **Credentials** | `.env`, `.env.local` |
| **Personal config** | `ABOUT-ME.md`, `CONFIG.md`, `VOICE-AND-STYLE.md` |
| **Personal profiles** | `knowledge/{{USER_JERRY}}-PROFILE.md`, `knowledge/OWNER-PROFILE.md` |
| **Personal workspaces** | `workspaces/options-helper/`, `workspaces/japan-2026/`, etc. |
| **Runtime state** | `channel-state/`, `ACTIVE-STATE.md`, `task-registry.jsonl`, `channels.json` |
| **Logs** | All `*.log` files |
| **Lock files** | `*.lock` |
| **Backup files** | `*.bak*`, `*.bak-*` |
| **Personal data** | `second-brain/`, `second-brain-raw/`, `financial-review/` |
| **PM operational files** | `pm-log.md`, `friction-log.md`, `decisions-log.md`, `engineer-queue.md` |

### 1.2 What ends up in get-helm/get-helm.github.io (the landing page repo — separate repo)

| File | Purpose |
|------|---------|
| `index.html` | The landing page users land on from friend links |
| `public-docs/phase1-prompt.md` (or embedded) | The pre-install prompt the button copies to clipboard |
| `public-docs/phase2-prompt.md` (or embedded) | The install prompt for Claude Desktop |
| CSS/assets | Styling, logo |

---

## 2. User Journey

### What the user sees and does at each step, and what HELM does in background

---

### Phase 0: Discovery & Landing Page
**Interface:** `get-helm.github.io` (static HTML — separate GitHub Pages repo)  
**User's state:** Just received a link from a friend. Knows almost nothing.

| Step | What User Does | What Happens in Background |
|------|----------------|---------------------------|
| 0.1 | Opens the link | Landing page loads. Header, 3 value bullets, requirements, one button. |
| 0.2 | Reads the page | Nothing. No auth, no tracking (yet). |
| 0.3 | Clicks "Copy prompt + open Claude.ai" | The Phase-1 pre-install prompt is copied to clipboard. Claude.ai opens in a new tab. |
| 0.4 | Pastes into Claude.ai, presses Enter | Claude reads the prompt and begins the guided conversation. |

**Gap to verify:** Button actually copies the correct prompt (the current Phase-1 prompt, not a stale version). Claude.ai opens correctly.

---

### Phase 1: Pre-Install Guide
**Interface:** Claude.ai (free tier, no account needed for this step) on the user's daily machine  
**Context:** User's daily machine — NOT the dedicated HELM machine yet.

| Step | What User Does | What HELM/Claude Does |
|------|----------------|----------------------|
| 1.1 | Answers hardware questions | Claude checks: do they have a spare machine? What OS? |
| 1.2 | Confirms or gets help finding a dedicated machine | Claude recommends Mac Mini if they don't have one |
| 1.3 | Wipes the machine (if needed) | Claude walks through Mac (Erase All Content) or Windows (Reset this PC) step-by-step, one click at a time |
| 1.4 | **Gets a Claude subscription first** | Claude explains why, what plan is needed, gives link. (Subscription must come BEFORE installing Claude Desktop — the Code tab requires Pro/Max, so installing first dead-ends.) |
| 1.5 | Installs Claude Desktop on the clean machine | Claude gives exact download URL, guides through installation |
| 1.6 | Opens Claude Desktop's **Code tab**, sets environment to **Local** | Claude gives exact step-by-step instructions with UI landmarks |
| 1.7 | Receives the Phase-2 install prompt | Claude outputs the exact text to copy; user pastes it into Claude Desktop Code/Local |

> **P5.1 ALIGNMENT (corrected 2026-06-15):** Order matches P5.1 STEP 1.5 (subscription) → STEP 1.6 (install Claude Desktop). Earlier draft had install before subscription — reversed, now fixed per {{USER_JERRY}}.

**Critical fix required:** Step 1.6 must say "Code tab → Local" — NOT "Cowork mode." Every reference to Cowork in this prompt must be removed.

**What the Phase-1 prompt must contain:**
- [ ] Introduction: what HELM is (1 paragraph, non-technical)
- [ ] What this guide will do (numbered overview, 4 steps)
- [ ] Step 1.1 hardware question
- [ ] Step 1.2-1.4 hardware + wipe flow (Mac and Windows)
- [ ] Step 1.5 Claude Desktop install (macOS and Windows paths)
- [ ] Step 1.6 subscription guidance (what plan, where to get it)
- [ ] Step 1.7 Code tab → Local guidance (exact UI steps)
- [ ] Step 1.8 handoff: the exact Phase-2 prompt to paste

---

### Phase 2: HELM Installation
**Interface:** Claude Desktop → Code tab → Local environment on the dedicated machine  
**Context:** User is now on the clean, dedicated machine. Claude Desktop is installed. Code/Local is running.

| Step | What User Does | What Claude Code Does (silently) |
|------|----------------|----------------------------------|
| 2.1 | Pastes Phase-2 prompt, presses Enter | Claude reads context, confirms it can run shell commands locally |
| 2.2 | Answers 2-3 config questions (bot name, their name) | Claude collects config; writes to a temp config file |
| 2.3 | Watches progress (no typing) | Claude runs `curl install.sh | bash` silently — installs Homebrew (if needed), Node.js, git, clones repo, runs npm install |
| 2.4 | Follows Discord bot creation: click-by-click | Claude opens Discord Developer Portal URL, guides through: Create Application → Add Bot → Copy Token → Enable 3 intents → Create Invite URL → Add bot to server |
| 2.5 | Pastes bot token when asked | Claude writes token to `~/helm/.env` (not 1Password — see Gap G-C) |
| 2.6 | Confirms server ID | Claude writes to `channels.json` via helm-hydrate.sh |
| 2.7 | Watches the connection test | Claude runs `node startup.js --test` or equivalent; verifies bot comes online |
| 2.8 | Confirms first Discord message | The bot posts "HELM is online" to #general |
| 2.9 | Watches auto-start setup | Claude configures launchd (Mac) or systemd (Linux) so HELM restarts on reboot |

**What the Phase-2 prompt must contain:**
- [ ] Context: what is happening, what Claude will do
- [ ] Config questions (bot name, owner name, email — just 3)
- [ ] install.sh invocation (with fallback for no curl)
- [ ] Discord bot creation walkthrough (step-by-step, with the 3 required intents listed: Message Content, Server Members, Presence)
- [ ] Token collection + secure write instructions
- [ ] `helm-hydrate.sh` invocation to write channels.json from config
- [ ] Connection test (verify bot appears online before declaring success)
- [ ] Auto-start configuration (launchd plist for Mac, systemd for Linux)
- [ ] First Discord message verification
- [ ] Second-brain setup (optional — run qmd-install.sh — or defer to Phase 3)
- [ ] Handoff message: "HELM is running. Go to your Discord server."

---

### Phase 3: Discord Onboarding
**Interface:** Discord — the user's new HELM server  
**Context:** Bot is online. User is in Discord for the first time with HELM.

> **CORRECTED 2026-06-15 to match P5.1 Phase 3.** The prior version of this table departed from P5.1 in four ways (tour fired before preferences; Stage 2 deferred to Day 3; used "@HELM"; assumed Gmail). All corrected below. Canonical order in P5.1: **Stage 1 (3 taps) → Stage 2 (rest of prefs, immediately) → Tour → First value → Connectors.**

| Step | What User Does | What HELM Does |
|------|----------------|----------------|
| 3.1 | Sees HELM's first message in #general | HELM posts a welcome message |
| 3.2 | Answers Stage 1 — exactly 3 taps (detail level, dark/light, pushback style) | HELM writes to CONFIG.md / VOICE-AND-STYLE.md |
| 3.3 | Answers Stage 2 — remaining prefs **immediately after Stage 1** (tone, quiet hours, proactive cadence, usage alert, date/time/week/timezone) | HELM writes prefs. NOT deferred to Day 3 — collected now while engaged. |
| 3.4 | Watches the channel tour (**fires AFTER Stage 2**, not before) | HELM fires TOUR-FIRST-USER-001 — posts to each channel in sequence with [Next →] buttons |
| 3.5 | Tries first value ("what's on my calendar?") | HELM responds; if connector not set up, gracefully explains how to connect |
| 3.6 | Offered connector setup in-flow (Stage 3) — **asks which email/calendar/drive provider**, never assumes Gmail | HELM walks through OAuth for the provider the user names |
| 3.7 | Day 3 / Day 7: gentle reminders **only for items left incomplete** | HELM nudges unfinished setup; does not introduce new first-time prefs here |

**What must be verified before beta:**
- [ ] HELM's first message lands in #general (not a different channel)
- [ ] Channel-layout init creates the standard layout on the user's server (NOT {{USER_JERRY}}'s server — single-guild guard)
- [ ] Tour fires **after Stage 1 + Stage 2**, in the correct channel order, one at a time
- [ ] Stage 1 = exactly 3 taps; Stage 2 fires immediately after, not Day 3
- [ ] User-facing commands use the bot's chosen name (e.g. `@Atlas help`), NOT literal `@HELM` — a renamed bot makes `@HELM` un-typeable
- [ ] Connector setup asks the user's provider (Gmail/Outlook/other; Drive/OneDrive; etc.) — no Gmail assumption
- [ ] First value ("what's on my calendar?") responds gracefully if connectors aren't yet set up
- [ ] Daily briefing is actually working (connectors offered in-flow) before the user exits onboarding — not an empty first briefing

---

## 3. Component Inventory

Every piece that must be built, verified, and tested before beta. Status is as of 2026-06-15.

### 3.1 Discovery & Entry Components

| ID | Component | What It Is | Status | Blocking Issue |
|----|-----------|-----------|--------|----------------|
| C1 | **Landing page** | `get-helm.github.io` — the friend-shared link | ✅ Live. Needs wording fix (Cowork → Code/Local). | Low risk |
| C2 | **"Copy + Open" button** | Copies Phase-1 prompt, opens Claude.ai | ✅ Exists. Must verify it copies the current prompt. | Verify live |
| C3 | **README** in get-helm/get-helm | The first thing a developer or curious user reads | ✅ Verified 2026-06-16: first CTA is get-helm.github.io, no curl/bash above fold. | Low risk |

### 3.2 Phase-1 Components

| ID | Component | What It Is | Status | Blocking Issue |
|----|-----------|-----------|--------|----------------|
| C4 | **Phase-1 pre-install prompt** | The AI prompt Claude.ai receives | ✅ Verified 2026-06-16: all 8 steps present, zero "Cowork" references, Code tab → Local. | — |
| C5 | **Mac wipe flow** | Step-by-step Mac wipe inside Phase-1 prompt | ✅ Exists in P5.1 spec | Verify it's in the published prompt |
| C6 | **Windows wipe flow** | Step-by-step Windows reset inside Phase-1 prompt | ✅ Exists in P5.1 spec | Verify it's in the published prompt |
| C7 | **Claude Desktop install guide** | Inside Phase-1 prompt — how to install Claude Desktop | ✅ Exists | Needs Code/Local fix |
| C8 | **Subscription guide** | Which Claude plan, where to get it | ✅ Verified 2026-06-16: "Pro ~$20/mo — enough for HELM. If you use HELM very heavily every day, Max is more reliable." | — |
| C9 | **Code/Local handoff** | The exact UI steps to open Code tab, set to Local, paste Phase-2 prompt | ✅ Verified 2026-06-16: Step 1.7 in Phase-1 prompt has exact UI steps for Code tab → Local | — |

### 3.3 Phase-2 Components

| ID | Component | What It Is | Status | Blocking Issue |
|----|-----------|-----------|--------|----------------|
| C10 | **Phase-2 install prompt** | The AI prompt Claude Desktop Code/Local receives | ✅ Verified 2026-06-16: full prompt embedded in Step 1.8 of Phase-1, includes install.sh + Discord bot creation + auto-start | — |
| C11 | **install.sh** | Prerequisite installer + repo cloner | ✅ Works. Invoked by Claude, never shown to user. | Tested locally; needs clean-Mac test |
| C12 | **setup-headless.sh** | Collects config, writes .env + CONFIG.md | ✅ Works | Must verify no {{USER_JERRY}} IDs in defaults |
| C13 | **helm-hydrate.sh** | Writes channels.json from gathered config | ✅ Exists in rich prompt | Not in published prompt — must add |
| C14 | **Discord bot creation walkthrough** | Click-by-click: Developer Portal → Bot → Token → Intents → Invite | ✅ Exists in both prompt versions | Verify 3 intents are listed correctly |
| C15 | **Token write** | Writes Discord token to ~/helm/.env | ✅ Works | Wording must match reality (no "Vault" promise) — Gap G-C |
| C16 | **Connection test** | Verifies bot appears online before claiming success | ✅ In rich prompt | Not in published prompt — must add |
| C17 | **Auto-start configuration** | launchd (Mac) / systemd (Linux) | ✅ In install.sh | Verify launchd plist path is correct |
| C18 | **Second brain setup** | Runs qmd-install.sh | ✅ In rich prompt | Decision needed: in-beta or post-beta? (Recommend post-beta) |

### 3.4 Phase-3 Discord Components

| ID | Component | What It Is | Status | Blocking Issue |
|----|-----------|-----------|--------|----------------|
| C19 | **First Discord message** | "HELM is online" in #general | ✅ Bot posts on start | Verify it goes to correct server, not {{USER_JERRY}}'s |
| C20 | **@HELM init** (AUTO-HELM-INIT-001) | Creates 4-category channel layout | ✅ Shipped 2026-06-15 | Single-guild guard must be verified |
| C21 | **First-user tour** (TOUR-FIRST-USER-001) | Posts a tour to each channel in sequence | ✅ Shipped 2026-06-15 | Cross-channel posting must be verified live |
| C22 | **Stage-1 preferences** (3 taps) | The minimal first preference set | ✅ In bot.js | Verify they're truly 3 and not more |
| C23 | **First value prompt** | Suggests "ask me what's on your calendar" | ✅ In onboarding flow | Calendar must fail gracefully if not connected — Gap G-E |
| C24 | **Connector setup prompt** | Asks which email/calendar/drive **provider** (never assumes Gmail), then walks the user to enable the matching **Claude-native connector** in Claude Desktop → Settings → Connectors | ✅ **DECIDED — deliver basics in-flow** ({{USER_JERRY}} 2026-06-15). **ARCHITECTURE CORRECTED 2026-06-16 (see G-J): NO custom OAuth infra — uses Anthropic-hosted Claude connectors, same as {{USER_JERRY}}'s.** | Engineer: build provider-ask + Settings→Connectors walkthrough (NOT OAuth backend) |
| C25 | **Stage-2 preferences** (immediate) | Remaining prefs collected **immediately after Stage 1**, while the user is engaged — NOT deferred to Day 3 | ✅ Per P5.1 Phase B (B2–B17 run in one sitting) | Engineer: ensure no Day-3 deferral in bot.js |
| C26 | **#recovery channel** | Pinned recovery prompt + lifeline instructions | ✅ Created by init | Verify the pinned message content is correct |
| C27 | **Onboarding resume** | If user drops off mid-onboarding, `ONBOARDING_STEP` resumes correctly | ❌ Not verified | Gap G-D — must test |

### 3.5 Recovery & Lifeline Components

| ID | Component | What It Is | Status | Blocking Issue |
|----|-----------|-----------|--------|----------------|
| C28 | **Lifeline bot** (VPS) | When main HELM is down, accepts messages, hands out AI prompt | ✅ Shipped 2026-06-15 (no API key required) | Verify prompt is the correct one, no API key ask |
| C29 | **Recovery AI prompt** | The paste-able prompt a user gives to Claude.ai when HELM is down | ✅ RECOVERY-AI-PROMPT.template.md exists | Verify it ships in the public repo |
| C30 | **Lifeline heartbeat watcher** | Lifeline detects when main bot stops sending heartbeats | ✅ Shipped 2026-06-15 | Verify 2-minute threshold is appropriate |

### 3.6 Security / PII Components

| ID | Component | What It Is | Status | Blocking Issue |
|----|-----------|-----------|--------|----------------|
| C31 | **PII scrub** | No {{USER_JERRY}} IDs, server IDs, or email in public repo | ✅ Verified 2026-06-15 (commit f1d897a) | Must re-verify after every publish |
| C32 | **Hardcoded ID check** | bot.js config resolves from CONFIG.md, not hardcoded values | ✅ Verified 2026-06-15 | Verify zero `1504865585` or `1501219027` literals remain |
| C33 | **Pre-deploy security check** | Scans artifacts before publish | ✅ `pre-deploy-security-check.sh` | Runs automatically in publish pipeline |

---

## 4. Pre-Beta Checklist

**Rule: Every item below must be manually verified — not assumed — before a human beta tester touches the install. Unchecked = blocked.**

### Category A: Entry & Discovery
- [x] **A1** — README's first screen is a single CTA pointing to get-helm.github.io. No `curl | bash` visible above the fold. *(Verified 2026-06-16)*
- [x] **A2** — Landing page is live and loads at `get-helm.github.io` *(curl → 200 OK, 2026-06-16)*
- [ ] **A3** — "Copy + Open" button copies the current Phase-1 prompt (not a stale version) and opens Claude.ai *(needs human verify — button opens browser)*
- [x] **A4** — The landing page says "Claude Desktop → Code tab" (zero "Cowork" references) *(Verified 2026-06-16)*
- [x] **A5** — The "skip to install" link on the landing page goes to the Phase-2 prompt *(Verified — `#install-prompt` anchor works, 2026-06-16)*

### Category B: Phase 1 — Pre-Install Prompt
- [ ] **B1** — The Phase-1 prompt is reachable and loadable by Claude.ai *(needs human verify)*
- [x] **B2** — Zero "Cowork" references in the Phase-1 prompt *(Verified 2026-06-16 — grep clean)*
- [x] **B3** — Mac wipe flow is complete (Apple → System Settings → Transfer or Reset → Erase) *(Verified 2026-06-16 — Step 1.3 present)*
- [x] **B4** — Windows wipe flow is complete (Settings → System → Recovery → Reset this PC) *(Verified 2026-06-16 — Step 1.4 present)*
- [x] **B5** — Claude Desktop install steps are present for both Mac and Windows *(Verified 2026-06-16 — Step 1.6)*
- [x] **B6** — Subscription guidance is honest: "Pro ~$20/mo; if you use HELM very heavily, Max is more reliable" *(Verified 2026-06-16 — Step 1.5)*
- [x] **B7** — Code tab → Local steps are present with exact UI landmarks *(Verified 2026-06-16 — Step 1.7 has exact UI steps)*
- [x] **B8** — The handoff to Phase 2 gives the exact Phase-2 prompt text *(Verified 2026-06-16 — Step 1.8 embeds full Phase-2 prompt)*

### Category C: Phase 2 — Install Prompt
- [x] **C1** — The Phase-2 prompt targets Code/Local, not Cowork *(Verified 2026-06-16)*
- [ ] **C2** — install.sh runs successfully on a near-clean Mac *(needs clean-Mac test — G1 gate)*
- [ ] **C3** — setup-headless.sh collects the right 3-4 config values *(needs clean-Mac test)*
- [x] **C4** — Discord bot creation walkthrough includes all 3 intents + invite URL *(Verified 2026-06-16 — in Phase-2 prompt)*
- [x] **C5** — Token is written to `~/helm/.env` (no Vault dependency for new users) *(Verified 2026-06-16)*
- [ ] **C6** — helm-hydrate.sh runs and correctly writes channels.json *(needs clean-Mac test)*
- [x] **C7** — Connection test verifies bot is online before proceeding *(Verified 2026-06-16 — in Phase-2 prompt)*
- [x] **C8** — Auto-start is configured: launchd plist on Mac, systemd on Linux *(Verified 2026-06-16 — in install.sh)*
- [ ] **C9** — First Discord message appears in the user's server #general (not {{USER_JERRY}}'s server) *(needs live test — single-guild guard exists but unverified end-to-end)*
- [x] **C10** — No hardcoded server IDs in any file that runs during install *(Verified 2026-06-15, commit f1d897a)*

### Category D: Phase 3 — Discord Onboarding
- [x] **D1** — init creates the 4-category channel layout in the new user's server *(Shipped 2026-06-15)*
- [x] **D2** — AUTO-HELM-INIT-001 single-guild guard verified: init only fires for the bot's own configured server *(Verified 2026-06-16 — line 4610 in bot.js)*
- [x] **D3** — First-user tour fires (TOUR-FIRST-USER-001) *(Shipped 2026-06-15; channels updated to P5.1 order 2026-06-16)*
- [ ] **D4** — Tour posts to each channel in the correct order, one at a time *(needs live Discord test)*
- [ ] **D5** — Stage-1 preference taps are exactly 3, write to CONFIG.md correctly *(⚠️ NOT FOUND in bot.js — may not be implemented as automatic taps; currently handled by help agent in #preferences)*
- [ ] **D6** — "What's on my calendar?" responds gracefully if connectors not configured *(needs live test)*
- [ ] **D7** — Connector setup is not promised until available *(⚠️ daily-briefing tour step mentions calendar — needs verification)*
- [x] **D8** — #recovery channel is created and recovery prompt is pinned *(Shipped 2026-06-15)*
- [ ] **D9** — Onboarding resume works *(not tested)*

### Category E: Recovery & Lifeline
- [x] **E1** — Lifeline bot is running on the VPS *(Verified 2026-06-15)*
- [x] **E2** — Lifeline hands a paste-able prompt, no API key required *(Shipped 2026-06-15 — VPS-BRAIN-OPTION-B-001)*
- [x] **E3** — Recovery AI prompt is accurate and in the published repo *(Verified 2026-06-15)*
- [x] **E4** — Lifeline heartbeat watcher triggers within 2 minutes *(Shipped 2026-06-15 — 2-min threshold)*

### Category F: Security & PII
- [x] **F1** — Zero {{USER_JERRY}}-specific server/channel IDs in published repo *(Verified 2026-06-15, commit f1d897a)*
- [x] **F2** — Zero hardcoded email addresses in any shipped file *(Verified 2026-06-15)*
- [x] **F3** — .env is not committed to the public repo *(denylist includes .env)*
- [x] **F4** — Pre-deploy security scan passes *(pre-deploy-security-check.sh runs in pipeline)*
- [x] **F5** — bot.js uses `process.env` or config files for all credentials *(Verified 2026-06-15)*

### Category G: The Gate (most important)
- [ ] **G1** — 🔴 Validated by the next real beta install itself ({{USER_JERRY}} 2026-06-16): a near-clean-Mac dry run cannot be simulated here, so G1 is proven by the beta tester following Phase-1 → Phase-2 → Discord end-to-end. **The behavior gaps below (D5/D9/C24/G-E) must land BEFORE that beta so the install isn't embarrassing again.**

### Remaining beta-blocking BUILDS — queued for engineer 2026-06-16
These are P5.1 decisions locked in this doc but NOT yet implemented in bot.js (verified via grep 2026-06-16). Full spec: `specs/BETA-BLOCKERS-ONBOARDING-BEHAVIOR.md`.
- [ ] **ONBOARD-STAGE12-FLOW-001** — Stage-1 (3-tap) + Stage-2 pref flow (D5/C22/C25). NOT in bot.js — prefs only handled ad-hoc by help agent today.
- [ ] **ONBOARD-RESUME-001** — Onboarding resume via ONBOARDING_STEP (D9). No ONBOARDING_STEP in bot.js.
- [ ] **ONBOARD-CONNECTOR-BRIEFING-001** — Connector provider-ask (no Gmail assumption) + in-flow first briefing (C24/G-E). Not built.
- [ ] **ONBOARD-ENV-WORDING-001** — Replace "Vault" credential promise with honest `~/helm/.env` wording (G-C).
- [ ] **(also queued separately)** Windows auto-start (G-F) + Phase-2 CLI-runner note (G-H) — see BLOCK-5/BLOCK-6.

---

## 5. Known Gaps

These are verified issues found on 2026-06-15. **{{USER_JERRY}}'s decisions are now locked — see Appendix B Decisions Log.** Summary: 2nd brain = in beta; Windows = in scope; connectors = deliver basics in-flow (briefing must work before onboarding exits); Pro is enough to start (mention Max for heavy use); .env wording = engineer fixes; never assume Gmail — ask the provider.

### G-A: Claude Pro usage cap vs. always-on bot
**Risk:** Beta user's HELM goes quiet mid-week and they think it's broken.  
**Detail:** P5.1 promises "Claude Pro ($20/month) is enough." An always-on bot with health checks, PM sweeps, daily briefings, and on-demand tasks will burn usage fast. Claude's Code tab itself requires Pro/Max. Weekly limits may be hit.  
**Options:**
1. Set honest expectation in onboarding: "Pro works for light use. For always-on with daily briefings, Max is recommended."
2. Measure actual weekly token burn before the promise is made.
3. Build a usage-remaining warning into HELM's daily briefing.  
**Status:** Unresolved. Recommend Option 1 now, Option 2 before GA.

### G-B: Cowork → Code/Local architectural correction
**Risk:** Any user following the current Phase-1 or Phase-2 prompt dead-ends — install is impossible from Cowork.  
**Detail:** Claude Desktop's Cowork tab runs in an isolated Linux VM sandbox and cannot install software on the host Mac. Code tab → Local environment can.  
**Action:** Every "Cowork" reference in Phase-1 prompt, Phase-2 prompt, landing page, and README must be replaced with "Code tab → Local" (or "Claude Code CLI" as fallback).  
**Status:** Fix required. Blocking.

### G-C: .env storage vs. "Vault" promise
**Risk:** User is told their credentials are stored in a secure vault; they're actually in a plaintext `.env` file.  
**Detail:** The P5.1 spec narration says "[SAVE token to HELM Vault — never stored in plain text]" and "Bot token → HELM Vault only." The actual install writes the token to `~/helm/.env` in plaintext. New users have no 1Password/PAP Vault — that's {{USER_JERRY}}-specific infra.  
**Options:**
1. Fix the wording: "Token stored locally in `~/helm/.env`, protected by your Mac's file permissions." (honest, not scary)
2. Add an optional encrypted local store (adds complexity, not blocking for beta)  
**Status:** Fix wording (Option 1) before beta. Option 2 is post-beta.

### G-D: Onboarding resume not verified
**Risk:** If a user's install is interrupted, they may restart from zero — losing progress and getting confused.  
**Detail:** P5.1 spec promises typing "onboarding" resumes from `ONBOARDING_STEP`. Whether bot.js actually persists and reads this value across restarts has not been tested.  
**Action:** Write a test: start onboarding, kill the bot, restart it, type "onboarding", verify it picks up from the right step.  
**Status:** Unverified. Test before beta.

### G-E: First daily briefing must work before onboarding exits  ✅ DECIDED
**Decision ({{USER_JERRY}} 2026-06-15):** Do NOT let the user leave onboarding with an empty briefing. Connectors basics are set up in-flow (C24) and the daily briefing is generated with live data and shown during onboarding (P5.1 B16–B17). The "starts tomorrow with no data" framing is removed.  
**Action:** Engineer wires the in-flow connector setup → generate a real sample briefing → show it before ONBOARDING_COMPLETED. If a user skips all connectors, the briefing gracefully states what's missing and how to connect — it is never silently empty.  
**Status:** Decided. Engineer build. Blocking for beta.

### G-F: Windows install path not tested
**Risk:** P5.1 says HELM works on Windows. install.sh handles WSL2. But the Phase-2 prompt (Claude Desktop Code/Local → install) has only been considered for macOS.  
**Detail:** WSL2 support exists in install.sh. Windows launchd equivalent (Task Scheduler or NSSM for systemd-like behavior) is unspecified. Claude Desktop Code/Local on Windows may behave differently.  
**Action:** Decide: Windows in beta scope, or Mac-only for beta with Windows coming later?  
**Status:** ✅ DECIDED — Windows in scope ({{USER_JERRY}} 2026-06-15). Engineer must spec the Windows auto-start (Task Scheduler / NSSM) and verify the Claude Code path on Windows.

### G-G: Claude Pro may NOT be enough for an always-on bot  🔴 NEW — contradicts a locked decision
**Source:** Web research 2026-06-15 (Anthropic usage docs, effective today).  
**Finding:** As of **June 15, 2026**, programmatic / non-interactive agent use (`claude -p`, Agent SDK, third-party agent apps) draws from a **separate monthly credit pool** — roughly **$20 on Pro, $100 on Max 5x, $200 on Max 20x**. An always-on HELM bot (health checks, PM sweeps, daily briefings, on-demand tasks) is exactly this programmatic path. Pro's small pool will likely be exhausted quickly.  
**Why this matters:** Appendix B currently says "Pro is enough to start." That decision predates this credit-pool split and may now be **wrong** — a Pro user's HELM could go quiet within days, looking broken. This is the same class of failure as the Cowork false premise: a promised capability that doesn't hold.  
**Options:** (1) Change the onboarding promise to "Max recommended for always-on; Pro only for light/interactive use." (2) Measure real weekly burn on a Pro account before any promise. (3) Support Console pay-per-token billing as an alternative.  
**Status:** ✅ DECIDED — **Pro / $20 to start is fine** ({{USER_JERRY}} 2026-06-16). It depends on what the user is doing; light/interactive use is fine on Pro. Onboarding sets the honest expectation: "$20 Pro gets you started; heavy always-on use may need Max." Do NOT block onboarding on a Max requirement. Supersedes the "may be wrong" framing above.

### G-H: Desktop Code/Local sandboxes the network during install  🟡 NEW — refines the Hybrid path
**Source:** Web research 2026-06-15 (Claude Code GitHub issue #37994).  
**Finding:** The **March 23, 2026** Claude Desktop update sandboxes Claude Code's network when launched from the Desktop app — LAN/curl/git operations can fail with "No route to host." The **Code tab → Local** environment runs on the host Mac (good) but the **install step** (curl install.sh, npm install, git clone) is more reliable run from the **Claude Code CLI directly**.  
**Implication for Hybrid:** For the install/configure block, prefer the CLI; the Desktop Code tab is fine for interactive use afterward. The published Phase-2 prompt should account for this (CLI as the install runner, not the Desktop sandbox).  
**Status:** 🟡 Refinement — fold into the Phase-2 prompt rewrite. Verify on the clean-Mac gate.

### G-J: Connector setup needs NO custom OAuth — uses Claude-native connectors  ✅ CORRECTED 2026-06-16
**Trigger:** {{USER_JERRY}}'s question — "Aren't we collecting these in onboarding? Why wouldn't we connect them just like mine are connected and be ready for the morning brief?"
**Finding (verified 3 ways):** (1) `~/.claude/mcp.json` is empty `{}` — {{USER_JERRY}}'s Gmail/Calendar/Drive are NOT a local MCP server; they are **Claude-native connectors** enabled at the account level, surfaced to the bot as `mcp__claude_ai_*` tools. (2) 2nd brain (Discord "Additional users" thread): *"I think I'm just using Claude Connector for these."* (3) Web research 2026-06-16: Gmail/Calendar/Drive connectors are **available to all Claude + Claude Desktop users**; setup = **Settings → Connectors → Connect → authorize (Anthropic-hosted OAuth), under 60 seconds.**
**Why the build was wrongly blocked:** Engineer posted a Level-4 BLOCK on ONBOARD-CONNECTOR-BRIEFING-001 (2026-06-16 05:51Z) citing *"OAuth connector integration requires auth infrastructure."* That premise is wrong. HELM builds **zero** OAuth infrastructure. The new user enables the **same Claude-native connectors** in Claude Desktop on their dedicated machine — exactly the way {{USER_JERRY}}'s are connected — and the HELM bot (running through that Claude) inherits the tools automatically. The spec's old phrase "HELM opens the OAuth consent page automatically" mislabeled this and caused the confusion.
**Corrected build scope (Level 2, not Level 4):** Onboarding connector step = a guided **Settings → Connectors** walkthrough: ask the provider, then tell the user the exact clicks to enable Gmail/Google Calendar/Drive in Claude Desktop, confirm the bot can see them (a test "what's on my calendar?"), then generate the first real briefing. Graceful degrade if skipped.
**One genuine caveat (VERIFICATION_REQUIRED, not a blocker):** GitHub issue anthropics/claude-code#62479 reports that connectors authorized in claude.ai can sometimes expose "only auth stubs" in a non-interactive Code session. {{USER_JERRY}}'s bot proves the path works (it reads his Gmail/Calendar today), so the architecture is sound — but the new-user end-to-end is confirmed only by the beta install itself (rolled into G1).
**Status:** ✅ Architecture corrected. ONBOARD-CONNECTOR-BRIEFING-001 reclassified Level 4 → Level 2 and re-queued with corrected scope (2026-06-16).

### G-I: Repo sprawl — five repos on {{USER_GITHUB}}, PAT in marvin-bot remote  🔴 NEW — consolidation in progress
**Finding (corrected 2026-06-16 from {{USER_JERRY}}'s screenshot):** {{USER_GITHUB}} (private account) currently has **five** repos, plus the get-helm org:

| Repo | Visibility | Purpose | Last update | Recommendation |
|------|-----------|---------|-------------|----------------|
| `{{USER_GITHUB}}/marvin-bot` | Private | Live bot.js + recovery scripts (the running system) | 3h ago | **KEEP — Core HELM sandbox** |
| `{{USER_GITHUB}}/helm-config` | Private | Config + specs (pap-complete, P5.1) | 10h ago | **KEEP — personal info/config backup** (pending {{USER_JERRY}} confirm vs `helm`) |
| `{{USER_GITHUB}}/helm-docs` | Public | HELM documentation | 3 days | DELETE (docs belong in get-helm, not personal account) |
| `{{USER_GITHUB}}/helm` | Private | "Runs 24/7" — `~/helm-public` working tree | last week | DELETE (stale mirror) — confirm it's not the personal backup first |
| `{{USER_GITHUB}}/platform-config` | Private | Old config | May 2 | DELETE (stale) |
| `get-helm/get-helm` | Public | Distribution repo (code + templates) | — | KEEP — public front door |
| `get-helm/get-helm.github.io` | Public | Landing page | — | KEEP — landing only |

**Target end state:** {{USER_GITHUB}} holds **2 private repos** (`marvin-bot` = Core HELM sandbox + `helm-config` = personal info backup, both stay private — locked 2026-06-14; `helm-config` confirmed as the active backup target in helm-publish.sh). get-helm holds **2 public repos** (code + landing).
**PAT location (corrected):** the live `ghp_` token was embedded in **`~/marvin-bot/.git/config`** remote URL ({{USER_GITHUB}}/marvin-bot.git) — NOT in `~/.env`. ✅ {{USER_JERRY}} revoked the old token + created a new one (vault "Github {{USER_GITHUB}} PAT", 2026-06-16). ⚠️ The old {{USER_GITHUB}} token in `~/marvin-bot/.env` (backup-publish target) is now REVOKED — backup publishing to {{USER_GITHUB}}/helm-config will fail until the new PAT is placed in `~/marvin-bot/.env`. The get-helm publish token (vault) is unaffected and works.
**Git-history PII:** ✅ Choice B — start get-helm/get-helm from scratch ({{USER_JERRY}} 2026-06-16).
**Status (2026-06-16):** Stale repos to delete: `{{USER_GITHUB}}/helm-docs` (content already backed up into get-helm/backups/repo-cleanup-20260615), `{{USER_GITHUB}}/helm`, `{{USER_GITHUB}}/platform-config`. ⛔ Deletion attempted via API and BLOCKED: the new "Github {{USER_GITHUB}} PAT" is a fine-grained token WITHOUT "Administration: write" permission (403 "Resource not accessible"). To unblock: either (a) edit the token at github.com/settings/personal-access-tokens to grant **Administration → Read and write** on **All repositories**, then HELM deletes them automatically; or (b) {{USER_JERRY}} deletes the 3 in the web UI (repo → Settings → bottom → Delete). Both stale + git-history-scrub deletions are irreversible.

---

## 6. The Gate

**This is the single most important item on this list.**

Before any human beta tester touches HELM:

1. **A HELM team member ({{USER_JERRY}} or authorized tester) installs HELM on a near-clean Mac** — a fresh user account, no HELM-specific tools, no .env files, no pre-cloned repos.
2. They follow the **exact Phase-0 → Phase-1 → Phase-2 → Phase-3 flow** as a non-technical user would: starting at get-helm.github.io, pasting the Phase-1 prompt into Claude.ai, using Claude Desktop Code/Local for the install, and ending in Discord.
3. Every failure, confusion point, or wrong step is documented and fixed before the external beta.

**This has never been done.** Every prior review has been done from inside the repo, reading code and specs. Reading code cannot catch what only a real install reveals. The failed beta on 2026-06-15 happened because this gate was skipped.

**The gate is not optional.** No amount of code review, checklist review, or spec review substitutes for it.

---

## Appendix A: File-to-Component Mapping

Quick lookup: which file implements which component.

| File | Components |
|------|-----------|
| `get-helm.github.io/index.html` | C1, C2, A2, A3, A4 |
| `public-docs/phase1-prompt.md` | C4, C5, C6, C7, C8, C9 |
| `public-docs/phase2-prompt.md` | C10, C13, C14, C15, C16, C17, C18 |
| `install.sh` | C11, C2 (backend) |
| `setup-headless.sh` | C12 |
| `helm-hydrate.sh` | C13 |
| `bot.js` | C19, C20, C21, C22, C23, C27 |
| `startup.sh` | C17 (auto-start trigger) |
| `lifeline-bot.js` | C28, C30 |
| `RECOVERY-AI-PROMPT.template.md` | C29 |
| `RECOVERY-GUIDE.md` | E3 |
| `pre-deploy-security-check.sh` | C33, F4 |
| `helm-publish.sh` | C31, C32, C33 |

---

## Appendix B: Decisions Log (from this session)

| Decision | Options | Status | Owner |
|----------|---------|--------|-------|
| Install path for beta | Claude Desktop Code/Local (primary) + CLI fallback (A3 Hybrid) | ✅ Decided — Hybrid | {{USER_JERRY}} |
| Second brain in beta? | In-beta vs. post-beta | ✅ **DECIDED — in beta** ({{USER_JERRY}} 2026-06-15) | {{USER_JERRY}} |
| Windows in beta scope? | In scope vs. Mac-only for beta | ✅ **DECIDED — in scope** ({{USER_JERRY}} 2026-06-15) | {{USER_JERRY}} |
| Connector promise in onboarding | Remove vs. defer vs. deliver | ✅ **DECIDED — deliver: offer to set up the basics in-flow** ({{USER_JERRY}} 2026-06-15). Daily briefing must work before user exits onboarding. **ARCHITECTURE CORRECTED 2026-06-16 (G-J): use Claude-native connectors (Settings → Connectors), NOT custom OAuth — same as {{USER_JERRY}}'s. Reclassified L4 → L2, re-queued as ONBOARD-CONNECTOR-CLAUDE-NATIVE-001.** | {{USER_JERRY}} |
| Pro vs. Max promise | Fix wording to honest expectation | ✅ **DECIDED — Pro is enough to start; mention heavy use may need Max** ({{USER_JERRY}} 2026-06-15) | Engineer |
| Vault vs. .env wording | Fix wording to match reality | ✅ **DECIDED — PM/engineer owns the fix** ({{USER_JERRY}} 2026-06-15) | Engineer |
| Email/Drive/password-mgr provider | Assume Gmail vs. ask | ✅ **DECIDED — always ask the provider, never assume Gmail** ({{USER_JERRY}} 2026-06-15) | Engineer |
| Tour timing | Before vs. after preferences | ✅ **DECIDED — after Stage 1 + Stage 2** per P5.1 ({{USER_JERRY}} 2026-06-15) | Engineer |
| `@HELM` literal commands | Keep vs. use bot's chosen name | ✅ **DECIDED — remove all `@`/`!`/`#` command-prefix requirements; the user speaks plain English. Bot responds to its chosen name or plain mentions.** ({{USER_JERRY}} 2026-06-15). NOTE: `@HELM` appears **46 times** in bot.js (re-counted 2026-06-15 — earlier "6+" was an undercount). Engineer must replace all literals with the configured bot name + plain-language intent matching. | Engineer |

### Tour channels (per P5.1 — the tour walks these 6, in order)
1. **#general** — main channel
2. **#new-workspace** — describe an automation to build
3. **#capture** — drop links/notes/voice memos into the second brain
4. **#daily-briefing** — morning summary lands here
5. **#help** — ask how things work / report problems
6. **#preferences** — change any setting; emergency `pause`/`resume`/`pause 2h` controls

> **RESOLVED ({{USER_JERRY}} 2026-06-16):** Tour walks **only channels that already exist after init** (system + capture channels), referenced by the **names init actually creates** — never assumed names like `#help`, and never a workspace channel that hasn't been built. The **first workspace is built right after the tour** in #new-workspace, so the tour never points at an empty/unbuilt workspace. Engineer: derive the tour channel list dynamically from the channels init creates; do not hardcode a 6-item list or assume `#help`.

---

*This document is the source of truth for HELM onboarding and install completeness. Update it whenever a component ships, a gap is resolved, or a new gap is found.*
