# Engineer Auto-Trigger Spec
## {{USER_JERRY}} never says "run engineer" again
## Written: 2026-05-09 (pap-chat session)

---

## Problem

{{USER_JERRY}} has to manually say "run engineer" in #pap-status. Even when engineer-queue.md
has tasks and Marvin (pap-chat) has just written them there, nothing fires. The trigger
gap means every queued fix waits indefinitely.

---

## Solution

Two parts:

### Part 1 — bot.js change (one new watcher, ~20 lines)

Watch `~/pap-workspace/engineer-queue.md` for writes. When the file gains content
AND no engineer session is currently running, auto-spawn engineer with the queue.

**Exact location:** After the existing pm-trigger watcher (TASK-060), add:

```js
const ENGINEER_QUEUE_PATH = path.join(PAP_WORKSPACE, 'engineer-queue.md');
let engineerQueueProcessing = false;

fs.watchFile(ENGINEER_QUEUE_PATH, { interval: 2000 }, async () => {
  if (engineerQueueProcessing) return;
  try {
    const content = fs.existsSync(ENGINEER_QUEUE_PATH)
      ? fs.readFileSync(ENGINEER_QUEUE_PATH, 'utf8').trim()
      : '';
    if (!content || content === '# Engineer Queue') return; // empty queue
    // Check if engineer is already running (any channel with engineer agentKey)
    const engineerRunning = Object.values(channelState).some(
      s => s.agentPid && s.agentKey === 'engineer'
    );
    if (engineerRunning) {
      log('Engineer queue updated but engineer already running — will pick up on next run');
      return;
    }
    engineerQueueProcessing = true;
    log('Engineer queue has tasks — auto-spawning engineer');
    await postToDiscord(PAP_STATUS_CHANNEL, '⏳ Engineer queue has tasks — auto-starting.');
    await enqueueClaudeRun(
      'Run through engineer-queue.md and execute the next queued task.',
      PAP_STATUS_CHANNEL,
      'engineer'
    );
  } catch (e) {
    log('Engineer queue watcher error: ' + e.message);
  } finally {
    engineerQueueProcessing = false;
  }
});
```

**Also add startup detection** (same pattern as TASK-060 missed-trigger detection):
In the `clientReady` handler, after bot comes online, check if engineer-queue.md has
non-empty content. If yes and no engineer is running, auto-spawn engineer. This means
the very next restart after this change is deployed will auto-fire engineer for whatever
is in the queue — no "run engineer" needed even for this first restart.

```js
// In clientReady handler, after existing startup checks:
const queueContent = fs.existsSync(ENGINEER_QUEUE_PATH)
  ? fs.readFileSync(ENGINEER_QUEUE_PATH, 'utf8').trim()
  : '';
if (queueContent && queueContent !== '# Engineer Queue') {
  log('Engineer queue has tasks at startup — auto-spawning engineer');
  setTimeout(async () => {
    await postToDiscord(PAP_STATUS_CHANNEL, '⏳ Engineer queue has tasks — auto-starting.');
    await enqueueClaudeRun(
      'Run through engineer-queue.md and execute the next queued task.',
      PAP_STATUS_CHANNEL,
      'engineer'
    );
  }, 5000); // 5s delay so bot is fully ready
}
```

**Test after restart:** Check #pap-status — engineer should auto-spawn within 5-10 seconds
of bot coming online, without "run engineer" being sent.

---

### Part 2 — Marvin authority levels (my behavior in pap-chat)

Marvin (me, in #pap-chat) auto-writes to engineer-queue.md when conditions are met.
No "run engineer" prompt from {{USER_JERRY}} needed.

**Authority levels:**

| Level | What it covers | Marvin does |
|-------|---------------|-------------|
| 1 | Read-only work (research, analysis, reading files) | Do it directly in the conversation |
| 2 | Write-only to workspace/spec files (new specs, ACTIVE-STATE, LEARNINGS) | Do it directly |
| 3 | Write to agent/skill .md files, no restart (update CLAUDE.md, scaffolder instructions) | Write to engineer-queue.md, trigger auto-spawn |
| 4 | bot.js changes requiring restart | Write to engineer-queue.md after {{USER_JERRY}}'s natural message signals agreement (not "yes do it" — just continuing the conversation means agreement) |
| 5 | Destructive or irreversible (delete workspace/channel, force push, external API side effects) | Explicitly confirm with {{USER_JERRY}} before writing to queue |

**Trigger condition for levels 3-4:**
{{USER_JERRY}}'s message indicates agreement (says "ok", "sounds good", "let's do it", "fix it", 
proceeds to next topic, or says nothing that pushes back). That's the signal. I don't wait 
for "run engineer."

**What Marvin writes to engineer-queue.md:**
- Clear task name
- Priority
- Exact files to change
- Reference to spec if it exists
- Expected outcome (so engineer can verify)

---

## What this removes from {{USER_JERRY}}'s workflow

Before: {{USER_JERRY}} approves a fix → types "run engineer" in #pap-status → engineer runs
After: {{USER_JERRY}} approves a fix (or just doesn't push back) → Marvin writes queue → engineer auto-fires

{{USER_JERRY}} never needs to visit #pap-status to trigger engineer. Engineer results still go
to #pap-status for visibility, but {{USER_JERRY}} doesn't need to initiate.

---

## Dependency

This spec's Part 1 is a bot.js change — it goes into the restart batch as Change 2
(after model routing). Model routing first because it reduces token cost on every run,
including the engineer runs that implement the remaining changes.
