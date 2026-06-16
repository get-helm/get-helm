# Rich Discord UI — bot.js Spec
Created: 2026-05-09

## Why
{{USER_JERRY}} gets multi-topic responses and has to type out which number he's replying to.
Buttons attached to each message topic eliminate that friction and make mobile interaction fast.

## What this enables
- Every DELIVER with numbered items gets a button row per item: "More on 1", "More on 2", etc.
- BLOCK messages get Yes/No or option buttons inline — no typing required
- Approval requests get [Approve] [Reject] buttons
- Threads are spawned automatically when a button is clicked — clutter stays out of main channel

## Discord mechanism
Discord Message Components: ActionRow + Button objects attached to the message payload.
These are separate from message content — they render below the message as tappable buttons.
Maximum: 5 buttons per ActionRow, 5 ActionRows per message (25 buttons max).

## Implementation

### 1. Sentinel parsing in bot.js
Agents write a sentinel in their output to declare button options:
```
[BUTTONS: More on 1|topic_1, More on 2|topic_2, Approve|approve, Skip|skip]
```
bot.js strips the sentinel before posting and converts it to a Discord components array.

### 2. Button interaction handling
When a button is clicked:
- Discord fires `INTERACTION_CREATE` event with `data.custom_id`
- bot.js matches `custom_id` to the originating message/channel/topic
- bot.js spawns the appropriate agent with injected context:
  `[{{USER_JERRY}} tapped: "More on 1". Original topic: {topic_text}. Continue from there.]`
- Response goes into a thread off the original message (not a new main-channel message)

### 3. Standard button sets per message type

**DELIVER with numbered items:**
```
[More on 1] [More on 2] [More on 3] [Done]
```
- Items beyond 4 get a "More..." button that expands remaining options
- "Done" dismisses without spawning

**BLOCK:**
```
[Yes, proceed] [No, stop] [Tell me more first]
```

**Approval request:**
```
[Approve] [Reject] [Modify]
```

**Long single-topic response:**
```
[Summary only] [Full detail] [Next step]
```

### 4. Button label generation
Labels are auto-generated from the first 6 words of each numbered item.
Example: "1. Auto context reset — bot.js counts..." → label: "Auto context reset"
Labels capped at 80 characters per Discord limit.

### 5. Thread spawning on click
Button click → bot.js creates a thread off the original message → spawns agent in thread context.
Thread name = button label (truncated to 100 chars, Discord thread name limit).
This keeps main channel clean: only the original message + button row visible.

### 6. State — custom_id encoding
custom_id format: `{action}_{messageId}_{channelId}_{topicIndex}`
Example: `more_1234567890_9876543210_1`
This lets bot.js recover full context from any button click without a lookup table.

## Changes to bot.js

### After posting any agent message:
1. Parse message content for `[BUTTONS: ...]` sentinel
2. If found: strip sentinel from content, parse button definitions
3. Call Discord API to post message WITH components array
4. Register interaction handler for each custom_id

### New event listener:
```js
if (event.t === 'INTERACTION_CREATE' && data.type === 3) { // type 3 = MessageComponent
  handleButtonClick(data);
}
```

### handleButtonClick():
1. Parse custom_id to recover action, messageId, channelId, topicIndex
2. Fetch original message for context
3. If action === 'more': spawn agent in thread with topic context injected
4. If action === 'approve'/'reject': write to channel-state and resume blocked agent
5. If action === 'done': ACK interaction (required by Discord) and do nothing

### Required: ACK every interaction within 3 seconds
Discord requires acknowledging every interaction within 3s or it shows "interaction failed."
Pattern: immediately POST to interaction endpoint with `type: 6` (deferred ACK), then do work.

## Channels
All channels. Thread creation is the mechanism that keeps main channels clean.
Threads also get button rows — buttons in threads spawn sub-threads or reply inline.

## Notification impact
Button clicks do NOT trigger a new message notification in Discord — they fire an interaction.
This means button-driven responses are silent for notification purposes, which is what {{USER_JERRY}} wants.
Only final DELIVER messages (which are new messages) generate notifications.

## Estimate
~120 lines of bot.js changes. Requires:
- One new event listener (INTERACTION_CREATE)
- Message post wrapper that handles components
- handleButtonClick() function
- Thread creation helper (shared with thread-support-spec.md)

No new Discord intents needed — `GuildMessageReactions` already covers this.
Actually: need to verify bot has `applications.commands` scope. Check bot invite URL.

## Dependencies
- Thread support spec must be implemented first (thread creation helper is shared)
- Implement thread support → then Rich UI (thread support is ~40 lines; Rich UI is ~120 lines)
