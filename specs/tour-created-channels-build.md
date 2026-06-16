# TOUR-CREATED-CHANNELS-001 — Tour only already-created channels, then build first workspace

**Decision ({{USER_JERRY}} 2026-06-16):** The onboarding tour must walk ONLY the channels that have
actually been created at tour time — do not reference channels that don't exist yet. Right
after the tour, the flow builds the user's first workspace (first real value), rather than
ending the tour and leaving the user idle.

## Why
Earlier flow risked touring a fixed list of channels (e.g. a hardcoded 6) regardless of what
the bot actually created, which produces dead references and confusion. Tour content must be
generated from the live channel set the bot created during setup.

## Required behavior
1. **Tour source = live channel set.** Enumerate the channels the bot actually created in the
   user's server (from the channel-ID map written at install), and tour those in order. Never
   reference a channel that wasn't created.
2. **Tour → first workspace handoff.** Immediately after the last tour channel, transition into
   building the user's first workspace (the first concrete value), per P5.1. No idle dead-end.
3. Keep tour copy in the user's actual bot name (depends on MENTION-REMOVE-001 for name
   rendering — sequence after or coordinate).

## Success criteria (must be tested, not asserted)
- Tour iterates the created-channel list dynamically; removing/adding a created channel changes
  the tour with no code edit.
- After the final tour step, the flow invokes the first-workspace build path (cite the bot.js
  line/handler that does this).
- Synthetic test: simulate a channel set of N created channels → tour references exactly those
  N, in order, then enters the workspace-build step. Paste output in DELIVER.
- Prevention: assertion that the tour channel list is derived from the created-channel map, not
  a hardcoded array.
