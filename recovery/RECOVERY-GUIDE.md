# HELM Recovery Guide
## For non-technical users — no terminal required

---

## The one rule that explains everything

**When HELM is silent: hit the 🛡️ Fix HELM button (or type `!fix` in Discord).**

It runs an automatic 4-step cascade — checks if HELM is already alive, then tries restart, then rollback, then hands you a Claude.ai escalation prompt. Zero decisions to make. Either succeeds or guides you to AI help. No need to pick the right command.

**Two places to hit the button:**
- 🛡️ **Recovery Webpage:** https://status.{{USER_DOMAIN}}/recovery (sign in with {{USER_DOMAIN}} password)
- 🛡️ **Lifeline Bot in Discord:** Type `!fix` in any channel — the backup bot responds even when main HELM is dead

If both of those are unreachable, that means the Mac mini itself is offline:
1. Check Mac is powered on (white light on front)
2. Power-cycle the Mac (hold power 5s, release, press again) — HELM auto-starts on boot
3. Open https://status.{{USER_DOMAIN}}/recovery/prompt on phone → paste into claude.ai for guided help

---

## Honest cheat sheet — what works when

| Failure type | How you'll notice | !restart works? | Webpage works? | What to do |
|---|---|---|---|---|
| Queue overload ("Queue overload — request dropped") | Messages bounced, nothing answers | ✅ | ✅ | Force Restart (kills all queued tasks, starts fresh) |
| Agent stuck / task hung | HELM acks but never delivers | ✅ | ✅ | `!restart` in #helm-recovery |
| Bad update broke something | Errors after a recent change | ✅ | ✅ | `!rollback` in #helm-recovery |
| Claude API outage | Bot replies but agents hang | ✅ | ✅ | `!restart`; if it loops, wait 5-10 min (external outage) |
| Bot process dead | Total silence, no 👍 acks | ✅ | ✅ | `!restart` first; webpage if that fails |
| Routing broken (June 7 class) | Messages accepted, nothing back | ✅ | ✅ | `!restart` in #helm-recovery |
| VPN (Tailscale) down | Alert says "Mac still online" | ✅ | ✅ | `!restart` or webpage |
| Mac lost internet (router incident) | Alert says "fully offline" | ❌ | ❌ | Self-heals in ~4 min (watchdog cycles Wi-Fi). Check router if not. |
| Mac lost power / kernel panic | Alert says "fully offline" | ❌ | ❌ | Power-cycle Mac — HELM starts automatically on boot |
| Discord itself is down | Discord app broken for everything | ❌ | ✅ | Webpage for restart; wait for Discord |
| Usage limit reached | "Usage limit" message | n/a | n/a | Wait — auto-resumes when window resets |
| Auth expired | Silence + relogin alert | n/a | n/a | Auto-relogin runs silently; if alerted, log in at claude.ai then `!restart` |
| Bad update — runtime variable bug ("HOME is not defined") | Bot.js running, agents ACK then immediately say "Something went wrong" | ✅ rollback | ✅ | Use `!rollback` (not restart). Auto-revert now catches this before deploy. |

---

## The Recovery Webpage (your main tool when HELM is dead)

**URL:** https://status.{{USER_DOMAIN}}/recovery
**Sign-in:** use your **{{USER_DOMAIN}} password** (same one protecting all {{USER_DOMAIN}} sites). Stays signed in for 7 days.

What it gives you:
- **System Status** — live health check of the Mac and bot
- **Restart Bot** — queues a restart command; your Mac picks it up within 60 seconds (verified end-to-end, no bot involvement)
- **Rollback** — restores yesterday's working version, then restarts
- **Get AI help** — link to the copy-paste prompt for claude.ai

After tapping Restart/Rollback the page shows live progress. If the Mac doesn't respond within 5 minutes, the page tells you so — that means the Mac is offline (see next section).

---

## When the webpage can't reach the Mac

This means the Mac mini has no power or no internet. The watchdog alerts in #recovery now tell you which:

- ⚠️ **"Mac is still online, VPN link down"** → the webpage Restart button still works — use it.
- 🔴 **"Mac appears fully offline"** → it's power or internet:
  1. Check the Mac mini is powered on (white light on front).
  2. Check your internet/router. If the router rebooted, the Mac's network watchdog cycles Wi-Fi automatically and recovers within ~4 minutes — give it that long.
  3. Still down? Power-cycle the Mac (hold power 5s, release, press again). HELM starts automatically on boot.
  4. Stuck 10 min later? AI help: https://status.{{USER_DOMAIN}}/recovery/prompt

---

## Self-healing you never see

These run automatically — listed so you know what's already covered:

| Watchdog | Checks every | Heals |
|---|---|---|
| launchd KeepAlive | 30s | Bot process crash → auto-restart |
| helm-selfheal | 30s | Stuck bot states |
| Network watchdog (Mac) | 60s | Internet loss → cycles Wi-Fi after 3 failed checks |
| Tailscale watchdog (Mac) | 5 min | VPN disconnects → re-up |
| Dead-man switch (VPS) | 5 min | Bot alive but not processing → SSH restart + verify |
| Mac watchdog (VPS) | 2 min | Mac silent 10+ min → diagnostic alert to #recovery |
| Auto-relogin | on failure | Claude session expiry → reads magic link from Gmail |

**Recovery server architecture (authoritative):**
- VPS runs the canonical recovery server (`status.{{USER_DOMAIN}}`). It survives Mac failures.
- Mac runs `com.helm.recovery-poll` only — polls VPS for queued commands and executes them locally.
- A Mac-side recovery server would be useless during the exact outage it's meant to fix. Mac copy was removed 2026-06-15.

---

## Quick reference

| What you see | Action |
|---|---|
| "Queue overload" bouncing messages | 🔄 Force Restart — that's exactly the right button |
| Silence 5-10 min | 🩺 System Status button; if no reply, webpage |
| Stuck task | 🔄 Force Restart button |
| Broke after update | ⏮ Emergency Rollback button (or webpage Rollback if bot silent) |
| Total silence, buttons do nothing | https://status.{{USER_DOMAIN}}/recovery → Restart Bot |
| Webpage says Mac not responding | Check power/router; power-cycle Mac |
| "Usage limit reached" | Wait, auto-resumes |
| "Auth relogin failed" alert | Log in at claude.ai, then Force Restart |
| Anything confusing | https://status.{{USER_DOMAIN}}/recovery/prompt → claude.ai |

---

## Fresh install — rebuilding credentials (.env)

If you're setting up HELM on a new machine, the `.env` file is NOT stored in any backup (by design — it contains secrets). Rebuild it from 1Password vault:

| Variable | Where to find it |
|---|---|
| `DISCORD_BOT_TOKEN` | 1Password → HELM Vault → "Discord Bot Token" |
| `HC_API_KEY` | 1Password → HELM Vault → "Healthchecks.io API Key" |
| `VPS_CHECK_UUID` | 1Password → HELM Vault → "Healthchecks.io VPS UUID" |
| `GITHUB_PAT` | 1Password → HELM Vault → "GitHub PAP Backup Token" |

All other config lives in `helm-recovery.conf` (backed up to helm-config GitHub repo, no credentials).

Run `bash ~/marvin-bot/helm-recovery-install-wizard.sh` on a fresh machine to configure everything.

---

## Off-machine backups

| What | Where | Schedule |
|---|---|---|
| Recovery scripts + plists | GitHub: helm-config repo | Nightly 3:15am PT |
| Claude memory files | GitHub: helm-config repo | Nightly 3:00am PT |
| VPS database | GitHub: platform-config + local ~/backups/vps | Nightly 2:30am PT |
| Recovery webpage | https://status.{{USER_DOMAIN}}/recovery | Always live on VPS |

---

## Incident log

### 2026-06-14 — `--dangerously-skip-permissions` flag dropped from bot.js
**What happened:** Commit `ea51fe4` (Fable 5 model-unavailable classification fix, 14:03) touched the `claudeArgs` array and accidentally removed `--dangerously-skip-permissions`. The flag is what tells Claude Code to skip per-tool approval prompts on non-interactive (`-p`) runs. Without it, every spawned agent ACK'd and then failed at the very first tool call. The settings.json `permissions.allow` block was present and correct — but settings.json permissions are only honored when the skip-permissions flag is also passed at invocation. Total agent outage from 14:03 until restored at 21:48 via `7117e6a`.
**Root causes found:**
1. The Fable 5 fix touched many lines around model handling; the claudeArgs change was unintentional collateral damage
2. The auto-revert / safe-restart validation pipeline only checked JavaScript syntax — the file parsed cleanly, so it passed
3. No behavioral test ran a real agent against a tool call before declaring the deploy healthy
4. Symptoms (agents getting "permission denied") pointed toward settings.json (which was correctly configured) and not the flag (which had been silently dropped)
**Fix applied:** Restored `--dangerously-skip-permissions` to `claudeArgs`. Refactored to a top-level named constant `CLAUDE_BASE_ARGS` so future edits can't silently drop it.
**Prevention measures (implemented 2026-06-14):**
1. ✅ Added flag-presence preflight grep to `safe-restart.sh` — exit 1 on missing, posts critical alert to helm-improvements
2. ✅ Added flag-presence check to `auto-revert.sh` validation suite — triggers Layer 3 revert on missing
3. ✅ Refactored `claudeArgs` in bot.js to use named constant `CLAUDE_BASE_ARGS` with comment marking the flag as Level 4
4. ✅ Documented this incident class in this guide
5. ✅ Added behavioral smoke test (Check 4) to `safe-restart.sh` — after every restart, spawns a real claude agent and verifies it can complete a tool call (TOOLCALL_VERIFIED). Catches any agent-execution breakage that syntax checks and routing tests miss.
6. **Symptoms:** Agents initialize and ACK but say "permission denied" or "tool call blocked" for every action — even when `~/.claude/settings.json` is correctly configured.
6. **Diagnostic:** `grep -n claudeArgs ~/marvin-bot/bot.js | head -5` — if `--dangerously-skip-permissions` is missing, this is the cause.
7. **Manual recovery:** Edit `~/marvin-bot/bot.js` line ~72 to restore `const CLAUDE_BASE_ARGS = ['--dangerously-skip-permissions', '-p'];` then `git commit && ~/marvin-bot/safe-restart.sh`.

### 2026-06-14 — Claude Code permissions gate silently blocked all agent execution
**What happened:** Agents spawned and ACK'd, then immediately failed on every tool call (Read, Write, Edit, Bash) because ~/.claude/settings.json was missing the `permissions` block. Without this configuration, Claude Code defaults to interactive-only mode — agents running non-interactively (via `claude -p`) can never get permission approval, so all tool calls fail silently.
**Root causes found:** 
1. During machine setup, the permissions block was never added to ~/.claude/settings.json
2. Agents couldn't self-diagnose because the permission gate blocked even the Read tool that would reveal the problem
3. No preflight check existed in safe-restart.sh to verify permissions before starting agents
4. Agent instructions told the user to run non-existent `/permissions` and `/fewer-permission-prompts` slash commands
**Fix applied:** Added the required permissions block to ~/.claude/settings.json with `allow: ["Bash(**)", "Read(**)", "Write(**)", "Edit(***)"]`. One-time fix; now permanent.
**Prevention measures (implemented 2026-06-14):**
1. ✅ Added permissions preflight check to safe-restart.sh — fails startup with clear diagnostic if block is missing
2. ✅ Added permissions validation to auto-revert.sh Layer 3 — restores from snapshot if missing
3. ✅ Enhanced recovery-guide.md with symptoms and fix command
4. ✅ Added `!check-permissions` Discord command for self-diagnosis
5. Store canonical ~/.claude/settings.json in pap-config GitHub repo for quick restore (pending)

### 2026-06-13 — Recovery system was claimed working but wasn't
**What happened:** {{USER_JERRY}} tried the recovery webpage and his {{USER_DOMAIN}} password was rejected. He tried the AI Help link and it returned 404. Both core recovery paths were broken at the moment he needed them.
**Root causes found:**
1. **Recovery webpage crash-loop** — VPS recovery server had been restarting 46,000+ times because a zombie process held port 8080; each new systemd-launched instance failed to bind. So the page {{USER_JERRY}} saw was served by an old broken instance.
2. **Wrong password configured** — the systemd unit had a random 48-char hex token (`2b86991ae45...`), not the canonical {{USER_DOMAIN}} Site Auth password {{USER_JERRY}} expected. The "site auth" pattern was inconsistent.
3. **/recovery/prompt route never existed** — nginx and the recovery server had no handler for the AI Help URL the pinned message advertised. Always 404.
4. **Nginx mis-proxied /api/recovery** — `proxy_pass http://127.0.0.1:8080/api` stripped the wrong prefix, turning `/api/recovery-action` into `/api-action` (404 on the backend).
5. **Lifeline-bot was restricted to 2 channels** — pinned message implied it worked everywhere, code limited it to #helm-recovery + one thread.
6. **Network watchdog never wrote logs** — launchd plist didn't set `HOME`, so the log path expanded to `/marvin-bot/...` (silent failure). The watchdog was probably running but produced zero evidence.
7. **Two lifeline-bots fighting over one token** — both VPS and Mac were running the same bot code with the same Discord token; Discord disconnected one of them.
**Fixes shipped (all verified end-to-end this session):**
- Killed the zombie port-8080 holder, restarted recovery server cleanly
- Updated systemd env to use canonical {{USER_DOMAIN}} Site Auth password
- Fixed nginx `/api/recovery` routing to preserve full path
- Added `/recovery/prompt` route serving the AI help page with a copy-to-clipboard button — no auth needed
- Expanded lifeline-bot to listen in ALL Discord channels (`ALLOWED_CHANNELS=null`)
- Added `HOME` to network-watchdog plist + hourly heartbeat for proof-of-life logging
- Disabled Mac-side duplicate recovery-server + lifeline-bot
- Verified: HTTPS recovery webpage with right password → 200 + action runs; wrong password → 403; `test_ping` returned Mac heartbeat data from VPS

### 2026-06-12 — Recovery chain rebuilt after 3 failed recoveries
**What happened:** Three disruptions in a row where Discord recovery buttons did nothing and the AI prompt wouldn't load. (The fixes from this date were partially incorrect — see 2026-06-13 entry above for what was actually still broken.)
**Root causes found:** (1) Every Discord button is handled by bot.js itself — dead exactly when needed; (2) the out-of-band webpage chain was broken end-to-end (the VPS endpoint the Mac reports to didn't exist); (3) the router reboot took out Wi-Fi → Tailscale → all watchdog paths with no self-heal.
**Fixes shipped:** webpage→VPS→Mac command chain repaired and verified end-to-end (45s round trip, zero bot involvement); AI prompt now hosted at /recovery/prompt (no bot needed); Mac network watchdog cycles Wi-Fi automatically; VPS alerts now diagnose VPN-down vs fully-offline and say exactly what to do; pinned message rewritten to be honest about which buttons work when.

### 2026-06-10 23:55 UTC — Claude API outage
Agents hung at ACK for 300+ s; bot alive but no work completed. `recover_force` only cleared PIDs without restarting. Fix: buttons now `pkill -9` before `safe-restart.sh --force`. When the API is down, restarts may loop until it recovers — expected, not a HELM bug.

---

## Disruption taxonomy — every failure mode and recovery path

This is the full map. If something fails and you can't find it here, that's a gap — file it.

### A. HELM application layer (bot.js + agents)
| Failure | Symptom | Auto-heal? | If not: what to do |
|---|---|---|---|
| Agent stuck in tool call | ACK fired, no DELIVER | yes — watchdog kills + recovers in ~5 min | `!restart` in any Discord channel |
| Single agent crashed | One channel silent, others fine | yes — launchd KeepAlive | wait 30s; if still silent, `!restart` |
| Whole bot.js crashed | ALL channels silent, no acks | yes — launchd KeepAlive | wait 30s; if still down, `!restart` |
| Bad code update | Errors appearing after a deploy | no | `!rollback` (web button) or `!rollback` in Discord |
| API outage (Claude/OAuth) | Bot alive, all agents fail | no — external | wait 5-15 min; check claude.ai/status |
| Auth/relogin expired | Silence, then "magic link" alert | yes — Gmail MCP reads link silently | only act if explicit user-action alert |
| Claude Code permissions gate | Agent ACKs then silent; or "permission denied" message | no | **Quick check:** type `!check-permissions` in Discord — it reports what's in settings.json and gives you the fix command. **Manual fix (terminal):** `python3 -c "import json,os; f=os.path.expanduser('~/.claude/settings.json'); d=json.load(open(f)); d['permissions']={'allow':['Bash(**)', 'Read(**)', 'Write(**)', 'Edit(**)']}; open(f,'w').write(json.dumps(d,indent=2)); print('done')"` Then tell Marvin: "permissions fixed, please proceed." |
| `--dangerously-skip-permissions` flag dropped | Agents ACK then tool calls denied — but `!check-permissions` reports OK | preflight grep in safe-restart blocks restart with missing flag | **Diagnostic:** `grep -n claudeArgs ~/marvin-bot/bot.js` — confirm `CLAUDE_BASE_ARGS` includes `--dangerously-skip-permissions`. **Fix:** edit bot.js line ~72 to restore the flag in `CLAUDE_BASE_ARGS`, commit, then `~/marvin-bot/safe-restart.sh`. |
| Usage limit reached | "limit reached" reply | yes — auto-resumes at window reset | wait |

### B. Operating system (Mac mini)
| Failure | Symptom | Auto-heal? | If not: what to do |
|---|---|---|---|
| Mac kernel panic | All processes gone, machine reboots | partial — boots back, HELM auto-starts | wait 3 min; if still down, physical power-cycle |
| Mac powered off | No heartbeat, no ping | no | physically press power button |
| Mac LaunchAgents corrupted | bot.js doesn't start at boot | no | `bash ~/marvin-bot/helm-recovery-install-wizard.sh` from terminal (advanced) |

### C. Network layer
| Failure | Symptom | Auto-heal? | If not: what to do |
|---|---|---|---|
| Wi-Fi dropped (router reboot) | Mac silent, "fully offline" alert | yes — network watchdog cycles Wi-Fi after 3 fails (~3 min) | wait 4 min; check router; consider wired ethernet |
| DNS broken (IP works, names don't) | Some services flap, others fine | yes — watchdog detects + cycles Wi-Fi | wait 4 min |
| Tailscale VPN down | "Mac online, VPN link down" alert | yes — pap-tailscale-watchdog re-ups every 5 min | use Recovery Webpage (uses public internet, not VPN) |
| ISP outage | Everything down, including web | no | wait for ISP; nothing recovery-system can do |

### D. VPS layer
| Failure | Symptom | Auto-heal? | If not: what to do |
|---|---|---|---|
| Recovery server down | Webpage returns 502 or 500 | yes — systemd Restart=always | wait 10s; if persistent, see incident log 2026-06-13 |
| Lifeline-bot down | !restart/!status no reply | yes — systemd Restart=always | wait 10s |
| VPS rebooted | Recovery webpage offline | yes — systemd starts on boot | wait 1-2 min |
| VPS provider outage | Webpage + lifeline-bot both down | no — external | Mac-local recovery only: power-cycle Mac |

### E. Discord layer
| Failure | Symptom | Auto-heal? | If not: what to do |
|---|---|---|---|
| Discord down for everyone | Discord app broken | no — external | use Recovery Webpage at status.{{USER_DOMAIN}}/recovery — does not need Discord |
| Bot token revoked | HELM bot offline forever | no | rebuild .env from 1Password vault → restart |

### F. Catastrophic / multi-failure
| Failure | Symptom | Recovery |
|---|---|---|
| Mac AND VPS both down | No recovery path online | Power-cycle Mac (it self-starts HELM). If still nothing, you're waiting on your home network or VPS provider. |
| Discord AND VPS both down | Total comms blackout | Power-cycle Mac. Wait for Discord/VPS provider to recover. |

---

## Known gaps (recovery has limits — be honest)

These are unresolved and would need new infrastructure to fix:

1. **No out-of-band notification when Discord itself is down.** If Discord is the failure mode AND the user isn't checking the recovery webpage, they have no signal that HELM is down. Recommended fix: Twilio SMS or Mailgun email integration on VPS dead-man's switch, sending alerts to a phone number/email when the clean machine is unreachable >15 min. Estimated build: ~2 hours including credential setup. Not built.
2. **Single clean machine = single point of failure.** If the clean machine hardware dies, HELM is offline until repair/replacement. The VPS keeps lifeline-bot reachable but can't run HELM itself. Recommended: documented bring-up procedure for a backup machine (currently: pap-onboarding-script.md gets new users running; same procedure restores existing user's HELM on new hardware).
3. **Recovery webpage requires browser + site auth password.** If the user is in a state where they have no browser or forgot the password, only the physical power-cycle works. Recommended: print a recovery card (one page, large text) with: the URL, where the password is stored, what to do if both fail. *Not yet built.*
4. **Lifeline-bot Discord username inherits from app name.** The {{USER_JERRY}}-instance bot was created with the token-as-name and shows as "HELM Lifeline Bot Token#7910" — ugly. New users must set a clean Application Name in Discord Developer Portal. Rename of existing bot is a manual {{USER_JERRY}} task. Documented in HELM-RECOVERY-ONBOARDING.md.
5. **No single-button auto-recovery yet.** Currently the user has to choose between Restart / Rollback / Test. For queue overload specifically: Force Restart is the answer. Design ready (HELM-AUTO-RECOVERY-DESIGN.md, Level 4 — {{USER_JERRY}} approval needed). When built: one "🛡️ Fix HELM" button runs a 7-step cascade. ~9 hours of engineer work.
6. **Mission-control dashboard doesn't yet embed recovery card.** Recovery lives at separate `/recovery` URL instead of inside the main dashboard. Spec ready (HELM-RECOVERY-WORKSPACE-INTEGRATION.md, Level 3 — mission-control workspace agent to implement).
7. **Hardcoded `{{USER_DOMAIN}}` references throughout user-facing pages.** Multi-user template fix in progress (HELM-RECOVERY-ONBOARDING.md Part 7). Variables defined; engineer queue item pending to replace hardcoded references with `{{user_domain}}` placeholders in recovery-server.py HTML and lifeline-bot.js text.

---

*Last updated: 2026-06-13*
