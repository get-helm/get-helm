# Mission Control — Behaviors Dashboard
# Handoff spec for the mission-control workspace agent
# {{USER_JERRY}}: paste this into #new-workspace or share with the mission-control workspace when creating it

## What to build
A password-protected web dashboard at behaviors.{{USER_DOMAIN}} that shows real-time status
of all 21 PAP agent behaviors — derived from disk files, not agent self-report.

## Why it matters
Agents can (and do) lie about compliance. This dashboard reads the source files directly
so {{USER_JERRY}} can hold agents accountable without trusting their DELIVERs.

## Data sources (on Mac mini, read directly)
- `~/pap-workspace/behaviors-status.md` — tier assignments for all 21 behaviors
- `~/pap-workspace/engineer-queue.md` — active queue items with status/priority
- `~/pap-workspace/queue-audit.log` — full history of queue writes and claims
- `~/pap-workspace/friction-log.md` — violation patterns (if exists)

## Display requirements

### Main view: 21-Behavior Table
Columns: # | Behavior name | Tier (A/B/C) | Evidence | Gap | Active fix
- Tier A = green ✅ (structurally blocked by bot.js)
- Tier B = yellow ⚠️ (partially enforced)
- Tier C = red ❌ (prompt-only / aspirational)
Color-code rows by tier

### Summary bar (top of page)
- "X of 21 structurally enforced" with a progress bar
- Tier counts: A: X | B: X | C: X
- Last updated timestamp

### Active engineer queue (sidebar or bottom card)
- Pull from engineer-queue.md
- Show: ID | Priority | Description (truncated) | Est. mins | Status
- Filter: pending only (not done)

### Violation history (if friction-log.md exists)
- Last 10 violation events
- Format: timestamp | violation type | behavior ID | channel

## Update mechanism
- Page refreshes data on load (no polling needed for MVP)
- PM updates behaviors-status.md when engineer ships a queue item
- Engineer marks queue items complete when implemented

## Auth
- Password-protected using {{USER_DOMAIN}} Site Auth credential from PAP Vault
- Subdomain: behaviors.{{USER_DOMAIN}}

## Tech stack preference
- Static HTML + inline JS that fetches a JSON endpoint
- OR: Python/FastAPI serving the page and reading files directly
- The workspace agent should choose based on what's proven in CAPABILITIES.md

## For users without VPS/Domain (and backup for {{USER_JERRY}})
No slash commands. Approach: GitHub URL + pinned message in #pap-status.

- behaviors-status.md lives at: https://github.com/{{USER_GITHUB}}13/pap-config/blob/main/behaviors-status.md
- Engineer pins this URL as the first pinned message in #pap-status
- Bot.js auto-re-pins on every behaviors-status.md push so it stays visible
- The GitHub file is the source of truth — bot.js-audited, not agent self-reported

Risk: pinned messages get buried if many things are pinned. Mitigation: bot.js
unpins old and re-pins on each update so it's always the top pin.
{{USER_JERRY}}'s backup if {{USER_DOMAIN}} is down: same GitHub URL, always current.

## Phases
Phase A: Mockup (standalone HTML) posted to mockups.{{USER_DOMAIN}} — {{USER_JERRY}} approves before any backend work
Phase B-1: Static data from behaviors-status.md (read file, render table)
Phase B-2: Live queue from engineer-queue.md (same pattern, second card)
Phase B-3: Deploy to behaviors.{{USER_DOMAIN}} with auth gate

## Riskiest assumption
The data in behaviors-status.md is accurate and up-to-date.
(Mitigation: behaviors-status.md is bot.js-audited, not agent self-reported — this holds.)
