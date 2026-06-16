# Lifeline Bot Rename — Step-by-Step

## Why this matters
Currently the bot shows up in Discord as "**HELM Lifeline Bot Token#7910**" because that's the literal string you typed when creating the app. This is awkward and confusing — recovery responses appear under that name. Renaming takes 2 minutes and doesn't require regenerating the token.

## Exact steps

1. **Open the Discord Developer Portal** → https://discord.com/developers/applications
2. **Click the lifeline bot application** in your list (currently named "HELM Lifeline Bot Token" or similar)
3. **Left sidebar → General Information**
4. **"Name" field** → edit it. Recommended: `HELM Lifeline` (or `HELM Recovery`, whichever you prefer)
5. **Click Save Changes** (bottom of page)
6. **Left sidebar → Bot**
7. **"Username" field** → edit. Recommended: `helm-lifeline` (lowercase, no spaces)
8. **Click Save Changes** (bottom of page)

That's it.

## What NOT to touch
- ❌ **Do NOT click "Reset Token"** — that invalidates the current token. You'd have to update the 1Password entry and restart the bot.
- ❌ Do not change the App ID
- ❌ Do not delete the bot

## Verifying the rename
After saving in the portal, the change is instant in Discord. Send `!status` in any channel and the reply will come from the new name.

If the bot is still showing the old name after 60 seconds, restart it:
```
ssh root@status.{{USER_DOMAIN}} 'systemctl restart helm-lifeline'
```
(But this is rarely needed — Discord pulls the name from the application, not the bot session.)

## Where this lives now
The bot is deployed at `/opt/helm-lifeline/lifeline-bot.js` on the VPS (status.{{USER_DOMAIN}}), with token in `/opt/helm-lifeline/.env`. The token is stored in 1Password under "HELM Lifeline Bot Token".

## For onboarding new users
This rename step happens during initial bot creation — the user names the app themselves in the Discord Developer Portal. There's no rename needed if they choose a sensible name from the start. Pass these instructions to the onboarding thread to include in the bot-creation step.
