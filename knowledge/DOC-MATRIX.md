# PAP Documentation Matrix
## Per-agent, per-action-class documentation requirements
## Updated: 2026-05-21

This file is the enforcement spec for the Documentation Gate in turn-protocol.md.
Before every DELIVER, agents check this matrix and list every required doc they updated in "Docs updated:".
A DELIVER that skips a required doc is structurally invalid — equivalent to a missing phase marker.

---

## How to read this

**Action class** — the category of work completed this turn
**Required docs** — files that MUST be updated before DELIVER is valid
**Optional docs** — files that SHOULD be updated if relevant
**Validation test** — how to confirm the doc was updated correctly

---

## ALL AGENTS — every turn

| Action class | Required docs | Optional docs |
|---|---|---|
| Any turn that touches system state (file edits, deploys, config changes) | `decisions-log.md` — one-line entry (see format below) | — |
| Any friction, unexpected error, or protocol violation encountered | `friction-log.md` — timestamped entry | — |
| Any multi-step task | `ACTIVE-STATE.md` — checkpoint after each step | — |

### decisions-log.md append format (one line per turn)
```
## [YYYY-MM-DD HH:MM]
Channel: [channel name / ID]
Agent: [workspace / help / connector / etc.]
Action: [one sentence: what changed]
Files: [comma-separated list of files changed]
Level: [0-5]
```

---

## WORKSPACE AGENTS

### Phase A (research + data source validation)

| Action class | Required docs |
|---|---|
| Data source tested (any result) | `ASSUMPTIONS.md` — update status (🟡 PARTIAL / ✅ CONFIRMED / ❌ FAILED) with actual extracted values |
| Data source approach tested | `RESEARCH-LOG.md` — append approach, what was tried, outcome |
| New external tool or API evaluated | `~/pap-workspace/CAPABILITIES.md` — add PROVEN/FAILED entry if generalizable |

### Phase B (build loops)

| Action class | Required docs |
|---|---|
| BML loop completed (pass or fail) | `LEARNINGS.md` — what was learned; `TASKS.md` — update task status |
| Architectural or design decision made | `DECISIONS.md` — decision + rationale + alternatives considered |
| Phase advanced (A→B, B→C, etc.) | `WORKSPACE-PHASE.md` — update current phase |
| New capability proven | `~/pap-workspace/CAPABILITIES.md` — add PROVEN entry if generalizable |
| Capability confirmed failed | `~/pap-workspace/CAPABILITIES.md` — add FAILED entry if generalizable |

### Phase D (BML memory checkpoint)

| Action class | Required docs |
|---|---|
| BML loop concluded | `LEARNINGS.md` — full loop summary; `TASKS.md` — close completed tasks; `~/pap-workspace/CAPABILITIES.md` — promote generalizable learnings |

### Any workspace turn with code changes

| Action class | Required docs |
|---|---|
| Deploy or VPS change | `DECISIONS.md` — what was deployed and why |
| Bug fixed | `TASKS.md` — close the task; bug fix prevention mechanism noted in DELIVER |

---

## HELP / PM AGENT

| Action class | Required docs |
|---|---|
| Protocol rule added or changed | `~/.claude/agents/turn-protocol.md` — update the rule; `decisions-log.md` — entry |
| CLAUDE.md routing updated | `~/pap-workspace/CLAUDE.md`; `decisions-log.md` — entry |
| Agent instruction file updated | The affected agent file; `decisions-log.md` — entry |
| User preference changed | `~/pap-workspace/VOICE-AND-STYLE.md` or `~/pap-workspace/CONFIG.md` |
| New doc or file created at root level | `~/pap-workspace/DOC-REGISTRY.md` — add row to the table |
| Feedback from user logged | `~/pap-workspace/friction-log.md` or feedback-queue.md |
| New skill added | `SKILL.md` — add `AGENT TRIGGER LINES` section listing each agent that should invoke this skill; for each listed agent, add one trigger line to that agent's `.md` file; `decisions-log.md` — entry |

---

## CONNECTOR AGENT

| Action class | Required docs |
|---|---|
| Article/URL saved to second brain | Second brain file written; no additional required docs |
| New integration set up | `~/pap-workspace/CAPABILITIES.md` — PROVEN entry |
| Integration failed | `~/pap-workspace/CAPABILITIES.md` — FAILED entry |

---

## ENGINEER AGENT

| Action class | Required docs |
|---|---|
| Task completed | `~/pap-workspace/engineer-context.md` — close task; `decisions-log.md` — entry |
| New capability shipped | `~/pap-workspace/CAPABILITIES.md` — PROVEN entry |
| Bug fixed | `~/pap-workspace/engineer-context.md` — close task; prevention mechanism added |
| Architecture changed | `~/pap-workspace/decisions-log.md` — entry with rationale |

---

## EXECUTOR AGENT

| Action class | Required docs |
|---|---|
| Deploy completed | `decisions-log.md` — what was deployed, to where, outcome |
| System config changed | `decisions-log.md` — what changed and why |

---

## SCAFFOLDER AGENT

| Action class | Required docs |
|---|---|
| Workspace created | `~/pap-workspace/DOC-REGISTRY.md` — entry for the workspace (WORKSPACE type) |

---

## VALIDATION TEST (before every DELIVER)

Run this mental check before posting any DELIVER:

1. What action class(es) did this turn involve?
2. For each action class, which docs does the matrix require?
3. Did I update all of them?
4. If not — update them now, before posting DELIVER.
5. List every updated doc in the "Docs updated:" DELIVER field.

A "Docs updated: none" is only valid if the turn was purely conversational with zero system state changes.

---

## Recovery: what to do if a prior turn skipped docs

If you discover a prior turn's docs were skipped:
1. Write the missing entry now (backdated to the turn's timestamp)
2. Note in your DELIVER: "Backfilled docs for [prior action]"
3. Do NOT create a friction-log entry for the gap unless it was a protocol-level violation (repeat pattern, not one-off miss)
