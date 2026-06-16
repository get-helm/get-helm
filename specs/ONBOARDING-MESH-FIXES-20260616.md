# Onboarding Mesh Fixes — verified 2026-06-16 (PM audit round 2)

Three locked P5.1/checklist Phase-3 decisions are NOT built in bot.js. Code verified by read-back at the cited lines. All Level 2 (onboarding behavior, no routing/lifecycle change).

## ONBOARD-TOUR-ORDER-001 — tour fires before prefs AND multiple times
**Locked decision:** P5.1 / checklist 3.4 + Appendix B — tour fires ONCE, AFTER Stage 1 + Stage 2.
**Actual (bot.js):**
- Line ~4302 `TOUR-FIRST-USER-001` first-boot block: fires the full 5-step tour in #general 8s after boot — BEFORE any preferences. This is the path the installer actually hits (comment at 4292 confirms GUILD_MEMBER_ADD never fires for the installer).
- Line ~4823 guild-create auto-init: also posts the tour on init, before prefs.
- Line ~4840 `GUILD_MEMBER_ADD`: startTourForNewMember — tour before prefs for any later join.
- Line ~3021/3022 Stage-2 completion: fires the tour AGAIN (this one is correct per P5.1).
**Result:** real user gets the tour before preferences, then a second time after Stage 2.
**Fix:** Gate all pre-preference tour triggers (4302, 4823, 4840) on `ONBOARDING_COMPLETED === 'true'`. The only tour fire is the one after Stage-2 completion (3021/3022). Welcome/online message should invite the user to begin setup, not launch the tour.
**Test:** fresh CONFIG.md (no ONBOARDING_COMPLETED) → boot → assert no tour posted; complete Stage 1+2 → assert exactly one tour sequence fires.

## ONBOARD-STAGE1-ENTRY-001 — Stage 1 entry is unprompted
**Actual:** Stage 1 only starts on the user's first message (bot.js ~7278-7280). The welcome copy ("✅ {name} is set up — just type in any channel to get started" line ~4822; "Welcome! HELM is online…" line ~4302) never tells the user that typing begins a short setup. A user can take the tour, go to #new-workspace, and never knowingly trigger the preference flow.
**Fix:** First #general message after install should explicitly invite the first reply to start setup (e.g., "Say hi here and I'll set up your preferences — takes about a minute"). Align the entry trigger with the welcome copy.
**Test:** boot fresh → welcome message contains an explicit "reply to begin" prompt → first reply launches stage1_q1.

## ONBOARD-TIMEZONE-001 — timezone never collected
**Locked decision:** checklist 3.3 — Stage 2 collects "date/time/week/**timezone**".
**Actual:** ONBOARDING_STEPS Stage 2 (bot.js ~2974-2980) collects PREFERRED_TONE, quiet hours, PROACTIVE_OUTREACH, USAGE_WARNING_THRESHOLD, DATE_FORMAT, TIME_FORMAT, WEEK_STARTS_ON — **no timezone question**. Quiet hours saved as literal "22:00"/"07:00" (line ~3008) with no tz. Only tz reference in bot.js is hardcoded `America/Los_Angeles` (line ~6891).
**Result:** every user's quiet hours + briefing time run in {{USER_JERRY}}'s Pacific time.
**Fix:** add a timezone question to Stage 2 (before or after date/time), save `TIMEZONE`, and make quiet-hours/briefing scheduling tz-aware. Provide a sane picker (common zones + "type your city/zone").
**Test:** set TIMEZONE=America/New_York → quiet-hours boundary computed in ET, not PT.

## ONBOARD-CONNECTOR-CLAUDE-NATIVE-001 — connector + first briefing not built; completion msg contradicts G-E
**Locked decision (G-E + G-J, Appendix B):** user must NOT leave onboarding with an empty/deferred briefing. In-flow: ask provider (never assume Gmail) → guide Settings → Connectors (Claude-native, no OAuth infra) → run "what's on my calendar?" test → generate first real briefing → graceful degrade if skipped.
**Actual:** COMPLETE_MSG (bot.js ~2996) says "Daily briefing starts once you connect a calendar or email (say **connect** in #preferences when ready)" — exactly the deferred/empty framing G-E removed. There is NO connector provider-ask, NO Settings→Connectors walkthrough, NO calendar test, NO first briefing. There is also NO `connect` keyword handler anywhere in bot.js — the instruction dead-ends.
**Fix:** build the in-flow connector step after Stage 2 (before/with the tour): provider-ask → exact Settings → Connectors clicks → tool-visibility test → real first briefing. Rewrite COMPLETE_MSG to match. Add a `connect` handler so the fallback instruction works. Caveat: claude-code#62479 (connector tools may show as stubs in non-interactive session) — confirm via beta (rolled into G1).
**Test:** complete onboarding with a connected calendar → a real briefing is shown before exit; skip connectors → briefing states what's missing + how to connect (never silently empty); type "connect" → walkthrough starts.

## Systemic note
All four were queued in prior PM rounds; the engineer queue is now clear of them with NO done records in task-registry.jsonl. The locked work fell out of the queue without being built — this is the recurring "queue → build" drop, not a spec gap.
