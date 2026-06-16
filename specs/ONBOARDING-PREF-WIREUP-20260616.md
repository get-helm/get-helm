# Onboarding Preference Wire-Up + UX Copy Fixes — 2026-06-16

## ROOT CAUSE (verified by direct file inspection, not inference)

Onboarding's `save(k,v,next)` (bot.js:3087) calls `setConfigValue()` (bot.js:2956), which writes
to **CONFIG.md**. But the running agent reads its behavior from **VOICE-AND-STYLE.md** and
**ABOUT-ME.md** (loaded via `--add-dir`; VOICE-AND-STYLE.md read at bot.js:2234). CONFIG.md is
never read to shape agent behavior — only TIMEZONE works, because `getUserTimezone()` happens to
read CONFIG.md.

Result: **8 onboarding answers are collected and orphaned.** The user taps through preference
questions and none of the answers change anything.

The proven "change a setting" path (`preferences-update.sh`) already maps each preference to the
correct file with the correct transform. Onboarding must mirror it.

## ORPHANED FIELDS (collected → never read)

| Field | Collected (bot.js) | Correct destination (mirror preferences-update.sh) |
|---|---|---|
| VERBOSITY | 3091-3092 | VOICE-AND-STYLE `RESPONSE_LENGTH_PREFERENCE` + transform (preferences-update.sh:36-44) |
| DISPLAY_MODE | 3093-3094 | VOICE-AND-STYLE `DISPLAY_MODE` (preferences-update.sh:54-60; already read by preferences-pinned-update.sh) |
| PUSHBACK_STYLE | 3095-3097 | VOICE-AND-STYLE `STANDING_PREFERENCES` append_context |
| PREFERRED_TONE | 3098-3099 | VOICE-AND-STYLE `PREFERRED_TONE` + casual/professional transform (preferences-update.sh:28-35) |
| PROACTIVE_OUTREACH | 3102-3104 | VOICE-AND-STYLE `STANDING_PREFERENCES` append_context (and read by proactive-send gate) |
| NOTIFICATION_QUIET_HOURS_START/END | 3100-3101 | needs a notification-gate consumer before proactive sends (was ONBOARD-QUIET-HOURS-ENFORCE-001) |
| USAGE_WARNING_THRESHOLD | 3105-3107 | usage check at bot.js:~3862 must read it (was ONBOARD-USAGE-THRESHOLD-001) |
| DATE_FORMAT / TIME_FORMAT / WEEK_STARTS_ON | 3108-3114 | **auto-detect from machine locale at install; remove the 3 questions** (also cuts survey fatigue) |

This item SUPERSEDES the two narrow items ONBOARD-USAGE-THRESHOLD-001 and ONBOARD-QUIET-HOURS-ENFORCE-001
— fix all 8 at the source.

## REQUIRED FIX

1. Change onboarding `save()` so each preference routes to the **same destination** preferences-update.sh
   uses (VOICE-AND-STYLE.md / ABOUT-ME.md with the documented transform). Easiest: have the onboarding
   handlers shell out to / reuse the preferences-update.sh mapping rather than duplicating it, so the two
   paths can never diverge again.
2. Quiet hours: add a notification-gate check that suppresses proactive sends during the collected window.
3. Usage threshold: the usage-check path (bot.js:~3862, runs `claude-usage-hourly.sh`) must read the
   collected `USAGE_WARNING_THRESHOLD` and fire the warning at that %.
4. Date/time/week: detect from the install machine's locale during setup-headless.sh; drop the 3 Discord
   questions (`s2e_date`, `s2e_time`, `s2e_week`) and re-stitch the step chain so s2d → connector step.

## TESTS (each must prove the answer now changes a file the agent reads)
- For each of VERBOSITY/DISPLAY_MODE/PUSHBACK_STYLE/PREFERRED_TONE/PROACTIVE_OUTREACH: simulate the
  onboarding tap, then `grep` VOICE-AND-STYLE.md (or ABOUT-ME.md) and show the value/transform landed.
- Quiet hours: simulate a proactive send inside the window → assert it's suppressed.
- Usage threshold: set 70, simulate 72% usage → assert warning fires (and does NOT at 85 default).
- Locale: run setup with a non-US locale → assert DATE/TIME/WEEK match locale and the 3 questions are skipped.

## UX COPY FIXES (from the 38-step walkthrough — apply in the same batch)
Surfaces: install prompt `specs/helm-cowork-install-prompt.md`, bot.js tour/COMPLETE_MSG strings, P5.1.
1. **De-terrify the wipe step:** add point-of-no-return + "nothing touches your daily machine/phone" before
   "Erase All Content and Settings."
2. **De-terrify Administrator grant:** "manages your private server for you — only inside your own HELM
   server, nowhere else."
3. **Explain "Privileged Gateway Intents":** "these let [AGENT_NAME] read and respond to your messages."
4. **Align the price story:** landing + Step 1.5 both say "$20 to start (Pro); heavy daily use may need Max
   ($100) — upgrade only if you hit limits." No mid-flow surprise.
5. **One time estimate:** reconcile 45-60 / 35-45 / 20-30 / 15 min into one end-to-end + one per-phase number.
6. **ID-copy hints + friendly validation:** "a long string of numbers, ~17-18 digits"; on fail, "that looks
   like a channel ID, not the server — right-click the server name and try again."
7. **Fix "no commands" contradiction:** tour step 3 should set up pause/connect as handy shortcuts, not deny
   commands exist.
8. **Move token-paste safety note BEFORE the paste, not after** (anxiety-first).
9. **Optional-step consequence:** GitHub-backup Skip and connector Skip should each state what's lost.
10. **Delete the stale `specs/helm-cowork-prompt.md`** (Cowork variant) — publish-pipeline landmine; keep only
    the Code/Local `helm-cowork-install-prompt.md`.

## Reversibility
All changes are reversible: revert the bot.js onboarding routing commit; restore deleted spec from git.
