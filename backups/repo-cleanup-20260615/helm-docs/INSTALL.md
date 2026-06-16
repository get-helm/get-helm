# Installing HELM

HELM runs on a Mac mini (always-on) and optionally a VPS for cloud tasks. This guide covers the standard single-machine setup.

---

## Requirements

- Mac (macOS 13+) or Linux
- Discord account + ability to create a Discord server
- Node.js 18+
- Claude account (claude.ai subscription)

Optional (for cloud tasks):
- A VPS (Linux, 1GB+ RAM)
- A domain name (for hosting automation outputs)

---

## Quick Install

```bash
# Download HELM
curl -O https://raw.githubusercontent.com/{{USER_GITHUB}}/helm-config/main/helm-install.sh

# Run installer (interactive)
bash helm-install.sh
```

The installer will:
1. Check prerequisites
2. Ask you to create a Discord server (or use an existing one)
3. Set up your HELM agent (Claude) credentials
4. Create your workspace directory
5. Start the HELM service

---

## What Gets Installed

| Component | Location | Description |
|---|---|---|
| Bot service | `~/marvin-bot/bot.js` | Discord bot (runs as background service) |
| Workspace | `~/helm-workspace/` | Your configs, preferences, workspace data |
| Scripts | `~/marvin-bot/*.sh` | Automation helper scripts |
| Agent files | `~/.claude/agents/` | HELM agent definitions |

---

## First Run

After install, HELM will:
1. Start the Discord bot
2. Post a welcome message in your server
3. Walk you through a 5-step onboarding to set preferences
4. Create your #preferences channel with your settings
5. You're ready to send your first proposal

---

## Updating HELM

```bash
bash ~/marvin-bot/helm-update.sh
```

This pulls the latest HELM files from the config repo without touching your personal data or workspace files.

---

## Uninstalling

```bash
bash ~/marvin-bot/helm-uninstall.sh
```

This removes the bot service and HELM files. Your workspace data is preserved by default. Add `--delete-workspaces` to remove everything.

---

## Troubleshooting Installation

**"Node.js not found"** — Install Node.js 18+: `brew install node` (Mac) or `apt install nodejs npm` (Linux)

**"Claude credentials failed"** — Make sure you have an active claude.ai account. HELM uses the Claude Code CLI.

**"Discord bot failed to connect"** — Check your Discord bot token. See the installer output for specific instructions.

For other issues, see [GUIDE.md#troubleshooting](GUIDE.md#troubleshooting) or open an issue.
