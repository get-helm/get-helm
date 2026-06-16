# Auto Context Reset — bot.js Spec
Created: 2026-05-09

## Why
Long conversations cause context rot. LLM instruction-following degrades after ~20 messages / ~3,000 tokens of system context. Currently: user has to manually say "fresh start." This should be invisible and automatic.

## How it works

### 1. Message counter in channel state
Add `userMessageCount` to channel state JSON. Increment on every user MESSAGE_CREATE (not bot messages).

### 2. Threshold check before spawn
Before spawning any agent, check `userMessageCount` against threshold (default: 15 messages).

### 3. On threshold hit
1. bot.js writes a compact state summary to ACTIVE-STATE.md using a lightweight Haiku call (or a template from current channel state + checkpoint)
2. Reset `userMessageCount` to 0
3. Spawn the agent with the ACTIVE-STATE.md summary injected at the TOP of the context (not buried in the middle — research shows beginning/end of context is remembered, middle is lost)
4. Add a note to the spawn context: "[Auto-reset: conversation compacted. State summary loaded from ACTIVE-STATE.md. Treat this as a fresh session.]"

### 4. ACTIVE-STATE.md template written by bot.js
```
# PAP Active State — Auto-reset [timestamp]
## Current task: [from checkpoint.requestText]
## Current step: [checkpoint.currentStep] of [checkpoint.totalSteps]
## Last agent message: [lastAgentMsgContent]
## Channel: [channelId]
## Key context: [checkpoint.notes]
```

### 5. No user action required
The reset is silent. Agent picks up in the same conversation thread without interruption.

## Threshold tuning
- Default: 15 user messages
- Configurable via CONFIG.md: `CONTEXT_RESET_THRESHOLD=15`
- Thread channels: lower threshold (10) since threads are topic-focused

## Research backing
Anthropic's context engineering guide confirms: "context rot" is real. Models perform best when key information is at the very START of context. The auto-reset puts state summary first, before the conversation history, matching this pattern.

## Estimate
~60 lines of bot.js changes. Requires Haiku API call for summarization step (optional — template version works without it and is cheaper).
