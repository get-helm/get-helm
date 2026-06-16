# HELM Recovery — Onboarding (Multi-User, Hardware-Variant)

**For the onboarding thread (channel {{USER_CHANNEL_BETA_USERS}}).**

This is the recovery section that must integrate into the main onboarding script. It handles users on any hardware (Mac mini, Linux server, Windows PC), and uses template variables instead of hardcoded `{{USER_DOMAIN}}` references.

---

## Recovery has 4 layers (all users)

| Layer | What it does | Works when... |
|---|---|---|
| 1. Lifeline Bot | Backup Discord bot, accepts `!fix` `!restart` `!rollback` `!status` in any channel | HELM main bot is completely silent |
| 2. Recovery Webpage | One-button "Fix HELM" UI on the user's mission-control dashboard | HELM dead but the clean machine is online |
| 3. Power-cycle | User physically restarts the clean machine; HELM auto-starts on boot | Clean machine offline (power/network) |
| 4. AI Help | Personalized Claude.ai prompt with full system context | All else fails |

The user only ever clicks ONE button on the recovery webpage. The cascade tries every fix automatically and escalates to a Claude.ai prompt if all fail.

---

## Part 1: Two Discord bots (every user)

Every user creates TWO Discord bots during onboarding:

### Main HELM Bot
1. Discord Developer Portal → New Application → name it "{{bot_name}}" (default: "HELM")
2. Bot section → Add Bot → Copy Token
3. Save in 1Password vault as `{{user_bot_token_entry}}` (e.g., "HELM Bot Token")
4. Intents: Message Content + Server Members
5. OAuth2 URL Generator → scopes: bot, permissions: Send Messages, View Channels, Read Message History, Manage Messages, Embed Links
6. Authorize bot to user's Discord server

### Lifeline Bot (backup recovery bot)
1. Discord Developer Portal → New Application → name it "{{bot_name}} Lifeline" (default: "HELM Lifeline")
2. Bot section → Add Bot → Copy Token
3. Save in 1Password vault as `{{user_lifeline_token_entry}}` (e.g., "HELM Lifeline Bot Token")
4. Intents: Message Content
5. OAuth2 URL Generator → scopes: bot, permissions: Send Messages, View Channels, Read Message History
6. Authorize bot to user's Discord server

**IMPORTANT:** When creating the Lifeline Bot in the Developer Portal, set the **Application Name** to something readable like "HELM Lifeline". Don't accept the default — the Discord username inherits from the application name. (The current {{USER_JERRY}}-instance bot is mis-named "HELM Lifeline Bot Token#7910" because the token was used as the name. New users should not repeat this mistake.)

---

## Part 2: Recovery credentials in vault

Each user's 1Password vault stores:

| Entry name | Field | Value | Purpose |
|---|---|---|---|
| `{{site_auth_entry}}` (e.g., "{{USER_DOMAIN}} Site Auth") | password | the user's site auth password | Recovery webpage login |
| `{{user_lifeline_token_entry}}` | password | Discord token from Part 1 | Lifeline bot login |

The {{site_auth_entry}} password is the SAME password the user uses for all their {{user_domain}} websites — there's no separate "recovery password" to manage.

---

## Part 3: Hardware variation — what changes by machine

The recovery system core works the same way for all users, but a few install-time steps vary by hardware:

### Mac mini ({{USER_JERRY}}-style)
- **Auto-start mechanism:** launchd (`~/Library/LaunchAgents/`)
- **Health endpoint:** runs locally on port 8080 (Mac watchdog)
- **Network watchdog:** macOS-specific `networksetup` commands to cycle Wi-Fi
- **Self-heal on crash:** launchd KeepAlive
- **Wake-on-LAN:** generally not supported (Mac sleep complicates this)

### Linux server (recommended for production users)
- **Auto-start mechanism:** systemd (`/etc/systemd/system/`)
- **Health endpoint:** runs locally on port 8080
- **Network watchdog:** systemd-networkd or NetworkManager `nmcli` commands
- **Self-heal on crash:** systemd `Restart=always`
- **Wake-on-LAN:** YES — VPS can wake the box from LAN

### Windows PC (consumer-friendly)
- **Auto-start mechanism:** Task Scheduler (`taskschd.msc` with "At startup" trigger)
- **Health endpoint:** runs locally on port 8080
- **Network watchdog:** PowerShell `Restart-NetAdapter`
- **Self-heal on crash:** Task Scheduler with restart-on-failure
- **Wake-on-LAN:** YES — most consumer motherboards support it

The install wizard MUST detect or ask the user's OS and configure the right auto-start path. See HELM-INSTALL-WIZARD spec for the detection + branching logic.

---

## Part 4: VPS (every user)

Every user needs a VPS for the recovery system. Recommendations at onboarding:
- Hostinger ($5/mo) — {{USER_JERRY}}'s current choice
- DigitalOcean ($6/mo droplet)
- Linode ($5/mo nanode)
- Any Linux VPS with public IP

The VPS hosts:
- `recovery-server.py` (port 8080, behind nginx)
- `lifeline-bot.js` (Discord backup bot)
- The user's mission-control dashboard at `https://status.{{user_domain}}` (or `https://status.[vps-ip].sslip.io` if no custom domain)

**VPS install wizard** (engineer to build):
1. SSH into fresh VPS
2. Run `bash <(curl -s https://raw.githubusercontent.com/[helm-repo]/install/install-vps.sh)`
3. Wizard asks: site auth password, Discord lifeline bot token, user_domain (optional)
4. Wizard sets up nginx + Let's Encrypt SSL + recovery-server.service + lifeline-bot.service
5. Wizard pushes SSH key from VPS to user's clean machine (for restart capability)
6. Test: `curl https://status.{{user_domain}}/recovery → 200`

---

## Part 5: Single-button auto-recovery (Level 4 — {{USER_JERRY}} to approve build)

When recovery is needed, user clicks ONE button. The system runs a 7-step cascade automatically. See HELM-AUTO-RECOVERY-DESIGN.md for the full spec.

User journey:
```
HELM goes silent
↓
User opens mission-control dashboard (or recovery webpage as fallback)
↓
Recovery card auto-expanded to red state
↓
User clicks "🛡️ Fix HELM"
↓
Live progress: 1/7, 2/7, 3/7... most cases done by step 3 (~2 min)
↓
Success: 🟢 HELM is back
   OR
Failure (step 7): "All automatic fixes failed. Open Claude.ai with this prompt" → user copies the prompt → pastes in claude.ai → guided fix
```

Zero triage decisions. Zero terminal. Zero asking "should I restart or rollback?"

---

## Part 6: Self-healing (invisible)

These watchdogs run regardless of user action — they fix problems before the user notices:

| Watchdog | Frequency | What it fixes |
|---|---|---|
| launchd / systemd / Task Scheduler KeepAlive | 30s | Bot process crash → auto-restart |
| helm-selfheal | 30s | Stuck bot states |
| Network watchdog (clean machine) | 60s | Internet loss → cycles Wi-Fi/network after 3 failed pings |
| Tailscale watchdog | 5 min | VPN drops → re-up |
| Dead-man switch (VPS → clean machine) | 5 min | Bot alive but not processing → SSH restart + verify |
| VPS-watching-clean-machine | 2 min | Clean machine silent 10+ min → diagnostic alert to recovery channel |
| Auto-relogin | On failure | Claude session expires → reads magic link from Gmail silently |

The user is told about these once at onboarding, then never sees them. They just work.

---

## Part 7: Multi-user template — DO NOT hardcode

When you write user-facing recovery text, USE these template variables (don't hardcode "{{USER_DOMAIN}}"):

```
{{user_domain}}            → e.g., "{{USER_DOMAIN}}" / "alice.dev" / "[vps-ip].sslip.io"
{{recovery_url}}           → "https://status.{{user_domain}}/recovery"
{{mission_control_url}}    → "https://status.{{user_domain}}"
{{site_auth_label}}        → e.g., "{{user_domain}} password" — same password as user's other sites
{{vps_provider}}           → "Hostinger" / "DigitalOcean" / "Linode"
{{vps_ip}}                 → e.g., "159.203.81.222"
{{machine_type}}           → "Mac mini" / "Linux server" / "Windows PC"
{{bot_name}}               → "HELM" or user's chosen name
{{lifeline_bot_name}}      → "HELM Lifeline" or user's chosen name
{{onboarding_user_id}}     → user's Discord ID (for personalization)
```

The onboarding wizard captures these and renders all docs/templates for the user with the right values.

---

## Part 8: Multi-user onboarding sequence (engineer to build)

```
1. User runs: bash <(curl -s https://raw.githubusercontent.com/[helm-repo]/install.sh)
2. Install wizard prompts:
   - Operating system (auto-detect, confirm)
   - Main Discord bot token
   - Lifeline Discord bot token
   - VPS IP (or "I'll set up later")
   - Custom domain (optional, default: status.[vps-ip].sslip.io)
   - Site auth password (random-generated if user doesn't have one)
3. Wizard writes per-user config to ~/helm-config/user.yaml
4. Wizard generates personalized RECOVERY-AI-PROMPT.md (with user's context)
5. Wizard installs auto-start service (launchd/systemd/Task Scheduler) per OS
6. Wizard tests: bot starts, recovery webpage accessible, lifeline-bot responds
7. Output: "✅ HELM installed. Recovery URL: {{recovery_url}}. Pin this in Discord."
```

---

## Part 9: What gets backed up where

| Data | Source | Backup | Cadence | Recovery |
|---|---|---|---|---|
| HELM workspace files | Clean machine | GitHub repo | On commit | git pull |
| Bot config / secrets | Clean machine | 1Password vault | Manual | Re-enter at install |
| VPS app code | VPS | GitHub repo | On commit | git pull |
| VPS database | VPS | Clean machine ~/backups/vps/ | Daily 2:30am | Restore from .sql.gz |
| Off-device backup | Clean machine | private GitHub repo (vps-backups/) | Daily | git clone + apply |

`.env` files are NEVER backed up (they contain secrets). Rebuild from vault.

---

## Part 10: Confidence baseline (what user is told at onboarding completion)

```
✅ Your recovery system is installed and tested.

When HELM stops working:
1. Open {{mission_control_url}} → click "🛡️ Fix HELM" → automatic recovery
2. OR type !fix in any Discord channel → automatic recovery via Lifeline Bot
3. If both fail, power-cycle your {{machine_type}} → HELM auto-starts on boot
4. If still stuck: click "Get AI Help" on the recovery page → claude.ai prompt with your full system context

Verified working:
- Recovery webpage at {{recovery_url}}
- Lifeline bot responding to !status
- VPS→{{machine_type}} link healthy
- Auto-start configured ({{auto_start_mechanism}})
- Self-heal watchdogs running

Test it yourself: kill your bot process manually and verify it restarts.
```

---

## Part 11: Known gaps (be honest with users)

These ARE NOT YET FIXED. New users should know:

1. **Discord-down + clean-machine-down at the same time** → no out-of-band notification. Recommended fix: Twilio SMS or Mailgun email alerts on VPS dead-man's switch. Not built. (Estimated: ~2 hours including credential setup.)
2. **Recovery webpage requires browser + password** → if user has no browser or forgot password, only physical power-cycle works. Recommended: print/save a recovery card with URL + password location.
3. **Single clean machine = SPOF** → hardware failure means HELM is offline until repair. Documented bring-up procedure restores HELM on a new machine, but takes ~30 min.
4. **VPS auto-restart varies by provider** → Hostinger and DigitalOcean both have APIs; Linode requires manual web console. Wizard captures provider at onboarding.

---

## Authority level

This is **Level 3** — user-visible behavior change for new users, reversible. Onboarding workspace agent implements; {{USER_JERRY}} reviews next time he onboards a test user.

---

## Dependencies

- HELM-AUTO-RECOVERY-DESIGN.md (Level 4 — {{USER_JERRY}} approval needed for the cascade build)
- HELM-INSTALL-WIZARD spec (Level 4 — wizard with OS detection and per-user templating)
- Mission-control workspace integration (HELM-RECOVERY-WORKSPACE-INTEGRATION.md)
- Lifeline-bot rename in Discord Developer Portal (one-time {{USER_JERRY}} task)
