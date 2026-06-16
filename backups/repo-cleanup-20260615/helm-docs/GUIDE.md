# HELM User Guide

## Table of Contents

- [Phases](#phases)
- [Proposals](#proposals)
- [Workspaces](#workspaces)
- [Commands](#commands)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq)

---

## Phases

HELM builds every automation in four phases. Each phase has a specific goal, and you control when to move forward.

### Planning

HELM talks to you, asks questions, and designs the solution. Nothing is built yet. You decide whether the plan looks right.

**What happens:**
- HELM confirms it understands your goal
- It maps out what it needs to build
- It identifies the riskiest parts to test first
- It shows you the plan

**What you do:** Review the plan. Say yes to start building, or ask for changes.

**How long:** Usually 15–30 minutes of conversation (async — HELM doesn't need you to be present).

---

### Building & Testing

HELM builds the automation in small loops. Each loop tests one assumption. You see results after each loop.

**What happens:**
- HELM builds a rough version and tests it
- It shows you what worked and what didn't
- It fixes issues before moving on
- It repeats until the core functionality works

**What you do:** Review results when HELM asks. Answer questions if it gets stuck.

**How long:** 2–8 hours depending on complexity (HELM works in the background; you're only involved when needed).

---

### Refining

Once the automation works, HELM makes it reliable and efficient. Speed, accuracy, edge cases.

**What happens:**
- HELM tests with real data
- It handles errors gracefully
- It optimizes for your schedule and preferences
- It confirms everything works end-to-end

**What you do:** Minimal. Approve the final output format if needed.

**How long:** 1–4 hours.

---

### Live

Your automation runs on its own. HELM monitors it and handles issues.

**What happens:**
- Automation runs on your defined schedule
- HELM watches for errors and fixes them
- You get output in your preferred format
- Nothing required from you unless something unusual happens

**What you do:** Enjoy the output. Ask HELM to change anything that doesn't feel right.

---

## Proposals

A proposal is HELM's plan for an automation. You see it before anything is built.

### What a Proposal Includes

1. **Goal confirmation** — what HELM understood you want
2. **Design** — how it plans to build it
3. **Assumptions** — what HELM is assuming (you can correct these)
4. **First test** — what it'll validate first
5. **Timeline** — rough estimate

### How to Respond to a Proposal

- Say **yes** or **start building** to approve
- Say **no** or describe what's wrong to refine
- Ask questions — HELM will answer before building
- Say **cancel** to drop the idea

---

## Workspaces

Every automation has its own workspace channel in Discord.

### What You See in a Workspace

- Pinned status message (phase, current step, last update)
- HELM's updates as it builds and runs
- Results and output
- Questions when HELM needs your input

### Managing a Workspace

In the workspace channel:
- `@HELM status` — see current state
- `@HELM pause` — pause the automation
- `@HELM resume` — resume after pausing
- `@HELM cancel` — stop and archive the workspace
- `@HELM help` — see help for this workspace

### Creating a New Workspace

Type in #general (or any channel):
```
@HELM [describe what you want]
```

Or use the #new-workspace channel if your HELM instance has one.

---

## Commands

All commands start with `@HELM` and work in any channel.

### Automation Commands

| Command | What it does |
|---|---|
| `@HELM [describe automation]` | Start a new automation proposal |
| `@HELM pause` | Pause the current workspace automation |
| `@HELM resume` | Resume a paused automation |
| `@HELM cancel` | Cancel and archive the current workspace |
| `@HELM status` | Show current workspace status |

### Settings Commands

| Command | What it does |
|---|---|
| `@HELM set [setting] to [value]` | Change a preference |
| `@HELM change my [setting] to [value]` | Same as above |
| `@HELM show my preferences` | See all current settings |

### Help Commands

| Command | What it does |
|---|---|
| `@HELM help` | General help |
| `@HELM help [topic]` | Help on a specific topic |
| `@HELM help phases` | Explain phases |
| `@HELM help preferences` | Explain preferences |
| `@HELM help workspaces` | Explain workspaces |
| `@HELM help commands` | List all commands |

---

## Troubleshooting

### HELM is not responding

1. Wait 2 minutes — HELM may be working on a task
2. Type `!force-restart` in #helm-status to restart HELM
3. Check the pinned message in #helm-status for recovery options

### HELM seems stuck on a task

1. Check the workspace channel for recent messages
2. Look at the pinned status message — it shows the last update timestamp
3. If the last update is >1 hour ago, type `@HELM status` in the workspace

### My automation stopped working

1. Go to the workspace channel
2. Ask: `@HELM what happened?`
3. HELM will diagnose and report (or escalate if it needs your input)

### HELM gave me wrong output

1. In the workspace, describe what was wrong: `@HELM the output is missing X`
2. HELM will fix it in the next loop
3. For persistent issues, ask for a design review: `@HELM review the design`

---

## FAQ

**Can I have multiple workspaces?** Yes. Each automation is a separate workspace. You can have as many as you need.

**Does HELM run when I'm asleep?** Yes. HELM runs 24/7 unless paused. If something needs your input, it waits until you respond.

**Can HELM access my accounts (email, bank, etc.)?** Only if you give it credentials during workspace setup. HELM will ask specifically for what it needs.

**Is HELM secure?** HELM runs on your machine and your VPS. Your data stays local. HELM only calls external APIs to fetch data you've requested. See [REFERENCE.md](REFERENCE.md#security) for details.

**Can I share HELM with others?** HELM is designed for personal use. Multi-user support is planned for a future version.

**What happens if HELM makes a mistake?** HELM logs all actions and can undo most changes. For critical automations, HELM asks you to confirm before taking action.
