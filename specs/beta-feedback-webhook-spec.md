# Beta Feedback Webhook — Design Spec

Status: DRAFT — awaiting {{USER_JERRY}} approval (raised 2026-06-10, thread {{USER_CHANNEL_BETA_USERS}})
Owner: PM / engineer once approved

## Goal
Beta users' HELM instances send feedback (bugs, ideas, praise) back to {{USER_JERRY}}'s server so he sees real usage signal without asking users to email or join his Discord.

## Recommended v1 — Discord webhook relay (zero new infra)

**User side (ships in platform repo):**
- `/feedback` command or message in the user's #feedback channel → their bot.js builds a JSON payload and POSTs to a Discord webhook URL stored in their CONFIG.md (`FEEDBACK_WEBHOOK_URL`).
- Payload: `instance_id` (random UUID generated at install — never name/email), `helm_version`, `category` (bug | idea | praise), `message` (user text), `context` (optional, last error line only).
- **Sender-side scrub (mandatory):** payload runs through `helm-personal-data-scan.sh --fix` before send. Nothing auto-attached; no logs, no file contents.

**{{USER_JERRY}} side:**
- Private channel `#beta-feedback` on {{USER_JERRY}}'s server, Discord webhook created there.
- PM sweep reads new posts during T2; bug-category items get triaged into the normal queue flow.

## Why webhook over VPS endpoint (v1)
- No new service, no auth code, no uptime burden. Discord rate-limits webhooks natively.
- Tradeoff: webhook URL in user configs = leak risk → spam. Acceptable for a small known beta cohort; URL is rotatable in one place if abused.

## v2 upgrade path (only if beta grows / abuse appears)
VPS relay endpoint with per-instance tokens, dedup, and rate-limiting; forwards to the same channel. Swap is one CONFIG.md value per user.

## Build steps (after approval)
1. Create #beta-feedback channel + webhook on {{USER_JERRY}}'s server (L2, reversible).
2. Add sender code + scrub hook to bot.js feedback path (platform repo side).
3. Test: fire one payload from {{USER_JERRY}}'s own instance (sandbox = first beta user).
4. Add PM T2 sweep step: read #beta-feedback since last sweep.

## Open questions for {{USER_JERRY}}
- Category set OK (bug/idea/praise) or add "question"?
- Should praise/ideas also reach the channel, or bugs only with the rest batched weekly?
