# Getting Started with HELM

This guide gets you from zero to a working HELM installation in about 30 minutes.

---

## Prerequisites

Before you start, you need:

1. **Mac Mini or always-on Mac** — HELM's bot runs here 24/7. A MacBook works but must stay awake.
2. **Discord account** — Create a free account at discord.com if you don't have one.
3. **Discord server** — You'll need your own server (not someone else's). Create one from the Discord app: click the + button in the server sidebar → "Create My Own."
4. **Discord bot token** — You'll create this during setup (step 2 below).
5. **Homebrew** — macOS package manager. Install at brew.sh if not already installed.
6. **Node.js 18+** — Installed via Homebrew: `brew install node`

---

## Step 1: Clone the HELM repository

```bash
git clone https://github.com/get-helm/helm.git ~/helm-workspace
cd ~/helm-workspace
npm install
```

---

## Step 2: Create your Discord bot

1. Go to [discord.com/developers/applications](https://discord.com/developers/applications)
2. Click **New Application** → name it anything (e.g. "Marvin")
3. Go to **Bot** → click **Add Bot**
4. Under **Token**, click **Reset Token** and copy the token — you'll need it in step 4
5. Under **Privileged Gateway Intents**, enable:
   - Server Members Intent
   - Message Content Intent
6. Go to **OAuth2 → URL Generator** → check `bot` and `applications.commands`
7. Under Bot Permissions, check: Send Messages, Read Message History, Manage Messages, Add Reactions, Embed Links, Pin Messages
8. Copy the generated URL, paste it in your browser, and add the bot to your server

---

## Step 3: Run the setup wizard

Open **Claude Desktop** in Cowork mode. Copy the install prompt from `~/helm/marvin-bot/specs/helm-cowork-install-prompt.md` and paste it into Claude Desktop. Press Enter.

Claude will walk you through:
- Entering your Discord bot token
- Entering your Discord server ID (right-click your server name → Copy Server ID)
- Choosing your timezone
- Setting up the channel structure in your Discord server
- Starting HELM as a background service

Setup takes about 10 minutes. Claude asks one question at a time in plain English — no config file editing required.

---

## Step 4: Say hello

Once the wizard finishes, open Discord. You should see HELM's channels created in your server. Type anything in **#general** — HELM's bot will respond.

Try:
- "What can you do?" — lists available capabilities
- "Run /tour" — starts the 5-step onboarding tour
- "Set up my morning briefing" — starts the briefing workspace

---

## Your first 5 minutes with HELM

1. **#general** — your main channel for requests and conversation
2. **#helm-improvements** — where agents report decisions and ask for your input
3. **#helm-status** — system health (🟢 = running, 🔴 = needs attention)
4. **#helm-audit** — automated logs (you don't need to read this daily)

When an agent is working on something for you, it will post progress updates in the relevant channel. You don't need to babysit it — just check back when you get a notification.

---

## What's next?

- Set up your first workspace (try asking "help me track my ETF portfolio")
- Configure your morning briefing (ask "set up a daily briefing for me")
- Explore preferences (ask "show me my preferences")

→ [Full Architecture Overview](architecture.md) — understand how HELM works  
→ [FAQ](faq.md) — common questions  
→ [Troubleshooting](troubleshooting.md) — when things go wrong
