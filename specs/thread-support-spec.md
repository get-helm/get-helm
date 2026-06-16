# Thread Support — bot.js Spec
Created: 2026-05-09

## Why
Each thread = isolated context window for one topic/task. Prevents context drift across conversations. Threads naturally cap message count, so agents start fresh per topic.

## What Discord sends
Thread messages arrive as `MESSAGE_CREATE` with:
- `channel_id` = thread ID (not parent)
- `channel_type` = 11 (public thread) or 12 (private thread)
- `parent_id` = the channel that holds the thread (e.g. #pap-chat)

Currently bot.js has NO check for channel_type, so thread messages arrive but route to the thread ID which has no workspace CLAUDE.md → agent gets no context → fails silently.

## Changes to bot.js

### 1. Detect thread messages (after line 1531 `if (event.t !== 'MESSAGE_CREATE') return;`)

```js
const isThread = data.channel_type === 11 || data.channel_type === 12;
const workspaceChannelId = isThread ? (data.thread?.parent_id || data.parent_id) : data.channel_id;
const contextChannelId = data.channel_id; // always the thread ID or regular channel
```

### 2. Route workspace lookups using workspaceChannelId, not channelId
- CLAUDE.md lookup → use workspaceChannelId
- Channel-state file → use contextChannelId (isolated per thread)
- History fetch → fetch from contextChannelId (thread history only)

### 3. Pass thread context to claude spawn
Add to the context injected into the claude prompt:
```
[Thread context: This is a Discord thread. Parent channel: {workspaceChannelId}. Thread ID: {contextChannelId}. Treat this as an isolated task context — do not reference other threads or the parent channel's message history.]
```

### 4. No new GatewayIntentBits needed
`GatewayIntentBits.GuildMessages` already includes thread messages. No intent changes required.

## User experience
- {{USER_JERRY}} starts a thread on any message → replies in that thread → Marvin responds in the thread only
- Each thread has its own clean context window and channel-state file
- Auto-resume works per thread (checkpoint stored under thread channel_id)
- Parent channel routing still works for workspace CLAUDE.md selection

## Estimate
~40 lines of bot.js changes. No new dependencies.
