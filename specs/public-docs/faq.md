# HELM — Frequently Asked Questions

---

## General

**What is HELM?**
HELM is a self-hosted AI automation platform. It runs on your Mac, connects to your Discord server, and gives you a team of specialized AI agents that work on real tasks — not just chat.

**Is HELM a chatbot?**
Not really. HELM uses a Discord bot as its interface, but it's more like a coordination layer for a team of agents. Each agent has a specific job. Some are triggered by your messages; others run on schedules or watch for conditions.

**How is HELM different from using Claude or ChatGPT directly?**
HELM is persistent and autonomous — it keeps working between your messages. It has memory (your decisions, preferences, prior work), uses tools (file access, web fetching, cron jobs), and coordinates multiple specialized agents to accomplish complex tasks. It's less like a conversation partner and more like an AI team you manage.

**Do I need to be a developer to use HELM?**
No. The setup wizard handles configuration. Day-to-day use is just typing requests in Discord. You don't need to write code, edit config files, or understand how agents work.

**Is HELM free?**
HELM itself is open source and free. You'll pay for:
- Claude API usage (Anthropic — usage-based, typically $5–30/month for personal use)
- Your Mac Mini electricity (minimal)
- Optional VPS for web dashboards (not required, ~$5/month)

---

## Setup and Requirements

**What hardware do I need?**
A Mac Mini is ideal — it's always-on, low power, and quiet. Any Mac that can stay awake 24/7 works. A MacBook works but must have sleep disabled.

**Does HELM work on Linux or Windows?**
The current version is macOS-focused. Linux support is in progress. Windows support is planned (via WSL2).

**Can I run HELM on a cloud server (VPS)?**
Partially. The bot must run on a Mac because it relies on Claude CLI, which requires macOS Keychain for authentication. Web dashboards and supporting scripts can run on a VPS.

**Which Claude model does HELM use?**
HELM uses Claude Sonnet by default for judgment-heavy tasks and Claude Haiku for fast/routine operations. You can configure model preferences per agent type.

**What permissions does the Discord bot need?**
Send Messages, Read Message History, Manage Messages, Add Reactions, Embed Links, Pin Messages, Create Threads. All scoped to your server only.

---

## How It Works

**What are "agents"?**
Agents are specialized AI processes. Each agent has a defined role (engineer, product manager, curiosity interviewer, workspace builder, etc.) and follows a strict protocol for communicating with you. When you send a message, HELM routes it to the right agent for your intent.

**What are "workspaces"?**
Workspaces are focused environments for recurring tasks — like an ETF tracker or options analysis tool. Each workspace has its own Discord channel, its own agent configuration, and its own data. You can have multiple workspaces running in parallel.

**How does HELM handle my data?**
All data stays on your machine. HELM does not send your personal data to any server except the Claude API (for AI processing). The Claude API processes your messages to generate responses but does not store them persistently.

**Can HELM access the internet?**
Yes, agents can search the web, fetch URLs, and access external APIs when you give them a task that requires it. You control what capabilities each workspace uses.

**What happens when HELM is offline?**
HELM has a self-healing watchdog that restarts the bot if it stops responding. If the bot is completely offline (power outage, network failure), there's a recovery page at your configured recovery URL. The VPS (if configured) serves this page even when your Mac is down.

---

## Privacy and Security

**Is my data sent to Anthropic?**
Your messages are processed by Claude (Anthropic's AI) to generate responses. Anthropic processes these under their privacy policy. HELM does not add any additional data collection.

**Can anyone else access my HELM instance?**
No. Your Discord server is private and you control who joins. Your web dashboards are password-protected. Your Mac is on your local network.

**Where are my credentials stored?**
Credentials (Discord token, GitHub PAT) are stored in `~/helm/marvin-bot/.env` on your Mac with file permissions set to 600 — only your user account can read them. No cloud service or third-party password manager is required. Advanced users can optionally add 1Password integration.

---

## Troubleshooting Quick Reference

**Bot not responding** → Check [Troubleshooting guide](troubleshooting.md) — Start with the #helm-status channel. Green 🟢 = running. Red 🔴 = needs restart.

**Agent seems stuck** → Type "quick status" in the relevant channel. HELM will report what it's doing.

**Wrong channel routing** → Messages to #general get classified by intent. If routing is wrong, report it in #helm-improvements and it will be fixed.

**Setup wizard failed** → See [Troubleshooting guide](troubleshooting.md) for common install errors.
