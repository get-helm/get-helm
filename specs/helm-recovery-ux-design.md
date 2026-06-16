# HELM Recovery UX Design
## Design Phase — Not yet built

**Goal:** Any non-techie HELM user recovers a dead bot without touching a terminal.

**Channel:** #troubleshooting (consolidates #recovery)

---

## User Journey (target state)

1. Bot is unresponsive → user opens #troubleshooting or goes to recovery URL
2. Pastes AI prompt into Claude.ai → gets guided triage
3. Triage routes to one of 3 non-terminal actions:
   - Click a button on the VPS recovery web page
   - Power-cycle the clean machine (physically or via smart plug)
   - Open "Fix HELM" Claude Code shortcut on the clean machine
4. Bot comes back. Done.

---

## What Users Can Do Without a Terminal (today, zero build)

- Restart the clean machine by pressing the power button
- Open Claude Code on the clean machine and describe the problem
- Check https://discordstatus.com for platform outages

---

## Infrastructure Gaps (what we need to build)

### 1. VPS Recovery Web Page
**What:** Simple password-protected web page served by VPS, accessible even when clean machine is dark.
**URL pattern:** `recovery.[helmapp.com]` or per-user subdomain
**Buttons:**
- "Restart the bot" — VPS SSHes into clean machine, restarts bot process
- "Roll back to yesterday" — reverts bot to last known-good commit
- "Test connection" — pings clean machine, shows green/red status
- "Power cycle (smart plug)" — only shown if smart plug configured at install
**Mobile-first.** No code. No terminal.

### 2. Smart Plug Integration at Install
**What:** HELM install wizard asks if user has a smart plug. If yes, captures credentials. Adds power-cycle button to recovery page.
**Why:** Lets user power-cycle clean machine remotely with one click. Most common fix for a frozen machine.

### 3. Per-User Recovery Prompt at Install
**What:** HELM install wizard captures 5 facts (machine type, VPS IP, Discord server ID, smart plug type, support email). Generates personalized `RECOVERY-AI-PROMPT.md` from template.
**Template lives in:** `pap-config` repo (`RECOVERY-AI-PROMPT-TEMPLATE.md`)
**User copy lives in:** their workspace root (`RECOVERY-AI-PROMPT.md`)
**Updated by:** Steward weekly (bumps date, re-pushes to GitHub)

### 4. "Fix HELM" Claude Code Shortcut
**What:** At install, add a Claude Code project shortcut on the clean machine desktop pre-loaded with HELM context. User double-clicks it, Claude sees the logs and can restart processes.
**Why:** Claude Code is the terminal — user never opens a terminal directly. Claude does the work.
**Blocker:** Requires Claude Code to be installed at install time (currently not guaranteed).

---

## Recovery Hierarchy (non-techie)

| Step | Action | Requires |
|------|--------|----------|
| 1 | Check VPS recovery web page → click button | VPS recovery page (to build) |
| 2 | Restart clean machine physically | Physical access or smart plug |
| 3 | Open "Fix HELM" Claude Code shortcut | Claude Code installed at setup |
| 4 | Contact support | Nothing — always available |

---

## Install Wizard Questions (5 questions, captures config)

1. What type of clean machine? (Mac / Windows)
2. Do you have a VPS set up? (Yes / No)
3. Do you have a smart plug for the clean machine? (Yes / No — if yes, which type?)
4. What's your Discord server ID? (auto-filled if Claude Code is active)
5. Who should users contact if all recovery paths fail? (email or Discord handle)

---

## Per-User Customization Fields (in generated prompt)

```
{{machine_type}}     → "Mac mini" / "Windows PC"
{{clean_machine_ip}} → [captured at install or "not configured"]
{{discord_server_id}} → [captured at install]
{{vps_configured}}   → true / false
{{smart_plug_type}}  → "TP-Link Kasa" / "none"
{{recovery_url}}     → "recovery.helmapp.com/[user-id]" or "not configured"
{{support_contact}}  → set at install; OPTIONAL. Never defaults to a personal email. Blank = section omitted from generated prompt. (Privacy rule 2026-06-09: owner PII never ships in user-facing recovery content.)
{{bot_name}}         → "Marvin" (or user's chosen name)
```

---

## What This Replaces

- Current RECOVERY-AI-PROMPT.md → becomes a {{USER_JERRY}}-specific instance of the template
- #recovery channel → deleted; content moves to #troubleshooting
- Manual path instructions → replaced by VPS recovery page buttons

---

## Mutual Recovery: Clean Machine ↔ VPS Watchdog

The two nodes watch each other. Neither is the single point of failure.

### Clean Machine → VPS Monitoring

- Cron job every 5 min: checks HC.io API for VPS check status
- If HC.io reports VPS DOWN: posts to Discord #helm-status with context (once per outage, 1hr cooldown)
- "I'm back" notification fires when VPS returns UP
- HC.io email stays as silent backup — only fires if both machines are dark

### VPS Restart Options (for users with VPS)

When VPS goes dark, Mac Mini can't restart it via smart plug (VPS is remote).
Options (to be configured at onboarding, in priority order):
1. **Provider API restart** — DigitalOcean, Linode, Hostinger all have REST APIs. Mac Mini calls `POST /server/restart` with provider API key. Requires API key captured at onboarding.
2. **Provider web console URL** — saved at onboarding as `VPS_CONSOLE_URL`. Shown in Discord alert: "Click here to restart your VPS." User logs in and clicks restart.
3. **Alert only** — if no API key or console URL: alert fires, user handles manually.

**Onboarding capture for VPS restart:**
- VPS provider name (DigitalOcean / Linode / Hostinger / Other)
- Provider API key (read in vault as "VPS Provider API Key") — optional but recommended
- Provider console URL (save as bookmark)

**{{USER_JERRY}} (Hostinger):** Hostinger has a VPS management API. Queue for engineer to implement auto-restart via Hostinger API.

### VPS → Clean Machine Monitoring

- Clean machine sends heartbeat POST to VPS every 5 min
- VPS watchdog process checks for missed heartbeats
- If 2+ missed (10+ min): declares clean machine down
- Actions: (1) posts to Discord via webhook (VPS keeps its own bot token for this), (2) sends ntfy/email alert, (3) serves the recovery page prominently with "Your clean machine appears offline"
- Cannot restart clean machine remotely — smart plug integration is what makes this non-terminal for users

### Asymmetry (by design)

| | Clean machine can... | VPS can... |
|---|---|---|
| Restart the other | Yes (provider API) | No (physical machine) |
| Alert the user | Yes | Yes (webhook + out-of-band) |
| Serve recovery page | No (it may be dark) | Yes (always up) |
| Keep HELM running | No (bot lives here) | No (processing lives here) |

The VPS always stays up and serves the recovery page. The clean machine is the one
that fails physically. Smart plug closes the gap for clean machine power-cycle.

### What Gets Backed Up Where

| Data | Source | Backup | Cadence | Recovery |
|------|--------|--------|---------|----------|
| PostgreSQL DB (VPS) | VPS | Clean machine ~/backups/vps/ | Daily 2:30am | Restore from .sql.gz |
| HELM workspace files | Clean machine | GitHub repo | On commit | git pull |
| Bot config / secrets | Clean machine | 1Password vault | Manual | Re-enter at install |
| VPS app code /opt/ | VPS | GitHub repo | On commit | git pull |
| Off-device copy (gap) | Clean machine | Not yet built | — | Gap: if Mac mini + VPS fail same night |

**Gap closed (2026-06-05):** Off-device backup now uploads daily to private GitHub repo (platform-config/vps-backups/) after each successful pull. Token already available; no new credentials.

---

## What's Now Live (as of 2026-06-06)

| Component | Status | Notes |
|-----------|--------|-------|
| Daily pg_dump Mac Mini pull | ✅ Live | 7-day rotation |
| Off-device GitHub backup | ✅ Live | platform-config/vps-backups/, 7-day prune |
| VPS heartbeat server | ✅ Live | Outage detection + "I'm back" alert |
| Mac Mini "I'm back" on startup | ✅ Live | helm-back-online.sh via startup.sh |
| Outage → Discord alert | ✅ Live | Single post to Discord; ntfy removed |
| Backup restore test results | ✅ Live | Log-only (PM reviews); no user-facing Discord post |
| Recovery command poll (VPS→Mac) | ✅ Live | recovery-command-poll.sh, 60s launchd |
| VPS recovery web page ({{USER_JERRY}}) | ✅ Live | mission-control.{{USER_DOMAIN}}/recovery/ |
| Recovery API endpoints | ✅ Live | /api/pending-command, /api/recovery-command, /api/clear-command |
| External dead-man's-switch (Mac Mini) | ✅ Live | HC.io: pings every 5 min, grace 15 min — no false alarm emails |
| External dead-man's-switch (VPS) | ✅ Live | VPS pings HC.io separately every 5 min; grace 15 min |
| HC.io grace period tuned | ✅ Live | Both checks updated to 900s grace (was 300s — caused 30-sec false alarm emails) |
| Mac Mini → VPS monitoring cron | ✅ Live | vps-monitor-check.sh every 5 min; posts to Discord if VPS down 15+ min |
| Healthchecks.io vault | ✅ Live | API key + both ping URLs in PAP Vault (ping_url_helm_heartbeat, ping_url_vps_heartbeat) |
| HC.io → Discord webhook ({{USER_JERRY}}) | ⚠️ Partial | Discord webhook created for #helm-status; HC.io UI setup needed to wire it |
| Per-user recovery page | 🔴 Design ready | Each user's VPS serves page at http://[vps-ip]:8080/recovery — no custom domain |
| Install-time recovery auth | 🔴 Design ready | Random token generated at install, stored in 1Password as "HELM Recovery Token" |
| SSH VPS service auto-restart | ✅ Live | vps-service-restart.sh built + tested 2026-06-06; integrated into vps-monitor-check.sh |
| Smart plug | ❌ Removed | Replaced by Discord notification "power on your machine" — too complex for users |
| Install wizard | 🔴 Not built | Blocks per-user personalization; Windows/Linux support needed (not just Mac) |
| Secondary contact fallback | 🔴 Not built | SMS/email if Discord is dark; captured at onboarding |
| HC.io → Discord webhook (UI wire) | ⚠️ Engineer queued | HC.io UI setup needed — API doesn't support channel creation |
| UptimeRobot 2nd monitor | ⚠️ Engineer queued | Requires account creation (UI); free tier email only; Discord needs Pro ($7.50/mo) |
| Hostinger API auto-restart | ⚠️ Engineer queued | Need to generate API key from Hostinger UI; endpoint: developers.hostinger.com |
| Windows/Linux install paths | 🔴 Design ready | launchd → Task Scheduler (Win) or systemd (Linux); SSH server varies by OS |

---

## Per-User Recovery Page (non-{{USER_JERRY}} users)

**Problem:** `mission-control.{{USER_DOMAIN}}` is {{USER_JERRY}}'s domain. Other users have no website.

**Solution:** Each user's VPS serves its own recovery page.

- URL pattern: `http://[vps-ip]:8080/recovery`
- Captured at install as `RECOVERY_URL` in onboarding config
- Displayed in user's #troubleshooting channel pinned message
- No custom domain required — IP address works fine for recovery scenarios
- Page runs as part of the existing VPS heartbeat server (already deployed)

**Onboarding flow:**
1. Install wizard captures VPS IP
2. Generates `RECOVERY_URL=http://[vps-ip]:8080` 
3. Saves to HELM config + pins in #troubleshooting

---

## Install-Time Recovery Auth

**Problem:** Recovery page needs auth, but `{{USER_DOMAIN}} Site Auth` is {{USER_JERRY}}-specific.

**Solution:** Per-user recovery token generated at install.

1. Install wizard generates: `HELM_RECOVERY_TOKEN=$(openssl rand -hex 16)` (32-char hex)
2. Install wizard saves it to 1Password automatically: `op item create --title "HELM Recovery Access" --url "http://[vps-ip]:8080/recovery" password=[token]`
3. Set as env var on VPS in `/opt/helm/.env`
4. Recovery page: single password field. User opens 1Password → finds "HELM Recovery Access" → copies password → done.
5. The 1Password entry stores BOTH the URL and the token — user opens 1Password, finds "HELM Recovery Access", opens the URL, pastes the password. One item, everything in it.

**What the user sees during install:**
"Your recovery page is set up. I've saved it to 1Password as 'HELM Recovery Access'. If HELM ever stops working, open 1Password, find that entry, click the URL, and paste the password."

**Rotation:** User can rotate via recovery page itself (if logged in) or via install wizard re-run.

**No external dependency:** Token lives in user's 1Password + VPS env only.

---

## No-VPS Recovery Path

**Scenario:** User has a clean machine (Mac or Windows) but no VPS.

**Design principle:** VPS is strongly recommended but not required. No-VPS path is viable with the right setup at install time.

**What changes:**
- No VPS heartbeat server → no recovery web page
- No mutual machine monitoring → Mac Mini outage = no Discord alert from HELM (HELM is down)
- Bot + DB run entirely on the clean machine

**Notification path for no-VPS users (machine goes dark):**
1. HC.io fires after 15 min grace period (not instantly — no false alarms)
2. HC.io → Discord webhook (set up at install, posts directly to user's #helm-status)
   - **Key insight:** HC.io posts directly to Discord via webhook. This bypasses HELM entirely — works even when the machine is down.
   - Set up at install: create Discord webhook for #helm-status, enter URL in HC.io settings
   - HC.io has built-in Discord/Slack integration — no relay server needed
3. HC.io → email as true last resort (Discord also dark)

**Recovery hierarchy for no-VPS users:**

| Step | Action | Requires |
|------|--------|----------|
| 1 | Check #helm-status (HC.io posted there directly) | HC.io → Discord webhook wired at install |
| 2 | Power-cycle the clean machine via smart plug | Smart plug (strongly recommended at install) |
| 3 | Open "Fix HELM" Claude Code shortcut on daily machine | Claude Code on a second device |
| 4 | Contact support | Nothing |

**Install wizard for no-VPS users:**
- Smart plug: strongly recommended (surfaces as "You won't have a web recovery page — smart plug is how you'll restart remotely")
- HC.io Discord webhook: required step in wizard (walk user through HC.io UI)
- Claude Code shortcut creation: required on any second device
- HC.io dead-man's switch is mandatory

**VPS is optional.** The tradeoff is clear: without VPS, there's no button-based recovery page, and recovery requires either a smart plug or physical access. A non-techie user without a smart plug who can't physically access their machine is the hard edge case. Install wizard should surface this tradeoff explicitly and let the user decide.

**VPS outage (for users who HAVE a VPS):**
Smart plug doesn't help — that's for physical machines. VPS restart options:
1. **Provider API restart** (best) — Mac Mini calls provider REST API with stored API key. Zero-click.
2. **Provider web console URL** (fallback) — stored at onboarding, shown in Discord alert: "Click to restart your VPS."
3. **Alert only** — if no API key, user handles manually via provider login.
Captured at onboarding: provider name, API key (optional but recommended), console URL.

---

---

## Two-Scenario Recovery Architecture (2026-06-06)

HELM must work for two user profiles. Every design decision must pass both.

### Scenario A: Full Stack User ({{USER_JERRY}}'s build)
- Mac Mini (always-on physical machine)
- Hostinger VPS
- ntfy
- HC.io + UptimeRobot
- Discord

### Scenario B: Minimal User (generic new user)
- Any clean machine: Mac, Windows, or Linux — physical or cloud
- May have VPS or not
- May not want ntfy or smart plug
- Must have: Discord server, Anthropic account, 1Password, internet

---

## Failure Scenario Matrix — Both User Profiles

| Failure | Detection | Auto-Fix | User Notified Via | Manual Action If Needed | Windows/Linux Note |
|---|---|---|---|---|---|
| **bot.js crash** (machine up) | launchd misses process | launchd auto-restarts | Nothing (silent if auto-fix works) | None | Same: systemd (Linux) or Task Scheduler (Windows) |
| **Clean machine fully off** | VPS: missed heartbeats →  Discord webhook; HC.io: missed pings | None | Discord (direct webhook, bypasses HELM) | Power on machine — no smart plug needed, just physical restart | Same |
| **Clean machine frozen** (OS up, bot dead) | VPS misses heartbeats; HC.io misses pings | VPS SSHes in → restarts bot.js (if SSH works) | Discord: "Attempting restart..." | If SSH fails: physical restart | Same; Windows: SSH restart works if OpenSSH server installed |
| **VPS services crash** (VM up) | Mac Mini: HC.io reports late; Mac Mini polls every 5 min | Mac Mini SSHes VPS → restarts services (vps-service-restart.sh) ✅ BUILT | Discord: "VPS auto-restarted" or nothing if seamless | None | N/A (VPS is always Linux) |
| **VPS VM fully down** | Mac Mini: HC.io reports down; HC.io external watch | Hostinger API auto-restart (API key needed — queued) | Discord: "VPS offline X min, manual restart needed" | Log into Hostinger → restart VPS | N/A |
| **Both machines down** | HC.io + UptimeRobot (external, independent) | None possible | HC.io → Discord direct webhook; email last resort | Restart both — check Discord for which came back | Same |
| **Discord down** | User notices; ntfy is fallback for {{USER_JERRY}} | None | ntfy ({{USER_JERRY}} only); email for others | Wait for Discord recovery | Same |
| **ISP down** | HC.io/UptimeRobot notice machine unreachable | None | HC.io email last resort (user on mobile/data) | Wait for ISP or use mobile hotspot | Same |
| **Claude API down** | bot.js error logs | None | Discord: Claude error message | Wait for Anthropic | Same |
| **PostgreSQL crash** | bot.js fails to connect | pg auto-restart (PostgreSQL service) | Discord: DB error if persistent | Restore from daily backup | N/A (Linux DB) |
| **bot.js running but BROKEN** (software loop, bad deploy, argument loop — machine UP but agents can't respond) | VPS polls `/tmp/helm-last-processed.txt` every 5 min; timestamp >5 min old + HC.io shows UP → flag. User also notices wrong behavior. | TASK-069: VPS SSHes Mac Mini → kills + restarts bot.js (NOT YET BUILT) | Discord: "HELM was unresponsive — restarted" (once TASK-069 built) | Type `!emergency-rollback` (revert + restart) or `!force-restart` in any Discord channel — bypasses ALL routing even when agents are completely broken | Weaker without VPS — no external detection; user must notice and use Discord command manually | Same — commands work on any OS |
| **Mac Mini kernel panic** (physical hardware crash) | HC.io detects machine unreachable | None | HC.io → Discord webhook or email | See pinned message in #helm-status: power off → power on → confirm internet connected. HELM restarts automatically. | N/A | Same — message says "power on your machine and connect to the internet" |

### No-VPS User Failure Matrix (Scenario B, no VPS)

| Failure | Detection | Auto-Fix | Notification Path |
|---|---|---|---|
| Machine crashes/off | HC.io misses pings (15 min grace) | launchd restart if crash; none if off | HC.io → Discord webhook direct (configured at install) |
| Machine frozen | HC.io misses pings | None | HC.io → Discord webhook |
| Both (machine + Discord) dark | HC.io + backup monitor | None | HC.io → email as last resort |

**The no-VPS tradeoff:** Without VPS, there's no button-based recovery page and no mutual watchdog. User recovers via physical restart or Claude Code shortcut on a second device. Install wizard must surface this explicitly.

---

## Clean Machine Platform Support (Mac / Windows / Linux)

All recovery scripts must handle non-Mac clean machines. Current Mac-specific items to generalize:

| Item | Mac (current) | Windows (planned) | Linux (planned) |
|---|---|---|---|
| Process auto-restart | launchd (plist) | Task Scheduler (XML task) | systemd (service file) |
| SSH server (inbound from VPS) | sshd (built-in) | OpenSSH Server (optional install) | sshd (standard) |
| Startup hook | launchd plist | Task Scheduler on boot | systemd service |
| Recovery shortcut | .command file on Desktop | .bat file on Desktop | .sh file on Desktop |
| heartbeat cron | crontab | Scheduled Task | crontab |

**Install wizard responsibility:** detect OS at install, configure the right persistence mechanism. No hardcoded `~/` paths — all paths must use env vars (`$HOME`, `%APPDATA%`).

---

## Notification Path: Bypassing Email (HC.io → Discord Direct)

**Problem:** HC.io currently sends email on outage. Email is confusing to users who don't know what to do.

**Target state:** HC.io → Discord webhook direct (bypasses HELM entirely — works even when both machines are dark).

**Current state:** HC.io has only email channel configured. Discord webhook requires HC.io UI setup (API doesn't support channel creation).

**Engineer task (queued):** Log into HC.io UI → Integrations → Discord → paste webhook URL for #helm-status → assign to both HELM Bot Heartbeat and HELM VPS Heartbeat checks → disable email except as absolute last resort.

**Webhook URL:** In PAP Vault → "VPS SSH Key (Mac Mini → Hostinger)" item notes (same webhook used by mac-watchdog.sh).

**For each new user at install:** Install wizard creates Discord webhook for their #helm-status channel, enters URL in their HC.io account. This is a required step, not optional.

---

## Clean Machine Restart Notification (Smart Plug Replacement)

Smart plug removed from the design — too complex for most users. Replaced by:

**When clean machine goes dark:**
1. VPS detects heartbeat loss
2. VPS → Discord webhook: "Your HELM machine (Mac Mini / Windows PC / Linux machine) appears to be offline. Please make sure it's powered on and connected to the internet. HELM will resume automatically once it reconnects."
3. User powers machine on (physically, or via their own remote power option if they have one)
4. On startup, HELM posts "I'm back" to Discord

**No smart plug required.** The message tells the user exactly what to do. Works for Mac, Windows, Linux.

**For users with cloud clean machine (no physical power toggle needed):** The cloud VM can be restarted via its provider console — same as VPS restart path above.

---

## Fresh-Eyes Gap Audit (2026-06-05, research-backed)

### Critical Gaps (recovery will fail without these)

**1. Backup never tested (🔴 highest risk)**
Industry data: 15-20% of user-led restores fail even when backup files exist.
The untested restore is the #1 actual recovery failure mode, not missing backups.
Fix: Build a "test restore" script. Run it quarterly. HELM should prompt the user annually.

**2. No external monitor when both nodes fail**
If Mac Mini AND VPS go dark simultaneously (power outage, ISP down), there is no
third party watching. The VPS heartbeat server can't alert if VPS itself is down.
Fix: Healthchecks.io or UptimeRobot (free tier) watching the VPS /status endpoint.
These are external SaaS — alive when both your machines are dark.
This is the "dead man's switch" pattern used in every production monitoring setup.

**3. Recovery page doesn't exist**
The single biggest non-techie blocker. All the "click a button to restart" UX requires
this page to be built. Until it exists, recovery requires Claude Code or terminal.

### Medium Gaps (creates user confusion or data loss risk)

**4. No secondary emergency contact**
If ntfy fails AND Discord is dark, there's no SMS or email fallback. Research shows
SMS has 98% open rate vs 20% email — for true "system is down" alerts, SMS is the
only guaranteed reach. This should be captured at onboarding.

**5. Backups are unencrypted**
pg_dump files in GitHub private repo are compressed but not encrypted. If repo access
is ever compromised, agentos DB is exposed. Fix: encrypt before upload (gpg --symmetric).
Low-urgency unless DB contains sensitive financial data.

**6. No independent recovery document**
If HELM is completely bricked, users need a recovery document that lives outside HELM
(printed, in Google Drive, in 1Password). The AI prompt in pap-config repo is good but
assumes users know the URL. Should be in 1Password at install time.

---

## Onboarding — Recovery Info Required

These fields must be captured at install for recovery to be possible:

| Field | Why | Current status |
|-------|-----|---------------|
| Machine type (Mac/Windows) | Terminal vs GUI paths differ | In design |
| VPS provider + login URL | User restarts VPS via web console if API unavailable | Missing |
| Smart plug type | Power-cycle without physical access | In design |
| Out-of-band notification | ntfy topic / email / phone | In proposal |
| Discord server ID | Recovery prompt personalization | In design |
| Support contact | Escalation path | In design |
| Secondary emergency contact | SMS fallback if primary fails | Missing |
| 1Password vault name | Credential recovery after full wipe | Missing |
| Recovery URL (VPS page) | Where to go when bot is dark | Blocks VPS page |

---

## Build Order (revised)

1. ✅ External dead-man's-switch — Mac Mini pings HC.io (live)
2. ✅ External dead-man's-switch — VPS pings HC.io separately (live 2026-06-06)
3. **HC.io → Discord webhook wire** (engineer queued — also enables email silence)
4. **Install wizard** — Tier A priority for new-user readiness. Branches on: desktop-only / VPS-only / full-stack. Detects OS (Mac/Windows/Linux). Captures provider + API key. Generates per-user HC.io check + Discord webhook + recovery token. Everything below is blocked until this exists for generic users.
5. VPS recovery web page (blocked on install wizard for generic users; deployable for {{USER_JERRY}} now)
6. Backup restore test script (quarterly prompt in Steward)
7. Hostinger API auto-restart (API key needed from Hostinger UI)
8. Secondary contact capture at onboarding
9. Backup encryption (lower urgency)
10. "Fix HELM" Claude Code shortcut (no-VPS primary recovery path)

**Install wizard branching (3 paths):**
- Desktop-only → HC.io check + Discord webhook (required step) + Claude Code shortcut; no VPS page
- VPS-only → HC.io check + provider API key + recovery page at http://[vps-ip]:8080/recovery
- Full-stack → both above; mutual watchdog enabled

---

## Software-Loop Failure Class (NEW — added 2026-06-07, post-mortem Session N)

**What it is:** Bot.js is running (machine is UP, HC.io is happy) but producing wrong outputs or not responding to messages. Hardware watchdogs don't catch this — the machine looks healthy from the outside.

**Incident that revealed this:** Orchestrator routing gate triggered on nearly every ACK message (>3 min estimate OR 3+ numbered lines), causing orchestrator to expand conversational questions into garbage sub-tasks. Subprocess failed → false DELIVER → silence. Restart guard then blocked recovery by requiring a verified code change before allowing restart, and got into an argument loop with itself.

**What made this require terminal work:**
- No automated detection of "bot.js running but not processing messages correctly"
- No bypass path for restart guard when bot is in confirmed bad state
- No pinned rollback command to paste from memory under pressure

**New failure class entry (add to main matrix):**

| Failure | Detection | Auto-Fix | User Notified Via | Manual Action |
|---|---|---|---|---|
| **bot.js running but unresponsive** (software loop, wrong output, argument loop) | VPS polls `/tmp/helm-last-processed.txt` via SSH every 5 min; if timestamp >5 min old AND HC.io shows machine UP → trigger restart | VPS SSHes Mac Mini → `pkill -f bot.js && sleep 2 && cd ~/marvin-bot && npm start &` (TASK-069 — NOT YET BUILT) | Discord: "Detected HELM was unresponsive — restarted automatically" | Paste rollback command (see below) if restart doesn't help |
| **Bad deploy / orchestrator misconfiguration** | User notices wrong behavior | git revert (engineer task: orchestrator classifier) | Nothing automatic | Use rollback command |

---

## Rollback Command (pin in #helm-status)

When bot.js is running but broken due to a bad code change, paste this from memory or the pinned message:

```
git -C ~/marvin-bot revert HEAD --no-edit && ~/marvin-bot/safe-restart.sh --force
```

**Where it lives:** Pin in Discord #helm-status. Also save in 1Password as "HELM Emergency Rollback" for non-techie users.

**What it does:** Reverts the most recent commit to bot.js, then force-restarts. Works for any bad deploy. Does not require knowing which commit broke things.

---

## In-Band Discord Emergency Commands (DISCORD-ROLLBACK-HANDLER — engineer queued)

**Goal:** Recovery without any terminal. Owner types a Discord command that bypasses all routing.

**Commands:**
- `!emergency-rollback` — reverts HEAD commit + force-restarts (skips restart guard)
- `!force-restart` — kills and restarts bot.js only (no revert; use when bad state but no bad commit)

**How it works:** bot.js catches these at the lowest message handler level, before any routing logic runs. Even if agents are broken and routing is garbage, the handler still fires. Owner-only (checks Discord user ID against OWNER_DISCORD_ID env var).

**Why this closes the terminal gap:** The 2026-06-07 incident would have been: type `!emergency-rollback` → done. No SSH, no terminal, no clean machine needed.

**Status:** Engineer task queued (DISCORD-ROLLBACK-HANDLER).

**For generic users:** Same design. Install wizard captures OWNER_DISCORD_ID at setup. Works for any user's bot instance.

**Limitation:** Reverts exactly 1 commit. If multiple bad commits, run again. If the problem is in config (not code), rollback won't help — restart with `~/marvin-bot/safe-restart.sh --force` directly.

---

## Restart Guard Bypass Design

**Problem:** Restart guard requires one verified code change per restart to prevent loops. When bot.js is in a confirmed bad state, this makes recovery harder — guard blocks clean restarts.

**Fix:** Bypass path for confirmed bad state:
- `safe-restart.sh --force --skip-guard` → skips guard, restarts immediately, logs to helm-audit
- Triggered by: VPS dead-man's switch (automated), or user from Discord (L3 action)
- Guard bypass is logged: any `--skip-guard` invocation writes to `~/pap-workspace/helm-audit/` with timestamp + reason

**Status:** Engineer task queued.

---

## TASK-069 Design: Process-Level Dead-Man's Switch

**What:** VPS detects that bot.js is running but not processing messages, and SSHes in to restart it. No Mac Mini terminal needed.

**Detection mechanism:**
1. bot.js writes timestamp to `/tmp/helm-last-processed.txt` every time it successfully handles a message
2. VPS cron (every 5 min): `ssh mac-mini "cat /tmp/helm-last-processed.txt"` → check if >5 min old
3. Cross-check: HC.io must show machine UP (so we're not catching hardware failures — those are already handled)
4. If timestamp stale AND machine UP → trigger restart

**Restart sequence (on VPS):**
```bash
ssh mac-mini "pkill -f 'node.*bot.js'; sleep 3; cd ~/marvin-bot && npm start >> ~/marvin-bot/marvin.log 2>&1 &"
```

**Post-restart check:** VPS waits 60s → reads timestamp again. If still stale → post to Discord: "Automatic restart attempted but HELM still not responding. Please check your machine."

**For users without VPS:** HC.io integrates with a simple HTTPS health endpoint. Install wizard configures HC.io to hit `http://[mac-ip]:PORT/health` every 5 min. If bot.js is frozen (port up but no response), HC.io alerts. Auto-restart still requires either VPS or a second device.

**Status:** HIGHEST PRIORITY engineer task. Every incident requiring terminal work since Session 8 traces to this gap.

---

## grab-logs.sh — Verified Working (2026-06-07)

Script exists at `~/marvin-bot/grab-logs.sh`. Tested — produces a single bundled file at `/tmp/pap-diagnostic-[timestamp].txt` containing:
- Bot process status
- Last 100 lines of marvin.log
- ACTIVE-STATE.md
- All channel-state JSON files
- Last 30 lines of friction-log
- Last 10 git commits

**How to use:** Run the script → drag the output file into Claude.ai → describe the problem. Claude can diagnose without any terminal navigation.

**For new users:** Install wizard should document this command as a pinned message in #helm-status. Non-techie users need to know this script exists before an incident happens.

**Action:** Add grab-logs.sh path to #helm-status pinned message + onboarding script. Engineer task queued.

---

*Design status: approved for build planning.*
*Last updated: 2026-06-07 — added software-loop failure class, rollback command, TASK-069 design, restart guard bypass, grab-logs.sh verification, in-band Discord emergency commands (DISCORD-ROLLBACK-HANDLER), feedback from Claude AI Chat incident review*
