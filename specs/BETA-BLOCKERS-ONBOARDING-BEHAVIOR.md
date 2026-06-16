# Beta Blockers — Onboarding Behavior Gaps

**Created:** 2026-06-16
**Source:** HELM-INSTALL-MASTER-CHECKLIST re-audit vs P5.1 + bot.js verification.
**Why this exists:** Several P5.1 decisions are *locked in the doc but not implemented in bot.js*. This is the exact failure class the June-15 beta hit. These are the real builds between us and a non-embarrassing next beta. G1 (clean-Mac install) can only validate AFTER these land.

Each item below was verified against `~/marvin-bot/bot.js` on 2026-06-16 (grep evidence in parens).

---

## BLOCK-1 — Stage-1 (3-tap) + Stage-2 onboarding preference flow
**Status in code:** NOT built. (`grep ONBOARDING_STEP|stage1|"detail level"` → 0 hits in bot.js.)
**P5.1 requirement:** New user answers Stage 1 = exactly 3 taps (detail level, dark/light, pushback style) → Stage 2 (remaining prefs) fires *immediately after*, not Day 3. Currently prefs are only handled ad-hoc by the help agent in #preferences — there is no automatic tap flow on first contact.
**Build:**
- On first user message after init, post Stage-1 as 3 button prompts; write answers to CONFIG.md / VOICE-AND-STYLE.md.
- Immediately chain Stage-2 (tone, quiet hours, proactive cadence, usage alert, date/time/week/timezone).
- Persist progress in an `ONBOARDING_STEP` value so it survives restart.
**Success:** Fresh server → bot drives 3 taps then Stage-2 with no manual #preferences visit. CONFIG.md reflects answers.

## BLOCK-2 — Onboarding resume (ONBOARDING_STEP persistence)
**Status in code:** NOT built. (No `ONBOARDING_STEP` in bot.js.)
**P5.1 requirement:** Typing "onboarding" resumes from the saved step after a drop-off/restart.
**Build:** Persist ONBOARDING_STEP to channel-state/config; on "onboarding" (plain word, no @), resume at the saved step.
**Success:** Start onboarding, kill bot, restart, type "onboarding" → picks up at correct step.

## BLOCK-3 — Connector provider-ask + in-flow first briefing
**Status in code:** NOT built. (No provider-ask logic; Gmail refs are {{USER_JERRY}}'s relogin infra only.)
**P5.1 + locked decision ({{USER_JERRY}} 2026-06-15):** Deliver connector basics in-flow; never assume Gmail — ASK which email/calendar/drive provider. Daily briefing must work (real sample shown) before onboarding exits; if user skips all connectors, briefing gracefully states what's missing — never silently empty.
**Build:** Stage-3 connector step asks provider (Gmail/Outlook/other; Drive/OneDrive/other) → OAuth the named provider → generate a real sample briefing → show before ONBOARDING_COMPLETED.
**Success:** New user reaches a populated (or gracefully-explained) first briefing inside onboarding.

## BLOCK-4 — Credential wording: ".env" not "Vault" (G-C)
**Status:** Published prompt narration still promises "HELM Vault — never stored in plain text" but install writes the token to `~/helm/.env` plaintext. New users have no 1Password.
**Build (wording, no code):** In Phase-1/Phase-2 prompt source + P5.1 narration, replace Vault promise with: "Token stored locally in `~/helm/.env`, protected by your Mac's file permissions."
**Success:** grep of published prompts shows no "Vault" credential promise; honest .env wording present.

## BLOCK-5 — Phase-2 install runner = Claude Code CLI, not Desktop sandbox (G-H)
**Status:** Desktop Code/Local sandboxes the network during install (curl/git can fail). Phase-2 prompt doesn't account for it.
**Build (wording):** Phase-2 prompt instructs running the install/configure block via Claude Code CLI; Desktop Code tab fine for interactive use after.
**Success:** Phase-2 prompt names CLI as the install runner with the network-sandbox caveat.

## BLOCK-6 — Windows auto-start spec (G-F)
**Status:** install.sh handles WSL2; Windows auto-start (Task Scheduler / NSSM) unspecified. Windows is in beta scope (locked).
**Build:** Spec + implement Windows auto-start equivalent to launchd; verify Claude Code path on Windows.
**Success:** Documented + working Windows auto-start path.

---

## NOT blockers (verified resolved / cosmetic)
- **@-mention removal:** command parsers already use `^@?(?:AGENT_NAME)...` — `@` is optional and name is dynamic (bot.js 7332/7475). Remaining 44 `@HELM` strings are comments/console.logs/audit-reasons — not user-facing. Plain-language-without-name is a post-beta enhancement, not a beta blocker.
- **Tour channels:** TOUR-CREATED-CHANNELS-001 (shipped) derives tour channels dynamically from channels.json.
- **Channel-ID PII:** PUBLISH-PII-CHANNELS-001 shipped; publish gate fails build on known IDs.
- **Pro vs Max:** decided — $20 Pro to start; honest "heavy use may need Max" wording already in prompt (verified).
