# HELM Technical Reference

## Architecture

HELM has three layers:

1. **Discord bot** (bot.js) — receives messages, routes to agents, manages workspace channels
2. **Claude agents** (`.claude/agents/*.md`) — the "brains" that handle tasks
3. **Scripts** (`~/marvin-bot/*.sh`) — helper scripts for data, APIs, Discord

### How a Message is Processed

1. You type `@HELM build me a daily digest`
2. Discord bot receives the message
3. Dispatcher agent reads the message and decides which agent handles it
4. Agent spawns (curiosity for new ideas, help for questions, etc.)
5. Agent does the work, posts results

---

## Data Storage

### Where Your Data Lives

| Data type | Location | Notes |
|---|---|---|
| Preferences | `~/helm-workspace/ABOUT-ME.md` + `VOICE-AND-STYLE.md` | Plain text, editable |
| Workspace state | `~/helm-workspace/workspaces/[name]/` | One folder per workspace |
| Bot logs | `~/marvin-bot/marvin.log` | Rotated daily |
| System state | `~/helm-workspace/system/` | PM logs, decisions, metrics |

HELM does not store your data in any cloud service. Everything stays on your machine.

### What HELM Sends Externally

- API calls to services your automation uses (e.g., Tiingo for stock prices)
- Claude API calls (for agent intelligence) — these include conversation context
- Discord API calls (to post messages)

---

## Security

### Credentials

HELM stores credentials in 1Password (PAP Vault). Credentials are:
- Never written to files
- Read-only where possible
- Masked in all logs (last 4 digits of account numbers only)
- One login attempt per session (no retry loops)

### Personal Data Rules

- Account numbers: always masked to last 4 digits
- Financial data: never published to unauthenticated locations
- Workspace data: local only (not synced to external services)

### Network

- HELM uses HTTPS for all external calls
- Discord bot uses Discord's official API
- No incoming network connections required (no open ports needed for basic use)

---

## Agent System

HELM uses Claude agents for different tasks:

| Agent | Role |
|---|---|
| dispatcher | Routes messages to correct agent |
| curiosity | Handles new workspace proposals |
| scaffolder | Creates workspace files and channels |
| help | Answers questions |
| product-manager | Orchestrates work, proactive planning |
| engineer | Builds HELM improvements |
| preferences | Handles `@HELM set` commands |
| security | Scans files and links |

---

## Channel Structure

| Channel | Purpose |
|---|---|
| #general | Main conversation with HELM |
| #new-workspace | Create a new workspace |
| #preferences | View and change settings |
| #helm-status | System health and recovery |
| #[workspace-name] | Per-automation workspace channels |

---

## Configuration Files

| File | Purpose |
|---|---|
| `CLAUDE.md` | Master HELM instructions |
| `behaviors.md` | Required behavior rules |
| `ABOUT-ME.md` | Your profile (name, timezone, role) |
| `VOICE-AND-STYLE.md` | Communication preferences |
| `CONFIG.md` | System configuration (domain, channels) |
| `channel-registry.json` | Channel ID registry |
| `PARTITION.json` | Manifest of Core/User/Runtime files |

---

## Commands Reference

See [GUIDE.md#commands](GUIDE.md#commands) for the full command list.

### Internal Commands (in #helm-status)

| Command | Effect |
|---|---|
| `!force-restart` | Restart the HELM bot |
| `!status` | Show bot health |
| `!version` | Show HELM version |
