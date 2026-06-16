# [ARCHIVED — Orchestrator removed 2026-06-10]
# HELM — Under the Hood: Architecture Guide (OUTDATED)
## For technically curious users who want to understand how the pieces fit together
## Draft: June 2026 (outdated — see specs/HELM-ARCHITECTURE-CURRENT.md for active design)

---

## THE BIG PICTURE

HELM is built from six interconnected layers:

1. **Command layer** — Discord receives your messages; bot.js routes them to the right agent
2. **Intelligence layer** — Claude (via your Anthropic subscription) does the thinking, writing, and building
3. **Coordination layer** — An orchestrator breaks large work into parallel sub-tasks
4. **Memory layer** — The second brain stores and retrieves what you know
5. **Governance layer** — Rules coded into every agent interaction keep behavior predictable
6. **Self-improvement layer** — Product Manager and Engineer agents observe patterns and update the system itself

These layers work together continuously. You interact with Layer 1. Everything else runs behind the scenes.

---

## 1. Discord + bot.js: Your Command Center

When you type a message in Discord, it doesn't go to Claude directly. It hits a server running Node.js — a lightweight piece of software called bot.js.

bot.js does several things immediately:
- Reads which channel the message came from and extracts its channel ID
- Decides which agent to route the message to (ETF tracker? Product Manager agent? Help agent?)
- Formats the request with context from that channel's saved state file
- Calls the Claude Code CLI with the right agent instruction file and context attached
- Posts the response back to Discord

This routing layer is what gives HELM its channel-based architecture. Each channel isn't just organizational — the channel ID is a routing signal that tells the system which specialized agent should handle the request.

bot.js also manages:
- Nightly restarts (changes queue and deploy at 2am to avoid mid-conversation interruptions)
- Watchdog heartbeats (if an agent goes silent, it gets woken up automatically every 60 seconds)
- Attachment handling (files dropped in Discord are saved to disk before the agent reads them)
- Discord's real-time event stream

---

## 2. The Orchestrator: How Complex Work Gets Coordinated

For tasks large enough to benefit from parallel execution, HELM uses an orchestrator (built on Mastra, an open-source agent framework).

When an agent decides a task needs orchestration — typically 4+ distinct, independent sub-tasks taking more than 15 minutes end-to-end — it emits a sentinel signal that bot.js intercepts. The orchestrator:

1. Expands the high-level request into discrete sub-tasks
2. Assigns each sub-task to the appropriate specialized agent
3. Manages dependencies (some tasks must run sequentially; others can run in parallel)
4. Aggregates results and delivers the final output

Without the orchestrator, one Claude session handles everything sequentially. With it, multiple agents can work on a problem simultaneously — the equivalent of a team instead of a solo developer.

---

## 3. The Second Brain: Knowledge That Compounds

Every link, note, screenshot, article, and conversation capture you share with HELM goes into a local knowledge base called QMD.

The design philosophy draws from the "Karpathy method" — Andrej Karpathy's approach to personal knowledge bases, which holds that your second brain should feel like a queryable extension of your own thinking, not a search engine you have to phrase perfectly. You capture things naturally; the system finds them meaningfully.

Technically, QMD is:
- A SQLite database with full-text search (FTS5) for fast keyword matching
- A vector embedding layer for semantic ("by meaning") search
- An LLM reranking pass that improves result quality for complex or ambiguous queries
- Local AI models (~2GB) that run entirely on your machine — no external calls for search

What this means in practice:
- You ask "what did I save about inflation hedging?" and QMD searches by meaning, not just keywords
- When HELM is building something, it runs a second brain search first to check what you already know about the topic
- Documents decay over time — recent, frequently-referenced content stays prominent; older content fades unless you keep using it

The second brain runs completely locally. Nothing about your saved knowledge is sent to any external service.

---

## 4. Steward: System Health and Maintenance

Steward is an agent that runs on a schedule (every Monday morning) to check in on the whole system.

What steward does:
- Runs a full health check across all active workspaces and system components
- Reviews the friction log for patterns — places where agents violated their own protocols
- Identifies issues that failed silently during the week
- Surfaces patterns to the Product Manager agent for prioritization
- Posts a health summary to your improvements channel for review

Steward is also responsible for keeping the system's capabilities list accurate. When a new tool or approach is confirmed working, steward records it. When something fails repeatedly, steward marks it in the "don't retry" section.

---

## 5. Product Manager + Engineer: How HELM Improves Its Own Code

This is the part most automation systems don't have.

HELM has two meta-level agents that work as a continuous improvement loop:

**The Product Manager agent** watches everything. It reads patterns in the friction log, monitors failures, tracks what users ask for, and surfaces the most valuable improvements. It doesn't just observe — it decides what to fix and sequences the work. Think CPO with full visibility into system behavior.

**The Engineer agent** implements the Product Manager's decisions. It literally opens bot.js, the agent instruction files, and the protocol files — and makes changes. Not "suggests changes" — makes them. It writes code, updates behavior rules, and commits to GitHub.

The loop:
1. Product Manager observes a pattern (e.g., "agents keep going silent on large API batches")
2. Product Manager writes a fix spec with acceptance criteria
3. Engineer implements it in bot.js or the agent files
4. Product Manager verifies the fix landed
5. The behavior improves — for all agents, including ones built in the future

This loop runs without you asking for it. The system you have in month 6 has been modified dozens of times. You didn't request any of it.

The Product Manager also learns from your direct feedback. When you tell HELM something isn't working the way you like — the tone is off, an agent keeps making the same mistake, a format feels wrong — it doesn't just log it. It identifies which behavior rule needs to change, writes the fix spec, and queues it for the Engineer. The system evolves toward how you want it to work, not just toward fewer errors.

---

## 6. Workspace Agents: How Custom Tools Get Built

Every tool HELM builds follows the same structured process — the BML (Build-Measure-Learn) loop.

1. **You describe the tool** in #new-workspace
2. A curiosity agent interviews you to clarify requirements and surface hidden assumptions
3. A scaffolder creates a dedicated workspace channel with all the files a new tool needs (spec, task list, capabilities reference, learnings file)
4. The workspace agent works through phases:
   - **Phase A:** Design and assumption mapping — what are we building, and what could go wrong?
   - **Phase B:** Short build loops, each testing exactly one assumption, each with explicit success criteria you can verify
   - **Phase C:** Polish, documentation, and deploy

Each phase requires your sign-off before the next begins. You're never surprised by what was built.

The workspace agent has full access to:
- A spec file (what it's building and why)
- A task list (what's done and what's next)
- A capabilities list (proven approaches to reuse, known failures to avoid)
- A learnings file (what this workspace discovered)
- Git (all changes committed and backed up automatically to GitHub)

When a workspace finishes, its learnings feed back into the shared capabilities list that all future workspaces read. Build 5 benefits from everything Build 1-4 figured out.

---

## 7. Self-Improvement: The System That Rewrites Itself

Most software changes when a developer writes code. HELM changes when it learns something.

The self-improvement pipeline:
1. An agent hits a problem → documents it in the friction log
2. Product Manager agent reads the friction log on its regular sweep
3. If the pattern recurs (same problem more than twice), it escalates to the engineer queue
4. Engineer agent reads the queue, implements the fix, and closes the item
5. Fix is committed to GitHub. Protocol and agent file changes take effect immediately; bot.js changes queue for the nightly 2am deployment.

Simultaneously, when an agent discovers a new technique that works reliably:
1. It writes the technique to CAPABILITIES.md
2. Future agents read CAPABILITIES.md before starting any new build
3. The technique propagates to all future workspaces automatically

This isn't hypothetical future-state. HELM has been modifying its own behavior protocols, agent instruction files, and bot.js logic since the beginning. The system learns its way to better behavior.

---

## 8. Clean Machine + Claude Desktop

HELM is designed to run on a clean, dedicated machine — not your daily computer. This isn't just for security; it's architectural.

Claude Desktop (Anthropic's desktop app) hosts the Claude Code sessions. When bot.js routes a message to an agent, it calls the Claude Code CLI, which runs the agent as a subprocess with full tool access: file read/write, bash execution, web search, and MCP (Model Context Protocol) integrations for external services.

The "clean machine" design means:
- HELM has access to a controlled, scoped file system — not your personal drive
- Credentials in the vault are explicitly scoped — HELM can only access what you've authorized
- Long-running processes work uninterrupted (no sleep mode, no session expiry)
- Recovery is clean: the system can be fully restored from its GitHub backup

---

## 9. Vault and Password Management

HELM stores all credentials in a vault — you share a single vault in your password manager with HELM, and that's all HELM can access. You decide what HELM can and cannot use.

How it works:
- When an agent needs a credential, it reads from the vault using a CLI command with an explicit reveal flag
- Credentials are never stored to disk, never hardcoded, never logged to output
- Every credential read is logged to an audit file with a timestamp, service name, and outcome
- If a vault read fails, the agent stops and blocks — no fallback to asking you to type a password
- Financial credentials are subject to additional rules: one login attempt, read-only scope only, immediate block on failure

The vault is auditable. You can see every time any agent accessed any credential.

---

## 10. External Connections: APIs and Integrations

HELM connects to external services through two mechanisms:

**MCP (Model Context Protocol)**: A standard protocol that gives Claude direct, structured access to external services. Current integrations include email, calendar, cloud drive, and others. These are the cleanest connections — Claude uses them like built-in tools rather than API wrappers.

**API credentials in vault**: For services without MCP support, HELM uses API keys stored in the vault. An agent reads the key, makes the API call, and the key is never exposed in output or logs.

Adding a new integration is typically: put the credential in the vault, and describe what you want HELM to do with it. The workspace agent handles the connection logic.

---

## 11. Rules Coded Into Interactions: The Governance Layer

HELM's behavior isn't just prompting. It's governance baked into every interaction.

Every agent runs with three mandatory files:
- **behaviors.md** — 21 required behaviors, each with a pass/fail gate
- **turn-protocol.md** — the exact format every message must take and what verification must happen before completion is claimed
- **CLAUDE.md** — workspace-specific rules and hard limits

Examples of coded rules:
- Before claiming a task is done, the agent reads the file it claims to have written and quotes the output
- Before recommending an approach, the agent checks the second brain and the capabilities list
- Every action is classified by stakes (0–5) and handled accordingly — from silent execution to explicit approval gate
- Financial operations have hardcoded limits that cannot be overridden, even if the user instructs otherwise
- Every DELIVER message must include a verification field, a pushback field, and a research field — bot.js rejects messages missing these

This is what makes HELM's behavior predictable. You're not relying on a language model to "try to be careful." The rules are written down, versioned in GitHub, and enforced programmatically.

---

## 12. Audit, Logging, and Recovery

Every significant action HELM takes is logged:
- **pap-audit.log** — all agent actions, decisions, and state changes
- **friction-log.md** — protocol violations and behavioral failures
- **decisions-log.md** — consequential decisions with rationale
- **engineer-queue.md** — pending improvements queued for the Engineer agent

Recovery is designed for the real world:
- All workspace configs, specs, and code are committed to GitHub nightly
- Channel state is written to a checkpoint file at the start of every multi-step task
- If the system restarts mid-task, it reads the checkpoint and resumes without starting over
- A watchdog monitors agent activity and wakes silent agents automatically every 60 seconds
- The full audit history is always available — every decision is traceable, every configuration is rollback-able

---

## 13. How Different Parts of Claude Get Used

HELM doesn't use one Claude model for everything. It picks the right capability for each job:

| Task | Claude capability |
|---|---|
| Routing, status checks, validation | Claude Haiku — fast, cheap, accurate |
| Agent work, building, writing | Claude Sonnet — best balance (default) |
| Major architectural decisions | Claude Opus — only for high-stakes decisions |
| Repeated system prompt delivery | Automatic prompt caching — verified working, reduces cost significantly |
| Tool use | Every agent uses structured tool calls (file read/write, bash, web search, MCP) |
| Complex reasoning | Extended thinking available for multi-step analysis |
| Large parallel workloads | Multiple sub-agents spawned by the orchestrator |
| Memory + retrieval | Local LLM reranking in QMD (runs on-device) |

---

## What We Haven't Covered (And Should)

A few additional architectural elements worth knowing:

**The authority scale as a safety model**: Every action HELM takes is classified 0–5 by stakes. Levels 0–2 execute silently; Level 3 executes and notifies; Levels 4–5 require explicit approval before execution. This isn't a preference — it's enforced in every agent's instruction file.

**Channel routing logic**: bot.js maintains a routing table that maps channel IDs to agent types. New workspaces get scaffolded with their own channel, which is automatically wired to the workspace agent on creation.

**Git as the backbone**: Every workspace, every config file, and every agent instruction file is committed to a private GitHub repo nightly. This is the recovery layer — HELM can be rebuilt from Git alone if something goes catastrophically wrong.

**The BML loop applied to HELM itself**: The same Build-Measure-Learn process that governs workspace development also governs the system's own improvement. Every protocol fix goes through the same assumption → test → verify → commit cycle.
