# [ARCHIVED — Orchestrator removed 2026-06-10]
# ORCH-02: Orchestrator Worker Contract Spec
## Status: Draft — {{USER_JERRY}} Review Required
## Date: 2026-05-24

---

## Overview

This spec defines the interface contract between the PAP orchestrator (`pap-orchestrator.mjs`) and the specialist worker agents it invokes. It covers three areas:

1. **Input format** — what the orchestrator sends to a worker
2. **Output/DELIVER format** — what a worker must return
3. **Failure and timeout handling** — how errors propagate

This spec is prerequisite to SPEC-01 (new specialist agents). Any new specialist agent built for orchestrator use must conform to this contract.

---

## 1. Input Format (Orchestrator → Worker)

### Generic worker (default path)

Workers receive a single string prompt assembled by `executeStep`. The prompt includes these blocks in order:

```
[PAP AGENT PROTOCOL]      — Phase markers + DELIVER schema (always injected)
[AUTHORITY SCALE]         — Level 0-5 cheat sheet (always injected)
[FINANCIAL SECURITY]      — Hard rules (always injected)
[DISCORD POSTING]         — discord-post.sh pattern (always injected)
[SPECIALIST CTX]          — Agent role assignment (workspace/discord/financial/pap-pm/generic)
[CHANNEL CTX]             — "Working channel: CHANNEL_ID" (if channelId was passed)
[WORKSPACE CTX]           — Workspace CLAUDE.md content slice (if --workspace-md was passed)
[PRIOR STEP RESULTS]      — Output of all previously-completed steps in this run (if any)
[STEP INSTRUCTION]        — "Step: {task}" (the single step this worker must complete)
[PARENT TASK]             — "(Part of larger task: {originalTask})"
```

### Specialist worker (pattern-matched path)

When a step task matches a registered `SPECIALIST_PATTERNS` regex, the orchestrator:
1. Loads the specialist's `.md` file from `~/.claude/agents/{name}.md`
2. Strips the YAML frontmatter (`---...---`)
3. Appends `turn-protocol.md` content
4. Prepends the resulting block before the step instruction

Specialist workers receive: their own .md instructions + turn-protocol + channelCtx + priorCtx + step instruction.

**Currently registered specialist patterns:**
- `etf-data-agent` — matches: ETF prices, Tiingo, fetch prices, tickers/prices, market data
- `financial-data-agent` — matches: Monarch, net worth, account balance, financial data, holdings

### Worker configuration (from orchestrator CLI)

| Field | Source | Description |
|---|---|---|
| `task` | `--task` arg | The specific step text the worker must execute |
| `originalTask` | decompose step | The parent task for context |
| `channelId` | `--channel` arg | Discord channel for progress posts (optional) |
| `workspaceContext` | `--workspace-md` arg | First 500 chars of workspace CLAUDE.md (optional) |
| `agentRole` | `--agent` arg | Override specialist routing (optional) |
| `timeoutMs` | `--timeout` arg | Per-step execution timeout in ms (default: 120000) |

---

## 2. Output Format (Worker → Orchestrator)

### Required output format

Workers must return a **plain text string** as their stdout response. The orchestrator captures this string as `result` and uses it as:
- Progress reporting (posted to Discord mid-run as step updates)
- Input context for subsequent steps (`priorCtx` block)
- Quality gate evaluation
- Final compiled Discord DELIVER

### DELIVER schema inside a worker response

Workers operating within the orchestrator still follow the PAP phase protocol. Each worker should produce:

```
✅ [Step description] — Done

[1-2 sentence summary of what was done and the result]

PUSHBACK: [one assumption challenge or "none — actively checked"]
VERIFICATION_REQUIRED: [one uncertainty or "none"]
PROACTIVE_NEXT: [action taken without being asked, or "none — checked X and found nothing"]
Docs updated: [files changed, or "none"]
```

The orchestrator uses the **first ~300 chars** of the worker result for the compiled Discord message, so the most important facts must appear at the top.

### Length constraint

- Recommended: under 500 chars for the summary section
- The compile step allocates `floor(budget / step_count)` chars per step with a minimum of 60 chars
- Long results are truncated with `...` in the final Discord DELIVER

### Status detection

The orchestrator sets step status to `'error'` if the result string starts with `"Step failed"`. Any other value is treated as `'done'`. Workers should NOT use this prefix unless the step genuinely failed — it triggers the `⚠️ N step(s) failed` footer.

---

## 3. Failure and Timeout Handling

### Timeout behavior

Each step runs inside `execSync(..., { timeout: timeoutMs })`. Default: 120000ms (2 min).

When a step exceeds `timeoutMs`:
- `execSync` throws `ETIMEDOUT` or `ERR_CHILD_PROCESS_STDIO_MAXBUFFER`
- The orchestrator catches this and writes `result = "Step failed: {error message slice}"`
- Status becomes `'error'`
- The chain continues to the next step (no abort)
- Failed steps appear in the compiled DELIVER with `⚠️`

**Worker responsibility:** For any operation expected to exceed 90 seconds (browser, VPS deploy, data pull), the worker must either:
1. Break it into smaller steps that each fit within `timeoutMs`, OR
2. Run long operations in the background and return a status pointer (e.g., path to log file)

Workers must NOT silently block on long operations — the orchestrator will kill them.

### Partial failure semantics

The orchestrator uses "fail forward" semantics:
- A failed step does NOT abort the chain
- Subsequent steps receive the failed step's error message in `priorCtx`
- The quality gate and compile step evaluate the run holistically

Workers that encounter an unrecoverable error within their step should:
1. Post `⏸ BLOCK` with the error to Discord (if `channelId` is available)
2. Return: `"Step failed: {one-sentence root cause}"` — this terminates just this step cleanly

Workers must NEVER exit silently. A blank stdout string will be treated as `result = ""` (status `done`, empty content) — misleading. Always return a non-empty string.

### Quality gate FAIL path

After all steps complete, the orchestrator runs a Haiku quality check:
- If the combined results do not address the original request → quality gate posts `⚠️ Quality check: FAIL - {reason}` to Discord
- The compile step still runs and delivers — the quality warning appears BEFORE the final DELIVER
- Workers do not interact with the quality gate directly

---

## 4. Specialist Agent Registration (for new agents)

To register a new specialist agent:

1. Create `~/.claude/agents/{name}.md` with the agent's instructions
2. Add a regex pattern to `SPECIALIST_PATTERNS` in `pap-orchestrator.mjs`:
   ```js
   '{agent-name}': /\b(keyword1|keyword2|...)\b/i,
   ```
3. The agent .md file must be self-contained — it cannot assume injection of CAPABILITIES.md or PAP-FACTS.md (those are bot.js injections, not orchestrator injections)
4. The agent should expect the `[PRIOR STEP RESULTS]` context block — it can use prior step outputs to avoid redundant work
5. Audit: all specialist invocations are automatically logged to pap-audit

---

## 5. Known Gaps (for {{USER_JERRY}}'s review)

1. **No per-step Discord channel lock.** Two orchestrator runs in the same channel can interleave step updates. Not a current issue (single orchestrator instance), but worth noting for future parallel orchestration.

2. **priorCtx truncation.** Prior step results are truncated to 300 chars each in the context block. Workers that produce dense results (JSON, tables) lose structure when passed forward. Workers should produce text summaries, not raw data, as their output.

3. **No worker output schema.** Workers return a free-form string. A structured output schema (e.g., `{summary, files_changed, assertions}`) would make quality gate evaluation more reliable. Current quality gate uses full-text heuristics.

4. **Specialist routing is text-matching only.** A step like "get the ETF price then send an email" matches `etf-data-agent` but the email half is silently dropped. Compound steps should be decomposed before entering the execute loop.

---

*This document is a draft. Section 5 gaps require {{USER_JERRY}}'s input before SPEC-01 specialist agents are built.*
