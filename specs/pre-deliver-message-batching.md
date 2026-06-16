# Pre-DELIVER Message Batching

**Status:** Queued for engineer  
**Date:** 2026-06-06

---

## Problem

When a user posts multiple messages in quick succession, each message triggers a separate agent invocation. The user gets 3 responses to 3 messages instead of 1 combined response. This wastes tokens and forces users to write longer single messages instead of posting thoughts as they form.

## Design

**Collection window is pre-DELIVER, not pre-invocation.**

The agent fires immediately on the first message (no delay). Before posting DELIVER, the agent checks whether the user has posted additional messages since the invocation began. If yes, it incorporates them into a single combined response.

### Flow

**Normal (no new messages during processing):**
```
0s:  User posts message 1
0s:  Agent invoked, ACK posted immediately
75s: Agent ready to DELIVER — no new messages — posts DELIVER
```

**With batching (new messages arrived during processing):**
```
0s:  User posts message 1
0s:  Agent invoked, ACK posted immediately
25s: User posts message 2 (agent still processing)
55s: User posts message 3 (agent still processing)
75s: Agent ready to DELIVER — detects messages 2 and 3 — updates ACK with new ETA
150s: Agent posts single DELIVER addressing all 3 messages
```

### Overflow rule (important)

**Only collect once.** If the user keeps posting messages after the re-ACK is sent, the agent does NOT extend again. It posts DELIVER with the messages it committed to at the re-ACK point, then handles any remaining messages as a fresh invocation.

This prevents an infinite delay loop where an active user never gets a response.

**Example:**
```
0s:   User posts message 1 → agent invoked
25s:  User posts message 2
55s:  User posts message 3
75s:  Agent detects msgs 2+3, re-ACKs: "Combining your last 3 messages — responding in ~75s"
80s:  User posts message 4 (after re-ACK)
150s: Agent DELIVERs response to messages 1, 2, 3 (combined)
      Message 4 triggers a fresh invocation separately
```

### Re-ACK format

When the agent detects new messages and extends:
```
⏳ Got your follow-ups — combining all [N] messages into one response. 
Updated ETA: ~[X] seconds.
```

### What counts as "new messages"

Only messages from the same user in the same channel, posted after the agent's ACK timestamp. System messages, other users' messages, and bot messages are ignored.

---

## Implementation Notes (for bot.js engineer)

1. **At agent invocation:** record the timestamp of the triggering message(s) + channel + user ID in a per-invocation context object.
2. **Before posting DELIVER:** query Discord API (or local message buffer) for messages from the same user/channel with timestamp > invocation start.
3. **If new messages found:**
   - Edit the existing ACK message with updated ETA
   - Append new message content to the agent's input context
   - Re-run only the response generation step (not the full invocation — ACK already exists)
   - Set a flag: `batching_extended = true` so this channel/user combo is not eligible for another extension until DELIVER posts
4. **After DELIVER posts:** clear the extension flag. Any messages that arrived after the re-ACK timestamp are now fresh inputs.

## Success Criteria

- User posts 3 messages over 55 seconds → gets 1 DELIVER that addresses all 3
- Response to message 1 alone takes same time as today (no added pre-invocation delay)
- If user posts message 4 after re-ACK, it is handled as a fresh invocation, not appended again
- Re-ACK is visible as an update to the original ACK (not a new message)

---

## Out of Scope

- Multi-user message combining (only same user, same channel)
- Channel-specific debounce windows (keep it uniform for now)
- Voice/attachment messages (text messages only for v1)
