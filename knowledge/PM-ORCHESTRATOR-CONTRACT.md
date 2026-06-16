# [ARCHIVED — Orchestrator removed 2026-06-10]
# PM-Orchestrator Contract
## Version 1.0 — Session 150 (2026-06-03)
## Owner: Engineer
## Consumers: product-manager.md, pap-orchestrator.mjs

This document defines the interface contract between PAP's two autonomous coordination services:
- **PM (Product Manager)**: Strategic coordinator. Owns backlog, quality patterns, engineer queue.
- **Orchestrator**: Tactical executor. Owns multi-step task decomposition, agent lifecycle, per-step cadence.

---

## Data Flows

### PM → Orchestrator

| File | Written by | Read by | Contents |
|------|-----------|---------|----------|
| `engineer-queue.md` | PM (via T1 framework + T1-D escalation) | Orchestrator (pap-orchestrator.mjs) | queued_at blocks — task name, problem, success_criteria, estimated_min |
| `work-items.json` | PM (auto-queue on deliver trigger) | PM self, future Orchestrator integration | items with status: queued/active/done/blocked |
| `queue-audit.log` | PM + Engineer | PM (audit reading) | timestamped queue operation log |

### Orchestrator → PM

| File/Event | Written by | Read by | Contents |
|------------|-----------|---------|----------|
| `event-stream.jsonl` | Orchestrator (agent_spawn, agent_message, timeout_kill events) | PM (T1-C, T1-F health checks) | raw event log |
| `orchestrator-cadence-metrics.json` | Orchestrator (per-run) | PM T1-C (future: quality pattern) | compliance rate, missed steps, on-time rate |
| `decisions-log.md` | Orchestrator (future: deliver_captured) | PM (T1-A, T1-D reconciliation) | session-level decisions + completions |
| `channel-state/*.json` | bot.js + agents | PM T1-A (stall detection) | agentPid, lastAgentMsgPhase, checkpoint |

### Shared State

| File | Written by | Read by | Contents |
|------|-----------|---------|----------|
| `friction-log.md` | bot.js validation gates | PM T1-D, performance-monitor | protocol violations |
| `pm-scratch.md` | PM (sweep state, known_violation_types) | PM (resume between sweeps) | ephemeral PM working state |
| `marvin.log` | bot.js | PM T1-F (anomaly detection) | bot runtime log |

---

## Contracts

### PM's obligations to Orchestrator
1. **Queue items are actionable** — any queued_at block in engineer-queue.md must have a complete `success_criteria` list (not "TBD"). Orchestrator's Haiku decomposition will use these verbatim.
2. **One item per trigger** — PM may write at most 1 queued_at block per sweep cycle (T1-E rule). Bulk queue writes are engineer-only (claim-first sessions).
3. **Claimed items are removed** — once an item is picked up by engineer, PM does not re-queue it unless engineer explicitly clears it and marks it back to "queued" status in work-items.json.
4. **Known violation types stay current** — pm-scratch.md `known_violation_types:` list is updated same-sweep when a new type is first seen. Never accumulate backlog of uncategorized violations.

### Orchestrator's obligations to PM
1. **Write orchestrator-cadence-metrics.json after each run** — PM will eventually read this for quality pattern detection.
2. **Emit agent_spawn, agent_message, timeout_kill events to event-stream.jsonl** — PM's T1-F and anomaly detector rely on these.
3. **Do not write to engineer-queue.md directly** — Orchestrator executes what's in the queue; it does not add new items. Only PM and Engineer write queued_at blocks.
4. **Post DELIVER to pap-audit ({{USER_CHANNEL_HELM_AUDIT}}) on task completion** — this is the trigger for PM's "Engineer DELIVER → Auto-Queue Next" path.

---

## Failure Mode Handling

### If PM is down (sweep not firing)
- Orchestrator continues executing queued items until queue is empty.
- No new items are queued (PM owns that path).
- bot.js watchdog (health check) detects PM silence via heartbeat timestamp.
- Resolution: launchd auto-restarts PM sweep via com.pap.pm.sweep.plist.

### If Orchestrator is down
- engineer-queue.md accumulates items but none execute.
- PM sweep detects idle queue with items (T1-B check: "active queue with no progress in 6h").
- PM escalates to pap-improvements with "Orchestrator appears inactive" alert.
- Resolution: engineer manually runs queue or restarts orchestrator subprocess.

### If both are down
- bot.js watchdog fires VPS fallback cron alert after 30 min of stale heartbeat.
- {{USER_JERRY}} receives ntfy push + VPS health check posts to pap-audit.
- Resolution: /restart command or nightly restart.

### If queue has items neither PM nor Engineer added
- Treat as potential data corruption or rogue agent.
- PM T1-B cross-references known item IDs. Unknown queued_at blocks → flag to pap-improvements.
- Do not execute unknown queue items until source is identified.

---

## Escalation Paths

### PM escalates to user ({{USER_JERRY}}) when:
- Critical anomaly (bot down, error rate >10% spawns, cost spike) — post to pap-improvements with literal evidence
- New friction pattern requiring {{USER_JERRY}} decision — post once with options, wait for response
- Design-blocked item requiring user input — post spec draft, request approval

### PM does NOT escalate to user when:
- Known violation type is recurring (queue engineer fix, log to pap-audit only)
- Workspace is stalled but recoverable (trigger resume via pm-agent-trigger.json)
- Queue is healthy and running (log to decisions-log only, no Discord post)

### Orchestrator escalates when:
- Step stalls past cadence (Discord nudge to agent — already implemented Session 148)
- Quality gate fails (⚠️ flag before DELIVER — already implemented Session 56)
- Multiple steps fail consecutively (post to pap-audit via qualityGateStep)

---

## Version History
- v1.0 (2026-06-03, Session 150): Initial contract definition. Captured existing implicit contract from Sessions 148-149 implementations.
