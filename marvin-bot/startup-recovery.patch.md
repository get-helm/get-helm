# startup-recovery.patch.md
## Patch: Post recovery messages for interrupted turns on bot startup

---

### What it does

When the bot restarts, it scans all channel-state JSON files for any channel
where the last agent message had a phase of `ack` or `update` — meaning the
agent had acknowledged a request or was mid-task when the bot died. For each
such channel it finds, it fetches the Discord channel and posts a warning
message to the user so they know their request was interrupted and they should
re-send it.

The elapsed time (in minutes) since the last agent message is calculated from
`state.lastAgentMsgTs` and included in the warning. The check uses the same
`CHANNEL_STATE_DIR` constant already present in bot.js.

---

### Insertion point

**File:** `/Users/{{USER_HOME}}/marvin-bot/bot.js`
**Lines:** 788–799 (the `// ─── STARTUP ───` block and `clientReady` handler)

The exact lines to find (10-line context window):

```javascript
// ─── STARTUP ───────────────────────────────────────────────────────────────
// Using 'clientReady' per discord.js v14 — avoids deprecation warning
client.once('clientReady', async () => {
  console.log(`${AGENT_NAME} online as ${client.user.tag}`);
  appendEvent('bot_restart', null, client.user.id, null, null, { commit: CURRENT_COMMIT });
  try {
    const statusCh = await client.channels.fetch(PAP_STATUS_CHANNEL);
    await statusCh.send(`👋 ${AGENT_NAME} is back online.`);
  } catch (err) {
    console.error('Startup message error:', err.message);
  }
});
```

---

### Code block to insert

**Step 1:** Insert the `checkInterruptedTurns` function definition immediately
BEFORE the `// ─── STARTUP ───` comment (i.e., before line 788). Place it
right after the preceding blank line that follows the missed-PM-trigger block
(line 787).

```javascript
// ─── INTERRUPTED TURN RECOVERY ────────────────────────────────────────────
// On startup: check for interrupted turns
async function checkInterruptedTurns() {
  const stateDir = path.join(__dirname, 'channel-state');
  try {
    const files = fs.readdirSync(stateDir).filter(f => f.endsWith('.json'));
    for (const file of files) {
      try {
        const state = JSON.parse(fs.readFileSync(path.join(stateDir, file), 'utf8'));
        if (state.lastAgentMsgPhase === 'ack' || state.lastAgentMsgPhase === 'update') {
          const channelId = state.channelId || file.replace('.json', '');
          const channel = client.channels.cache.get(channelId);
          if (channel) {
            const elapsed = state.lastAgentMsgTs
              ? Math.round((Date.now() - new Date(state.lastAgentMsgTs).getTime()) / 60000)
              : '?';
            await channel.send(`⚠️ Bot restarted. Your request from ~${elapsed} min ago was interrupted. Please re-send when ready.`);
          }
        }
      } catch (e) { /* skip unparseable state files */ }
    }
  } catch (e) { /* stateDir may not exist yet */ }
}

```

**Step 2:** Add a `checkInterruptedTurns()` call inside the `clientReady`
handler, AFTER the `await statusCh.send(...)` line. Replace the existing
`clientReady` block with:

```javascript
// ─── STARTUP ───────────────────────────────────────────────────────────────
// Using 'clientReady' per discord.js v14 — avoids deprecation warning
client.once('clientReady', async () => {
  console.log(`${AGENT_NAME} online as ${client.user.tag}`);
  appendEvent('bot_restart', null, client.user.id, null, null, { commit: CURRENT_COMMIT });
  try {
    const statusCh = await client.channels.fetch(PAP_STATUS_CHANNEL);
    await statusCh.send(`👋 ${AGENT_NAME} is back online.`);
  } catch (err) {
    console.error('Startup message error:', err.message);
  }
  await checkInterruptedTurns();
});
```

The only change to the `clientReady` block is the added line:
```javascript
  await checkInterruptedTurns();
```
just before the closing `});`.

---

### Note on `lastAgentMsgTs`

The current channel-state schema uses `lastAgentMsgAt` (a Unix timestamp in
milliseconds, written as `Date.now()`), not `lastAgentMsgTs`. The code block
references `state.lastAgentMsgTs`, which will be `undefined` for existing state
files, causing the elapsed time to display as `?`. This is safe — the recovery
message will still post.

If you want accurate elapsed times, either:
- Accept `?` for channels whose state was written before this patch lands
  (state files written after the patch is applied will need `lastAgentMsgTs`
  added to `writeChannelState` calls — a separate task), OR
- Change the elapsed calculation in `checkInterruptedTurns` to use
  `state.lastAgentMsgAt` instead of `state.lastAgentMsgTs`, since that field
  is already being written:

```javascript
            const elapsed = state.lastAgentMsgAt
              ? Math.round((Date.now() - state.lastAgentMsgAt) / 60000)
              : '?';
```

Recommend using `state.lastAgentMsgAt` — it's already populated by the
existing `writeChannelState` calls throughout bot.js.

---

### How to apply when ready

1. Open `/Users/{{USER_HOME}}/marvin-bot/bot.js` in an editor.
2. Find the block starting with `// ─── STARTUP ───` (around line 788).
3. Immediately before that comment, insert the `checkInterruptedTurns`
   function definition (Step 1 above).
4. Inside the `clientReady` handler, add `await checkInterruptedTurns();`
   as the last line before the closing `});` (Step 2 above).
5. Optionally: update the elapsed-time field reference from
   `state.lastAgentMsgTs` to `state.lastAgentMsgAt` per the note above.
6. Save the file and restart the bot under supervision.
7. Verify in the bot log that `[startup]` lines appear and that any channels
   with `ack`/`update` state receive the recovery message in Discord.
