# Instructions for Onboarding and Workspace Threads

Copy these instructions into the appropriate Discord threads.

---

## For #onboarding Thread

**Subject: HELM Recovery System — Bot Setup Instructions**

---

The HELM recovery system requires **two Discord bots** to work correctly. Here's the step-by-step setup:

### What These Bots Do

- **Main HELM Bot** — orchestrates everything, runs on the user's Mac
- **Lifeline Bot** — backup recovery bot, works independently, responds even when main HELM is completely down

### Create Main HELM Bot (5 min)

1. Go to [Discord Developer Portal](https://discord.com/developers/applications)
2. Click **New Application** → name it `HELM` → **Create**
3. Go to **Bot** section → **Add Bot**
4. Under **TOKEN**, click **Copy** → save as `HELM_BOT_TOKEN` in password manager
5. Scroll to **Intents** → enable:
   - ✅ **Message Content Intent**
   - ✅ **Server Members Intent**
6. Go to **OAuth2** → **URL Generator**
   - Scopes: `bot`
   - Permissions: `Send Messages`, `Read Messages`, `Read History`, `Manage Messages`, `Embed Links`
7. Copy generated URL → paste in browser → **Authorize** to your server

### Create Lifeline Bot (5 min)

1. Go to [Discord Developer Portal](https://discord.com/developers/applications)
2. Click **New Application** → name it `HELM Lifeline` → **Create**
3. Go to **Bot** section → **Add Bot**
4. Under **TOKEN**, click **Copy**
5. **Save to 1Password:**
   - Open 1Password → **HELM Vault**
   - Create new entry:
     - Name: `HELM Lifeline Bot Token`
     - Type: `Login` or `Password`
     - Password field: [paste token from step 4]
   - Save
6. Scroll to **Intents** → enable:
   - ✅ **Message Content Intent**
7. Go to **OAuth2** → **URL Generator**
   - Scopes: `bot`
   - Permissions: `Send Messages`, `Read Messages`, `Read History`
8. Copy URL → paste → **Authorize** to your server

### Store Recovery Password (2 min)

Your **{{USER_DOMAIN}} Site Auth password** protects the recovery webpage. It's already in 1Password, but verify:

1. Open 1Password → **HELM Vault**
2. Search `{{USER_DOMAIN}} Site Auth`
3. Verify password is there (same one protecting all {{USER_DOMAIN}} sites)
4. If missing: create it with that password

### Test Recovery (2 min)

**Test Lifeline Bot:**
- In any Discord channel, type: `!status`
- Should respond: `✅ Connection Test complete`

**Test Recovery Webpage:**
- Go to `https://status.{{USER_DOMAIN}}/recovery`
- Sign in with {{USER_DOMAIN}} password
- Click **Test Connection**
- Should show: `✅ Test Connection complete`

### Done!

Recovery is now active. When HELM goes silent:
1. Type `!restart` in Discord (Lifeline Bot)
2. If that doesn't work, use the webpage: `https://status.{{USER_DOMAIN}}/recovery`
3. If both fail, power-cycle the Mac

Full guide: see **#helm-recovery** for the complete RECOVERY-GUIDE.md with all failure modes.

---

## For Workspace Integration Thread

**Subject: Recovery Buttons in Workspace Channels**

---

To integrate recovery controls directly into workspace channels (so users can restart HELM from #options-helper, #etf-tracker, etc.):

### What Gets Added

A pinned message in the workspace channel with:
- **System Status** button → is HELM online?
- **Restart Bot** button → SSH restart (~30s)
- **Rollback** button → restore yesterday's version (~60s)
- **Recovery Webpage** link
- **AI Help** link

### Implementation

**Step 1: Update bot.js**

Find the `buildRecoveryContent()` function in `bot.js` (line ~3320).

Add workspace channels to recovery posting list:

```javascript
const WORKSPACE_RECOVERY_CHANNELS = [
  RECOVERY_CHANNEL,          // #helm-recovery
  OPTIONS_HELPER_CHANNEL,    // #options-helper
  ETF_TRACKER_CHANNEL,       // #etf-tracker
  // Add other workspace channels here
];
```

This will pin recovery buttons to all these channels on bot startup.

**Step 2: Test**

1. Restart the main HELM bot: `!restart` in #helm-recovery
2. Check the workspace channel (e.g., #options-helper)
3. Look for pinned message with recovery buttons
4. Click **Test Connection** — should respond with bot status
5. Click **Restart Bot** — should take ~30s

**Step 3: Document**

In the workspace's `CLAUDE.md`, add:

```markdown
## Recovery
When this workspace stops working:
- Type `!restart` in #helm-recovery (or click Restart button here)
- If that doesn't work: go to https://status.{{USER_DOMAIN}}/recovery
- Still stuck? Use AI help: https://status.{{USER_DOMAIN}}/recovery/prompt
```

### That's It

Recovery buttons are now integrated. Users can restart HELM without leaving the workspace channel.

---

## Quick Reference

| What | How | Time |
|---|---|---|
| Create Main Bot | Developer Portal → New App → Add Bot | 5 min |
| Create Lifeline Bot | Developer Portal → New App → Add Bot → Save token to 1Password | 5 min |
| Test Recovery | Type `!status` in Discord + visit recovery webpage | 2 min |
| Add workspace buttons | Update bot.js + restart bot | 5 min |

**If stuck on any step:** Check the full setup guide at `/Users/{{USER_HOME}}/helm-workspace/specs/HELM-RECOVERY-ONBOARDING.md`
