# Onboarding Notification Channel — Design Proposal
## For: Onboarding Agent
## Status: Design — not yet built

---

## The Problem

HELM needs to reach users when Discord is down. Discord is the primary interface — but
it's also the most likely thing to be unavailable during an outage. Without a fallback
channel, users don't know HELM is down until they happen to check Discord.

Not all users will have ntfy or even a reliable email. We can't make it required
(friction kills installs) but we need to incentivize it strongly.

---

## Proposed Approach: Progressive Notification Setup

### At Onboarding — Required Prompt (not optional)

Frame it as a safety question, not a settings question:

> "If Discord stops working, how should I reach you?
> This is how you'll know HELM is offline before you happen to notice."

**Offer 4 options, ranked by recommendation:**

| Option | Friction | Reliability | Recommended? |
|--------|----------|-------------|--------------|
| ntfy (push notification) | Low (free app, no account) | High | ✅ First offer |
| Email | Zero (everyone has it) | Medium (may land in spam) | ✅ Strong fallback |
| Text/SMS | Low (phone number) | High | Offer if no ntfy |
| Skip for now | None | None | Available but discouraged |

**UX:** Present as [BUTTON] options, not a form. One tap to pick. They can skip,
but HELM should note "No fallback configured — you won't know if I go offline"
and offer to set it up again from #preferences.

---

## Recommended Default: ntfy

ntfy is:
- Free with no account required (self-hosted or ntfy.sh)
- Simple: share one topic URL, HELM subscribes, done
- Already integrated in {{USER_JERRY}}'s HELM install (proven)
- Works on iOS and Android

**Onboarding flow for ntfy:**
1. "Download the ntfy app on your phone"  → [Button: Done]
2. "Your notification channel is ready — HELM will post here if Discord goes offline"
3. [BACKGROUND: write ntfy_topic to user config, test-post "HELM connected"]

---

## Recommended Fallback: Email

If user skips ntfy:
- "What's your email? This is only used for critical alerts."
- [TEXT: email address]
- Validate format, confirm with a test send
- [BACKGROUND: write notification_email to config]

---

## What Happens If User Skips Both

- Log `notification_configured = false` in user config
- Post weekly reminder in #preferences: "No fallback set. If Discord goes offline, I can't reach you."
- Steward surfaces this in weekly health sweep (low-key, not alarming)

---

## What HELM Sends (scope: critical only)

To avoid notification fatigue, out-of-band alerts are limited to:
1. **HELM offline** — clean machine unreachable or bot crashed
2. **VPS down** — VPS watchdog missed 2+ heartbeats
3. **Critical task failure** — financial data unavailable, backup failed
4. **"I'm back"** — confirmation that HELM is restored after an outage

No routine updates, no summaries, no scheduled reports via out-of-band channels.
Notification fatigue = users turn it off = defeats the purpose.

---

## Implementation Notes for Onboarding Agent

1. Add this question to the onboarding flow at Step 5 (after Discord setup, before workspace creation)
2. ntfy topic should be auto-generated as `helm-[user-id]` on ntfy.sh unless user provides their own
3. Test-post immediately after setup to confirm it works ("HELM connected — you'll be notified here if Discord goes offline")
4. Store in user config: `notification_channel`, `notification_type` (ntfy/email/sms/none), `notification_value`
5. Steward weekly check should verify `notification_configured = true` and flag if not

---

*Created: 2026-06-05*
*Owner: Onboarding agent*
*Depends on: Onboarding script (pap-onboarding-script.md)*
