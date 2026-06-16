# HC.io → Discord Webhook Setup

**Status:** Webhook created and stored. Needs {{USER_JERRY}} to wire on healthchecks.io side.

## What's already done (engineer)
- Discord webhook created for #helm-status: `HC.io Healthcheck Alert`
- Webhook URL stored in HELM Vault as "HC.io Discord Webhook"
- Tested: HTTP 204 confirmed (message appeared in #helm-status)

## What {{USER_JERRY}} needs to do (5 min, one-time)

1. Go to [healthchecks.io](https://healthchecks.io) → log in → find the HELM check
2. Click the check → **Integrations** tab → **Add Integration**
3. Select **Discord**
4. Paste this webhook URL (from HELM Vault → "HC.io Discord Webhook" → reveal):
   ```
   https://discord.com/api/webhooks/1515588915346800700/[token]
   ```
5. Set **down after:** 5 minutes (default is fine)
6. Click **Save**

## How to verify
Kill bot.js: `pkill -f "node.*bot.js"` → wait 5 min → check #helm-status for HC.io alert.
HELM can be down and the alert still arrives (webhook goes direct to Discord, not through HELM).

## Why this matters
When HELM is silent (crash, Mac Mini asleep, power outage), HC.io fires the alert directly to Discord without needing HELM to be alive. Current gap: HELM must be alive to post "I'm down" alerts, which is circular.
