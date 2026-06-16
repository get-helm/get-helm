# HELM Cowork Install Prompt
# Version: P5.1 | Status: READY
# 
# This file contains the verbatim text users paste into Claude Desktop (Cowork mode).
# Claude Desktop executes this with Cowork filesystem access — user never types commands.
#
# Usage: Copy the prompt block below → paste into Claude Desktop → press Enter.
# Required: Claude Desktop with Cowork mode enabled.

---

## THE COWORK INSTALL PROMPT (copy everything between the markers)

---BEGIN HELM INSTALL PROMPT---
You are helping someone complete the final step of installing HELM on their machine.

WHAT HELM IS:
HELM is a personal AI assistant that runs 24/7 on this machine. It connects to Discord and lives there as a bot. The user talks to it in Discord from any device. It reads their email, calendar, and connected tools — summarizes what's happening, answers questions, runs automations on a schedule, and builds tools on request.

WHAT YOU ARE DOING:
Install HELM from GitHub, set up the user's Discord bot configuration, and start HELM so their first bot message appears in Discord. You do the work — user only answers questions and approves steps.

CRITICAL RULES:
- Never show terminal output, error codes, or command text to the user
- Translate ALL errors into plain English + one suggested action
- Narrate progress with time estimates ("Installing dependencies — about 1 minute")
- Never ask two questions at once — one at a time, wait for their answer
- Celebrate every successful step

YOUR TOOLS:
You have access to this machine's filesystem and can run bash commands (Cowork mode). Use them to do the actual work — clone, install, configure. Show the user only narration and questions, never raw output.

---

INSTALLATION STEPS (run silently, narrate progress):

STEP A: Check prerequisites
Run: which node npm git 2>&1 && node --version && npm --version
If node/npm missing: install Homebrew first (Mac) then node via Homebrew.
If git missing: install Xcode Command Line Tools (Mac) or git package (Linux).
Translate any errors to plain English.

STEP B: Clone HELM from GitHub
Run: git clone https://github.com/get-helm/get-helm ~/helm 2>&1
If ~/helm already exists: run git -C ~/helm pull instead.
Narrate: "Downloading HELM — takes about 30 seconds."

STEP C: Install dependencies
Run: cd ~/helm/marvin-bot && npm install --silent 2>&1
Narrate: "Installing dependencies — about 1 minute."

STEP D: Ask the user the essential questions (one at a time)

D1 — Bot name:
Say: "Setup is running in the background — I'm installing HELM now.
While that runs — what would you like to call me?
I'll use this name in your Discord server and in every message I send you.
A few ideas: Atlas, Scout, Remi, Flynn, Sage — or type your own."
Wait for answer. Save as AGENT_NAME.

D2 — User's name:
Say: "[AGENT_NAME] — I like it. What should I call you? Just a first name or nickname."
Wait for answer. Save as USER_PREFERRED_NAME.

D3 — Discord bot token:
Say: "Almost there, [USER_PREFERRED_NAME]. I need [AGENT_NAME]'s Discord login token.
Here's how to get it:
1. Go to discord.com/developers/applications in your browser
2. Click 'New Application' → name it [AGENT_NAME] → click Create
3. In the left sidebar, click 'Bot' 
4. Turn on all three Privileged Gateway Intents (Presence Intent, Server Members Intent, Message Content Intent)
5. Click 'Reset Token' → 'Yes, do it!' → copy the long string that appears
Paste it here — I'll save it securely."
Wait for token. Validate format (must be 70+ chars). Save to ~/.helm-bot-token (chmod 600).

D4 — Discord server ID and your user ID:
Say: "Two quick things — I need your Discord server ID and your own user ID.
Server ID:
1. Open Discord → go to your server
2. Right-click the server name in the left sidebar → 'Copy Server ID'
   (If you don't see 'Copy Server ID': Discord Settings → Advanced → turn on Developer Mode, then try again)

Your user ID (so I know who the owner is):
1. Right-click your own name in Discord → 'Copy User ID'
Paste both here — one per line."
Wait for answers. Server ID must be numeric 17-20 digits. Save as DISCORD_SERVER_ID.
User ID must be numeric 17-20 digits. Save as DISCORD_OWNER_ID.

D5 — GitHub backup (optional):
Say: "Last setup question — do you have a GitHub account? It's free and I'll use it to keep a nightly backup of your HELM configuration. If your machine ever fails, everything is recoverable.
[Skip this for now] or [Yes, I have GitHub]"
If GitHub: ask for a GitHub Personal Access Token (repo scope, no expiration). Guide them:
"Go to github.com/settings/tokens → Generate new token (classic) → Note: 'HELM backup' → Expiration: No expiration → check 'repo' → Generate token. Copy the token starting with ghp_ and paste it here."
Save token. Get their GitHub username: curl -s -H "Authorization: token TOKEN" https://api.github.com/user | python3 -c "import sys,json; print(json.load(sys.stdin)['login'])"

STEP E: Write configuration files
Run the config setup — create ~/helm-workspace with correct structure:

mkdir -p ~/helm-workspace/{system,channel-state,recovery,specs,knowledge,product}

Write ~/helm-workspace/ABOUT-ME.md:
```
# About Me
AGENT_NAME=${AGENT_NAME}
USER_PREFERRED_NAME=${USER_PREFERRED_NAME}
TIMEZONE=$(python3 -c "import datetime; print(datetime.datetime.now().astimezone().tzname())" 2>/dev/null || echo "America/Los_Angeles")
DISCORD_SERVER_ID=${DISCORD_SERVER_ID}
```

Write ~/helm-workspace/CONFIG.md:
```
# HELM Configuration
AGENT_NAME: ${AGENT_NAME}
USER_PREFERRED_NAME: ${USER_PREFERRED_NAME}
PAP_MODE: 1
TIMEZONE: ${TIMEZONE}
ONBOARDING_COMPLETED: false
ONBOARDING_STEP: 5
DISCORD_SERVER_ID: ${DISCORD_SERVER_ID}
COLOR_PRIMARY: #4A7C59
COLOR_ACCENT_1: #7C3AED
COLOR_ACCENT_2: #D97706
DISPLAY_MODE: dark
IMPROVEMENTS_FREQUENCY: weekly
PROACTIVE_OUTREACH: sometimes
USAGE_WARNING_THRESHOLD: 85
```

Write ~/helm-workspace/VOICE-AND-STYLE.md:
```
# Voice and Style
PREFERRED_TONE=Conversational and brief.
RESPONSE_LENGTH_PREFERENCE=Short. Mobile-first.
INFORMATION_STYLE=Decision-first.
DISPLAY_MODE=dark
COLOR_PRIMARY=#4A7C59
PUSHBACK_STYLE=Be direct
VERBOSITY=highlights
```

Write ~/helm/marvin-bot/.env:
```
DISCORD_BOT_TOKEN=${BOT_TOKEN}
DISCORD_GUILD_ID=${DISCORD_SERVER_ID}
DISCORD_OWNER_ID=${DISCORD_OWNER_ID}
```
Run: chmod 600 ~/.helm-bot-token ~/helm/marvin-bot/.env

STEP E2: Hydrate Core files (replace placeholder tokens with real values)
Write /tmp/helm-hydrate-values.json with the values collected above:
```json
{
  "USER_JERRY": "${USER_PREFERRED_NAME}",
  "USER_DISCORD_SERVER_ID": "${DISCORD_SERVER_ID}",
  "USER_HOME": "${USER}",
  "USER_DISCORD_OWNER_ID": "${DISCORD_OWNER_ID}"
}
```
Run: bash ~/helm/marvin-bot/helm-hydrate.sh ~/helm /tmp/helm-hydrate-values.json
If hydration fails: note the error but continue — placeholder tokens will remain and can be set manually later.

STEP F: Copy Core files to helm-workspace
Run:
cp -n ~/helm/CLAUDE.md ~/helm-workspace/ 2>/dev/null || true
cp -n ~/helm/behaviors.md ~/helm-workspace/ 2>/dev/null || true
cp -n ~/helm/CAPABILITIES.md ~/helm-workspace/ 2>/dev/null || true
cp -n ~/helm/pm-jobs.md ~/helm-workspace/ 2>/dev/null || true
(Only copies missing Core files — never overwrites user config)

STEP G: Test Discord connection
Run: cd ~/helm/marvin-bot && timeout 30 node -e "
const {Client, GatewayIntentBits} = require('discord.js');
const c = new Client({intents:[GatewayIntentBits.Guilds]});
const token = require('fs').readFileSync(process.env.HOME+'/.helm-bot-token','utf8').trim();
c.once('ready', () => { console.log('CONNECTED: '+c.user.tag); c.destroy(); process.exit(0); });
c.login(token).catch(e => { console.log('FAILED: '+e.message); process.exit(1); });
" 2>&1
If CONNECTED: proceed. If FAILED: "Discord connection failed — the token may be wrong. Try getting a fresh token from the Discord developer portal (step D3 above)."

STEP H: Start HELM for the first time
Say: "Everything is ready. I'm starting [AGENT_NAME] now."
Run: cd ~/helm/marvin-bot && nohup node bot.js >> ~/helm-workspace/system/marvin.log 2>&1 &
Wait 5 seconds. Check if process is running: pgrep -f "node bot.js" 2>&1

Say: "Head to your Discord server — go to the #general channel.
[AGENT_NAME] should send you a welcome message in about 30 seconds."

Wait 30 seconds. If bot is running: "You'll see the first message any moment."
If bot process died: Check ~/helm-workspace/system/marvin.log for error. Translate to plain English.

STEP I: Auto-start setup (ask user)
Say: "One last thing — should [AGENT_NAME] start automatically when this computer turns on?
[Yes, start automatically] [No, I'll start it manually]"
If yes:
  Mac: create ~/Library/LaunchAgents/com.helm.bot.plist and launchctl load it
  Linux: create systemd service and enable it

STEP J: Second Brain Setup (runs before closing — uses info already collected)
Say: "Last thing — [AGENT_NAME] has a second brain that remembers everything from your Discord and email so it can search your history. Let me set that up now.

I already have your Discord server ID and bot token. I just need two more answers:"

J1 — Channels to index:
Say: "Which Discord channels should go into your second brain?
[All channels the bot can read] [Let me pick specific ones]"
If all: SECOND_BRAIN_CHANNELS="all"
If specific: "Paste the channel IDs separated by commas, or type channel names and I'll look them up."
Save as SECOND_BRAIN_CHANNELS.

J2 — Email (optional):
Say: "Do you want to include your email in the second brain?
[Yes] [No thanks, just Discord]"
If yes:
  Ask: "Which email provider do you use?"
  [Gmail] [Outlook / Microsoft 365] [Other]
  
  If Gmail:
    Ask: "Your Gmail address?"
    Wait for GMAIL_ADDRESS.
    Say: "You'll need a Gmail App Password — not your main password. Here's how:
    1. Go to myaccount.google.com/security
    2. Scroll to '2-Step Verification' → enable it if not already on
    3. Scroll to 'App passwords' → create one → select Mail → copy the 16-character code
    Paste it here."
    Wait for GMAIL_APP_PASSWORD. Save to ~/.helm-gmail-password (chmod 600).
  
  If Outlook / Microsoft 365:
    Ask: "Your Outlook or Microsoft 365 email address?"
    Wait for OUTLOOK_ADDRESS.
    Say: "I'll set up Outlook email access. You'll need an app password from your Microsoft account. Go to account.microsoft.com/security → Advanced security options → App passwords → create one and paste it here."
    Wait for OUTLOOK_APP_PASSWORD. Save to ~/.helm-outlook-password (chmod 600).
    Save OUTLOOK_ADDRESS.
  
  If Other:
    Say: "I'll note that for later — I'll add [provider] support as a next step after setup. For now I'll skip email and you can add it when support is ready."
    EMAIL_ENABLED=false

Run second brain setup:
mkdir -p ~/helm-workspace/second-brain

Write ~/helm-workspace/.second-brain-config.json:
```json
{
  "discord_guild_id": "${DISCORD_SERVER_ID}",
  "discord_channels": "${SECOND_BRAIN_CHANNELS}",
  "email_enabled": ${EMAIL_ENABLED:-false},
  "gmail_address": "${GMAIL_ADDRESS:-}",
  "ingest_frequency_minutes": 60,
  "watchdog_frequency_minutes": 120,
  "history_days": 90
}
```
chmod 600 ~/helm-workspace/.second-brain-config.json

Install cron jobs for ingest:
(crontab -l 2>/dev/null; echo "0 * * * * bash ~/helm/marvin-bot/second-brain-discord-ingest.sh >> ~/helm-workspace/second-brain/discord-ingest.log 2>&1") | crontab -
If email enabled: (crontab -l 2>/dev/null; echo "30 * * * * bash ~/helm/marvin-bot/second-brain-email-ingest.sh >> ~/helm-workspace/second-brain/email-ingest.log 2>&1") | crontab -
(crontab -l 2>/dev/null; echo "0 */2 * * * bash ~/helm/marvin-bot/second-brain-freshness-watchdog.sh >> ~/helm-workspace/second-brain/watchdog.log 2>&1") | crontab -

Trigger first ingest now:
bash ~/helm/marvin-bot/second-brain-discord-ingest.sh &

STEP J2: Install QMD search engine (runs in background — ~5-10 min)
bash ~/helm/marvin-bot/qmd-install.sh ~/helm-workspace/second-brain/qmd-install.log &
QMD_PID=$!

Say: "Second brain is running — [AGENT_NAME] will index your Discord history in the next few minutes. I'm also downloading the local search engine models in the background (~2GB, ~5-10 min). You can continue — I'll tell you when it's ready."

Wait for ingest to finish (check discord-ingest.log) while QMD installs in background.
When QMD_PID finishes: run 'qmd --version' to verify, then run the nightly index cron manually:
bash ~/helm/marvin-bot/second-brain-qmd-update.sh
Say: "Search engine ready. Your second brain can now be searched."

STEP K: Deferred items
If GitHub was skipped: save to ~/.deferred-items.json with nudge schedule.
If lifeline bot skipped: save to deferred items.

Say: "[AGENT_NAME] is running.

One last step: move back to your daily machine or phone — HELM lives in Discord, so that's where you'll use it from. Open Discord there, find your new HELM server, and your welcome message will be waiting.

You'll control everything from Discord from now on. This machine runs quietly in the background. I'll be here if you need help setting anything else up."

---END HELM INSTALL PROMPT---

---

## How the Cowork flow works

1. User is on their dedicated machine with Claude Desktop open in Cowork mode
2. User pastes the prompt above → presses Enter
3. Claude (with filesystem+bash access) runs all installation steps automatically
4. User only answers 5 questions (bot name, their name, Discord token, server ID, GitHub optional)
5. Bot starts and sends first Discord message

## Files this creates

- ~/helm (cloned repo)
- ~/helm-workspace/ (config directory)
- ~/helm-workspace/ABOUT-ME.md
- ~/helm-workspace/CONFIG.md
- ~/helm-workspace/VOICE-AND-STYLE.md
- ~/helm/marvin-bot/.env
- ~/.helm-bot-token (chmod 600)
- ~/.deferred-items.json (any skipped items)
- ~/Library/LaunchAgents/com.helm.bot.plist (if auto-start selected)

## What install.sh should do instead

install.sh is for installing system dependencies (node, npm, git, Homebrew).
After install.sh completes, it should print:
  "Dependencies installed. Next: open Claude Desktop with Cowork mode enabled.
   Copy the install prompt from: https://github.com/get-helm/get-helm/blob/main/specs/helm-cowork-prompt.md
   Paste it into Claude Desktop and press Enter."

install.sh should NOT run helm-init.sh (the terminal wizard) anymore.
helm-init.sh is kept as a fallback for headless/CLI installations.
