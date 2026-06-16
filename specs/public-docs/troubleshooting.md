# HELM — Troubleshooting Guide

Use this guide when HELM isn't behaving as expected. Start at the top and work down.

---

## Quick Diagnostics

### Step 1: Check the status indicator

Look at **#helm-status** in your Discord server:
- **🟢helm-status** — Bot is running normally
- **🔴helm-status** — Bot has stopped or is unresponsive

### Step 2: Check if the bot is responding at all

Type `ping` in **#general**. If you get a response within 10 seconds, the bot is alive. If not, proceed to the restart section.

---

## Bot Not Responding

### Option A: Soft restart (try this first)

In **#helm-recovery**, click the **Restart Bot** button. Wait 30 seconds and try `ping` in #general.

### Option B: Hard restart via terminal

```bash
~/marvin-bot/safe-restart.sh --force
```

### Option C: If you can't access the Mac

If your Mac Mini is offline or unresponsive, use the recovery page at your configured recovery URL (e.g., `https://recovery.yourdomain.com`). This page runs on your VPS and can trigger a remote restart.

Default credentials: check your 1Password vault under "HELM Recovery Access."

### Option D: If nothing works

1. Check if your Mac Mini is powered on and connected to the internet
2. Restart the Mac Mini manually
3. The bot should auto-start on reboot (it's registered as a macOS service)
4. If it doesn't start automatically: `cd ~/helm-workspace && launchctl load ~/Library/LaunchAgents/com.helm.bot.plist`

---

## Agent Stuck or Looping

**Symptom:** An agent keeps posting updates but never delivers, or posts the same thing repeatedly.

**Fix:**
1. Type `stop` or `cancel` in the channel where the agent is active
2. If the agent doesn't respond, go to **#helm-recovery** and click **Restart Bot**
3. The restart will clean up any stuck agents

**Prevention:** Agents have a built-in silence watchdog — if they go quiet for 3 minutes without finishing, they're automatically killed and the user is notified. This catches most stuck-agent cases automatically.

---

## Wrong Channel Routing

**Symptom:** You typed a request in #general but it went to the wrong agent (e.g., your idea was routed to "help" instead of "curiosity").

**What's happening:** HELM classifies your message's intent to pick the right agent. Ambiguous messages sometimes get mis-routed.

**Fix:**
1. Rephrase your request more clearly:
   - For a new idea or build request: "I want to create..." / "Build me..."
   - For a question or help: "How do I..." / "What is..."
   - For refining an existing idea: "Refine my idea about..."
2. Report the misrouting in **#helm-improvements** — the routing logic is improved based on real examples

---

## Setup Wizard Failures

### "Command not found: node"

Node.js isn't installed. Run:
```bash
brew install node
```
Then re-run `bash helm-install.sh`.

### "Permission denied" during install

You need to run the wizard from your home directory, not as root:
```bash
cd ~
bash helm-workspace/helm-install.sh
```

### Bot token is invalid

- The token must be copied exactly from the Discord Developer Portal
- Make sure you didn't include extra spaces or line breaks
- If your token was reset (you clicked "Reset Token" again after copying), you need to use the new token
- Update the token: `~/marvin-bot/update-token.sh` (follow the prompts)

### "Can't connect to Discord"

Check your internet connection. Discord's API sometimes has brief outages — check [discordstatus.com](https://discordstatus.com). If Discord is up but HELM can't connect, verify your bot token hasn't expired.

### Channels not created in Discord

The wizard creates channels via the Discord API. If channels are missing:
1. Check that your bot has "Manage Channels" permission in your server
2. Re-run channel creation: `bash ~/marvin-bot/setup-channels.sh`

---

## Morning Briefing Not Arriving

**Check 1:** Is the briefing workspace active?
- Look in **#helm-status** for a daily-brief workspace entry
- If absent, the workspace may not be running

**Check 2:** Is the schedule correct?
- Type "what time is my morning briefing?" in #general
- HELM will report the scheduled time in your timezone

**Check 3:** Did it run but deliver nothing?
- Check **#helm-audit** for `daily-brief` entries around the expected time
- A briefing with no data (empty calendar, no news) posts a minimal message that can be easy to miss

**Fix:** Type "restart my morning briefing workspace" in #general.

---

## Data or File Issues

**Symptom:** HELM references stale data, or a workspace produces wrong/outdated results.

**Fix:**
1. Type "clear cache for [workspace name]" in the workspace channel
2. If the issue persists, type "rebuild [workspace name]" — the agent will re-initialize from scratch

**Symptom:** HELM can't find a file it should know about.

**Fix:** The agent likely lost context. Type "here's the context you need: [brief description]" in the workspace channel to re-orient the agent.

---

## Getting More Help

**In Discord:** Type "help" in any channel — the help agent will respond with options specific to that context.

**Check the FAQ:** [faq.md](faq.md) covers common questions.

**Report a bug:** Type your issue in **#helm-improvements**. HELM logs all reports and addresses them in order of frequency.

**Recovery guide:** For serious issues (bot crashes, data corruption, service failures), see the detailed [RECOVERY-GUIDE.md](https://github.com/get-helm/helm/blob/main/recovery/RECOVERY-GUIDE.md) in the source repository.
