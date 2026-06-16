# HELM Architecture Overview

This document explains how HELM works under the hood. You don't need to understand this to use HELM — it's here for curious users and contributors.

---

## System Overview

```
Discord (your interface)
    ↓
Bot.js (message router, running on your Mac)
    ↓
Agent dispatcher (picks the right agent for your intent)
    ↓
Specialized agents (Claude CLI processes)
    ↓
Work output → Discord + local files
```

HELM's bot (bot.js) runs permanently on your Mac as a macOS service. It connects to Discord's WebSocket API and listens for messages. When you send a message, the bot classifies your intent, spawns the appropriate agent, and that agent does the work.

---

## Components

### 1. Bot.js (The Coordinator)

The bot is a Node.js process that:
- Maintains a persistent WebSocket connection to Discord
- Routes messages to the correct agent based on channel and intent classification
- Tracks agent state (which channel has an active agent, what phase they're in)
- Enforces protocol rules (monitors for agents that go silent, validates DELIVER schema)
- Handles Discord UI interactions (buttons, dropdowns, modals)

Bot.js does not do any AI processing itself. It's the traffic cop between Discord and the agents.

### 2. Agents (The Workers)

Agents are Claude CLI processes spawned on-demand. Each agent:
- Has a specific role defined in a markdown file (`~/.claude/agents/[name].md`)
- Gets injected context (your preferences, workspace state, relevant memory)
- Does work by calling tools (read/write files, run bash commands, search the web, call APIs)
- Reports progress to Discord at a declared cadence
- Posts a structured DELIVER when done

Current agents:
- **dispatcher** — routes incoming messages, never handles tasks directly
- **help** — answers questions, handles feedback
- **curiosity** — interviews you to understand a new project or idea
- **scaffolder** — creates new workspace folders and configs
- **engineer** — improves HELM itself (self-improvement loop)
- **product-manager** — monitors system health, queues improvements, proactive sweep
- **workspace agents** — one per workspace (ETF tracker, options helper, daily brief, etc.)

### 3. Channel State

HELM uses a JSON file per Discord channel to track state:
```
~/helm-workspace/channel-state/[channelId].json
```

This file stores:
- Active agent PID and last phase marker
- Checkpoint (current task, progress, notes)
- Last message timestamps

This is how HELM resumes correctly after restarts — it reads the checkpoint, not the message history.

### 4. Task Registry

All engineer tasks are tracked in:
```
~/helm-workspace/task-registry.jsonl
```

One JSON line per event (queued → in_progress → done). This is the source of truth for what's been built and what's in progress.

### 5. Event Stream

```
~/helm-workspace/event-stream.jsonl
```

Every significant system event is appended here (agent spawned, DELIVER posted, violation detected, etc.). The product manager reads this during sweeps to understand system behavior.

### 6. Friction Log

```
~/helm-workspace/system/friction-log.md
```

When agents violate protocol rules (take too long, skip required fields, claim work without verifying), violations are logged here silently. The PM reviews patterns weekly and queues fixes via the engineer.

---

## The Self-Improvement Loop

HELM improves itself through a continuous loop:

```
1. PM sweeps (every few hours) detect friction patterns
2. PM queues fixes in engineer-queue.md
3. Nightly engineer batch processes the queue
4. Changes are deployed via bot.js restart at 2am PT
5. Steward reports weekly on what improved
```

This is how HELM gets smarter over time without you doing anything — it's the product-manager agent's primary job.

---

## Message Routing

When you send a message to #general, the routing logic is:

1. **Intent classification** — Is this exploratory/conversational, or action-oriented?
2. **Channel context** — Are you in a workspace channel? A special channel?
3. **Agent selection** — Maps (intent × channel) → agent name
4. **Dispatch** — Bot spawns Claude CLI with the agent's markdown file + context

Routing rules (simplified):
- Workspace channel → workspace agent
- #general + idea/build request → curiosity agent
- #general + question/help → help agent
- #helm-improvements → product-manager agent
- #capture → connector agent

### Agent communication protocol

Every agent message starts with a phase marker:
- 👍 **ACK** — "I got your request, here's my estimate"
- ⏳ **UPDATE** — "Still working, here's what I found"
- ⏸ **BLOCK** — "I'm stuck, I need your input"
- ✅ **DELIVER** — "Done, here's what I did"

This protocol makes agent behavior predictable and lets the bot detect when agents go wrong (no update after expected time = silent kill + restart).

---

## Storage Model

| What | Where | Format |
|------|-------|--------|
| Channel state | channel-state/[id].json | JSON per channel |
| Task history | task-registry.jsonl | JSONL append-only |
| System events | event-stream.jsonl | JSONL append-only |
| Agent config | ~/.claude/agents/*.md | Markdown |
| Workspace files | workspaces/[name]/ | Mixed |
| Credentials | ~/helm/marvin-bot/.env | chmod 600, file permissions |
| Logs | system/helm-audit.log | Plaintext append |

---

## Security Model

- **Local only** — Bot.js runs on your Mac, on your network
- **Credentials in .env** — Secrets stored in `~/helm/marvin-bot/.env` (chmod 600); file-permission protected
- **Sandboxed agents** — Each agent runs as a CLI subprocess; cannot access other processes
- **Discord auth** — Bot token scoped to your server; no cross-server access
- **Web dashboards** — Password-protected via nginx auth; credentials in vault
- **VPS** — SSH key-based auth only; no password login

---

## Deployment Architecture

```
Mac Mini (always-on)
├── bot.js (main Discord bot, launchd service)
├── lifeline-bot.js (recovery watchdog bot)
├── helm-selfheal.sh (30s watchdog cron)
└── claude CLI (spawned per agent request)

VPS (187.xxx.xxx.xxx)
├── nginx (reverse proxy + SSL)
├── recovery-server.py (emergency recovery page)
└── web dashboards (etf, options, etc.)
```

The Mac Mini is primary. The VPS serves the recovery page and static web dashboards. If the Mac Mini goes down, you can use the VPS recovery page to restart the bot remotely once the Mac is back online.

---

## Contributing

HELM is designed to improve itself, but external contributions are welcome. Key areas:
- Additional agent specializations
- New workspace templates
- Linux/Windows compatibility (in progress)
- Web dashboard templates

See the [GitHub repository](https://github.com/get-helm/helm) for contribution guidelines.
