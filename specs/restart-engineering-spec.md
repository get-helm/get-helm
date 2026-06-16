# Restart Engineering Spec
## Ready to implement at next restart
## Written: 2026-05-09 (pap-chat session)

This file contains exact bot.js changes for engineer to apply. Each change has a
location, a before/after snippet, and a test to confirm it worked.

---

## CHANGE 1 — Model Routing
**Problem:** Every agent runs on Sonnet regardless of frontmatter. Haiku costs 20× less.
**Fix:** Parse `model:` field from agent .md frontmatter, pass `--model` flag to Claude CLI.

**Location:** `runClaude()` function, around line 525 where `execFile(CLAUDE, ...)` is called.

**Also need:** New helper `parseAgentModel(agentInstructions)` that reads `model:` from frontmatter.

**Code to add (before `runClaude` function):**
```js
function parseAgentModel(agentInstructions) {
  if (!agentInstructions) return null;
  const match = agentInstructions.match(/^model:\s*(.+)$/m);
  if (!match) return null;
  const m = match[1].trim();
  // Map shorthand to full model IDs
  const map = {
    'haiku': 'claude-haiku-4-5-20251001',
    'sonnet': 'claude-sonnet-4-6',
    'opus': 'claude-opus-4-7'
  };
  return map[m] || m; // if already a full ID, use as-is
}
```

**Change inside `runClaude`:** The function signature becomes:
`function runClaude(prompt, channelId, agentKey, extraEnv, agentInstructions)`

Add before `execFile`:
```js
const modelFlag = parseAgentModel(agentInstructions);
const claudeArgs = ['--dangerously-skip-permissions', '-p', prompt];
if (modelFlag) claudeArgs.splice(1, 0, '--model', modelFlag);
```

Replace `['--dangerously-skip-permissions', '-p', prompt]` with `claudeArgs` in BOTH execFile calls.

**Also update callers** in `enqueueClaudeRun` to pass `agentInstructions` through,
and update `messageCreate` handler where `enqueueClaudeRun` is called.

**Test:** After restart, check logs for `[model]` entries. PM sweep should show `haiku` in logs.
Expected: ~60-70% overnight token reduction.

---

## CHANGE 2 — CAPABILITIES.md Injection Gate
**Problem:** Workspace agents don't read CAPABILITIES.md. They reinvent solved problems.
**Fix:** Inject CAPABILITIES.md content into every workspace agent prompt before Phase B.
**Mechanism:** Add it to `loadAgentInstructions` for workspace agents — same pattern as turn-protocol injection.

**Location:** `loadAgentInstructions()`, around line 257 where `agentKey.startsWith('workspace:')` is handled.

**Change:**
```js
if (agentKey.startsWith('workspace:')) {
  const wsName = agentKey.replace('workspace:', '');
  const wsPath = path.join(WORKDIR, 'workspaces', wsName, 'CLAUDE.md');
  
  // Inject CAPABILITIES.md before workspace instructions
  const capPath = path.join(WORKDIR, 'CAPABILITIES.md');
  let capContent = '';
  if (fs.existsSync(capPath)) {
    capContent = `[SYSTEM CAPABILITIES — read before Phase B]\n${fs.readFileSync(capPath, 'utf8')}\n[END SYSTEM CAPABILITIES]\n\n`;
  }
  
  return preamble + capContent + fs.readFileSync(wsPath, 'utf8');
}
```

**Why this works:** CAPABILITIES.md is injected fresh every spawn. Agents can't ignore it — it's in the prompt, not a "you should read" instruction. After each loop, BML checkpoint skill writes back to CAPABILITIES.md. Next spawn gets the updated version.

**Test:** Start any workspace task. Confirm CAPABILITIES.md content appears in Claude's context (check by asking agent "what does CAPABILITIES.md say about Firecrawl?").

---

## CHANGE 3 — PM Scheduled Proactive Sweep
**Problem:** PM only runs reactively (via launchd every 15 min, which is external). Between sweeps, problems pile up. PM can report but can't act.
**Fix:** 
- Part A: Bot.js runs PM on its own setInterval (every 15 min), independent of launchd.
- Part B: PM sweep gets action capabilities: write files, relay misrouted messages, trigger engineer directly via trigger file.

**Location:** Startup section, after `rebuildRegistryView()` call (~line 1256).

**Code to add (Part A — scheduled PM sweep):**
```js
// ─── SCHEDULED PM SWEEP ─────────────────────────────────────────────────
const PM_SWEEP_INTERVAL_MS = 15 * 60 * 1000; // 15 minutes

async function runPMSweep() {
  // Skip if PM already running in improvements channel
  if (activeChannelAgents.has(PAP_IMPROVEMENTS_CHANNEL)) {
    console.log('[pm-sweep] skipping — PM already active');
    return;
  }
  // Skip if no meaningful events since last sweep
  if (readEventsSinceLastPMLog()) {
    appendEvent('pm_skip', PAP_IMPROVEMENTS_CHANNEL, null, 'no meaningful events', null);
    console.log('[pm-sweep] idle skip — no meaningful events');
    return;
  }
  
  console.log('[pm-sweep] spawning proactive sweep');
  const pmInstr = loadAgentInstructions('pap-improvements');
  const pmPrompt = buildPrompt(
    PAP_IMPROVEMENTS_CHANNEL,
    'pap-improvements',
    '[SYSTEM: Scheduled PM sweep. Review system state, relay any misrouted feedback, trigger engineer if needed via pm-engineer-trigger.json. Post to #pap-improvements only if there is something actionable for {{USER_JERRY}}.]',
    '',
    pmInstr
  );
  activeChannelAgents.set(PAP_IMPROVEMENTS_CHANNEL, { startedAt: Date.now() });
  try {
    await enqueueClaudeRun(pmPrompt, PAP_IMPROVEMENTS_CHANNEL, 'pap-improvements', null);
  } finally {
    activeChannelAgents.delete(PAP_IMPROVEMENTS_CHANNEL);
  }
}

setInterval(() => runPMSweep().catch(e => console.error('[pm-sweep] error:', e.message)), PM_SWEEP_INTERVAL_MS);
console.log('[startup] PM sweep scheduled every 15 min');
```

**Part B — PM action capabilities (in PM agent instructions `pap-improvements.md`):**
PM sweep should now have three actions available:
1. **Relay misrouted messages:** Read channel history from wrong channel, post to correct channel.
2. **Trigger engineer:** Write `pm-engineer-trigger.json` with `{ trigger: 'engineer', reason: '...', ts: '...' }`.
3. **Post to #pap-improvements only if actionable:** If {{USER_JERRY}} needs to see it, post. Otherwise log silently.

The bot.js trigger file watcher already handles step 2. Steps 1 and 3 are PM instruction changes.

**Test:** Wait 15 min after restart. Check logs for `[pm-sweep]` entries. Confirm PM posts only when there's something to act on.

---

## CHANGE 4 — Proactive PM: Marvin reads system state between conversations
**Problem:** Marvin (me) only exists when {{USER_JERRY}} messages. Can't notice stuck agents between messages.
**Fix:** Scheduled PM sweep (Change 3) IS the proactive layer. Additionally, when Marvin receives any message in #pap-chat, he should first read ACTIVE-STATE.md + the last PM sweep report before responding.

**Location:** `buildPrompt()` for #pap-chat channel specifically.

**Code change in `buildPrompt`:**
```js
// For pap-chat, prepend current system state so Marvin is always contextual
if (channelId === PAP_CHAT_CHANNEL) {
  const activeStatePath = path.join(WORKDIR, 'ACTIVE-STATE.md');
  if (fs.existsSync(activeStatePath)) {
    const activeState = fs.readFileSync(activeStatePath, 'utf8');
    prompt = `[CURRENT SYSTEM STATE]\n${activeState}\n[END SYSTEM STATE]\n\n` + prompt;
  }
}
```

This means Marvin always knows what's running, what's stuck, and what decisions are pending — before seeing {{USER_JERRY}}'s message.

**Test:** Ask Marvin "what's happening in options-helper right now?" without telling him. He should know.

---

## CHANGE 5 — Context Splitting (smaller CLAUDE.md files)
**Problem:** CLAUDE.md has grown so large that rules at the bottom get crowded out under token pressure.
**Fix:** PROMPT-MANIFEST.json controls what gets injected per agent. Split the monolith:
- `turn-protocol.md` — already separate ✓
- `about-me.md` — already injected ✓
- `voice-and-style.md` — already injected ✓
- `capabilities-summary.md` — NEW: 1-page summary of CAPABILITIES.md for non-workspace agents
- Each agent .md file stays focused on agent-specific instructions only

**Action for engineer:** Audit PROMPT-MANIFEST.json. Confirm no agent gets more than 4 injected files.
If any agent gets >4 injections, identify the lowest-value one and remove it.

**Test:** Check token count of any agent's full prompt. Should be under 8,000 tokens before conversation history.

---

## ALREADY DONE (no restart needed)
These are in bot.js and agent files from today's session:
- `timeout_kill` + `timeout_warn` in PM SKIP_TYPES ✓
- options-helper in LONG_TIMEOUT_CHANNELS (900s threshold) ✓  
- PM→engineer trigger file watcher ✓
- PM relay rule (misrouted feedback) ✓
- PM idle rule (no identical repeat posts) ✓

## RESTART ORDER (dependencies)
1. Model routing (Change 1) — no dependencies
2. CAPABILITIES.md gate (Change 2) — no dependencies
3. PM scheduled sweep (Change 3) — depends on PM instructions update
4. ACTIVE-STATE injection in pap-chat (Change 4) — no dependencies
5. Thread support (from thread-support-spec.md) — no dependencies
6. Auto context reset (from auto-reset-spec.md) — depends on thread support
7. Rich Discord UI (from rich-discord-ui-spec.md) — depends on thread support

## VALIDATION CHECKLIST
After each change, confirm in logs:
1. `[model]` entries showing haiku for PM, sonnet for workspace agents
2. `[pm-sweep]` entries every 15 min
3. CAPABILITIES.md content in workspace prompts (grep bot logs)
4. ACTIVE-STATE.md injected in pap-chat prompts

See `specs/restart-validation-checklist.md` for full rollback instructions.
