# Staged Posting Architecture

**Status:** Queued for engineer  
**Date:** 2026-06-06  
**Engineer ID:** ENG-STAGED-POST-001

---

## Problem

The current system has agents post directly to Discord via `discord-post.sh`. This means bot.js has no visibility or interception point between an agent completing its work and the message appearing in Discord.

This creates a structural gap for pre-DELIVER message batching (spec: `pre-deliver-message-batching.md`): by the time an agent is ready to DELIVER, bot.js cannot check whether the user posted more messages — because the agent bypasses bot.js entirely on the way out.

---

## Solution: Two-Phase Post

Replace direct-post with a stage → dispatch loop:

**Phase 1 — Agent stages its output**  
Instead of calling `discord-post.sh` to post a DELIVER, the agent writes its message to a staging file:
```
~/pap-workspace/post-queue/[channel_id]-[timestamp]-[uuid].json
```

File format:
```json
{
  "channel_id": "1513016423373602897",
  "invocation_id": "abc123",
  "phase": "DELIVER",
  "content": "✅ DELIVER — ...",
  "staged_at": 1717700000,
  "invocation_started_at": 1717699925,
  "user_id": "123456789"
}
```

Agent exits after staging. It does NOT post to Discord directly.

**Phase 2 — bot.js dispatches from the queue**  
bot.js runs a polling loop (every 2 seconds) watching `~/pap-workspace/post-queue/`. When a file appears:

1. Read the staged message
2. If `phase == "DELIVER"`: check Discord for messages from `user_id` in `channel_id` with timestamp > `invocation_started_at`
3. **If new messages found** (pre-DELIVER batching rule from `pre-deliver-message-batching.md`):
   - **Substance filter (mandatory before re-invoking):** classify each new message as substantive or noise. Noise: single emoji, reactions, "👍", "ok", "got it", "thanks", messages under 10 characters. If ALL new messages are noise → post DELIVER as-is. Only re-invoke if at least one message is substantive.
   - **Re-invoke count check:** read `batching_reinvoke_count` from `channel-state/[channel_id].json`. If count >= 2: skip re-invocation, post DELIVER with appended note: *"You sent new messages while I was working — answered below. Address the rest in a follow-up."*
   - **If re-invoking:** pass full context to re-invoked agent — original task context + the staged DELIVER (task A answer) + new messages. Re-invoked agent MUST include task A answer in its DELIVER, then address new messages. It must not silently drop the original work.
   - Delete the staged file. Increment `batching_reinvoke_count`. Re-invoked agent stages a new DELIVER.
4. **If no new messages** (or all new messages are noise): post to Discord, delete staged file, reset `batching_reinvoke_count` to 0

For non-DELIVER phases (ACK, UPDATE, BLOCK): post immediately without batching check.

---

## Migration Plan

### Step 1 — Parallel mode (safe rollout)

- `discord-post.sh` gets a new flag: `--stage` 
- When `--stage` is passed, write to post-queue instead of posting directly
- When not passed, current behavior unchanged
- No agents change yet — verify the queue watcher works correctly

### Step 2 — Agent protocol update

- Update `~/.claude/agents/turn-protocol.md` to instruct agents to call `discord-post.sh --stage` for DELIVER messages only
- ACK, UPDATE, BLOCK remain direct-post (they should never be batched)
- Test in one channel before rolling to all agents

### Step 3 — Full rollout + remove legacy path

- All agents use `--stage` for DELIVER
- Remove direct-post fallback for DELIVER phase
- Delete parallel mode flag

---

## Post-Queue File Management

- Staged files are ephemeral: deleted after posting or re-invocation
- If a staged file is older than 5 minutes and hasn't been processed: post it directly (dead-agent safety valve) and log to `helm-audit.log`
- Queue directory: `~/pap-workspace/post-queue/` (create if not exists)

---

## Implementation Notes

1. **bot.js change:** Add `watchPostQueue()` function — polling interval 2s, processes files in `staged_at` order (oldest first)
2. **discord-post.sh change:** Add `--stage` flag that writes JSON to post-queue instead of calling Discord API
3. **Agent protocol change:** DELIVER phase → `discord-post.sh --stage`; ACK/UPDATE/BLOCK → `discord-post.sh` (unchanged)
4. **Batching integration:** Three fields added to `~/pap-workspace/channel-state/[channel_id].json`:
   - `batching_reinvoke_count`: integer, resets to 0 after a clean DELIVER (no re-invoke)
   - `batching_last_reinvoke_at`: timestamp, for debugging
   - `batching_staged_deliver`: content of task A answer passed to re-invoked agent so it doesn't drop original work
5. **Substance filter:** Implement in bot.js as `isSubstantiveMessage(content)` — returns false for: length < 10, pure emoji, matches list ["👍","ok","okay","got it","thanks","lol","haha","nice"]

---

## Success Criteria

- Agent stages a DELIVER → bot.js picks it up within 2 seconds and posts
- User posts substantive message 4 during agent processing → bot.js intercepts staged DELIVER, re-invokes with full context (including task A answer), one combined response that covers both
- User posts "👍" or "ok" during processing → DELIVER posts as-is, no re-invocation
- User is on a chatty roll (3+ substantive messages mid-task) → agent re-invokes at most twice, then posts with note about follow-up
- Re-invoked agent always includes original task A answer — no silent drops
- ACK/UPDATE/BLOCK messages post immediately with no staging delay
- If agent crashes mid-task: staged file timeout (5 min) triggers direct post, no silent drops
- No regression: channels without new messages get DELIVER posted at same speed as today

---

## Dependencies

- `pre-deliver-message-batching.md` (the feature this architecture enables)
- `channel-state/[channel_id].json` (for `batching_extended` flag storage)

---

## Out of Scope

- Staging for non-DELIVER phases in v1
- Multi-agent coordination via the post-queue (agents don't read each other's staged files)
- Message editing vs. new post decision (stage-and-dispatch always posts new message in v1)
