# HELM Friend Patch — Direct Claude Code Instructions
# Version 2 — 2026-06-16. No research delegation. Every step is an exact command.

---

Paste this into your friend's Claude Code session. Each step tells Claude Code exactly
what to run and exactly what to do with the output. No questions to "ask HELM."

---

## PART 1 — Fix onboarding so it runs from the beginning

**Step 1: Find CONFIG.md**
```bash
find ~/helm-workspace -name "CONFIG.md" 2>/dev/null | head -3
```
Expected output: one path like `~/helm-workspace/CONFIG.md`
If no output: run `find ~ -name "CONFIG.md" -not -path "*/node_modules/*" 2>/dev/null | head -5`

**Step 2: Check the current onboarding state**
```bash
grep -E "ONBOARDING_COMPLETED|ONBOARDING_STEP|AGENT_NAME" ~/helm-workspace/CONFIG.md
```
You will likely see `ONBOARDING_COMPLETED: true` — that's the lock we need to break.

**Step 3: Reset the onboarding lock**
```bash
sed -i.bak 's/ONBOARDING_COMPLETED: true/ONBOARDING_COMPLETED: false/' ~/helm-workspace/CONFIG.md
sed -i.bak 's/^ONBOARDING_STEP: .*/ONBOARDING_STEP: stage1_q1/' ~/helm-workspace/CONFIG.md
```
Then verify:
```bash
grep -E "ONBOARDING_COMPLETED|ONBOARDING_STEP" ~/helm-workspace/CONFIG.md
```
Expected: `ONBOARDING_COMPLETED: false` and `ONBOARDING_STEP: stage1_q1`

If ONBOARDING_STEP line doesn't exist yet:
```bash
echo "ONBOARDING_STEP: stage1_q1" >> ~/helm-workspace/CONFIG.md
```

---

## PART 2 — Fix #new-workspace so it launches workspace creation

**Step 4: Verify the #new-workspace channel name in Discord**
The bot routes to workspace creation ONLY if the Discord channel is named exactly
`new-workspace` (no # symbol, no spaces, no capital letters).

Run:
```bash
grep -i "new.workspace\|NEW_WORKSPACE" ~/helm-workspace/channels.json 2>/dev/null || echo "channels.json has no new-workspace entry"
```

Then check the channel setup:
```bash
cat ~/helm-workspace/channels.json 2>/dev/null | python3 -m json.tool 2>/dev/null | grep -i "workspace\|general\|capture\|help"
```

If the channel IDs are present and the Discord channel is named exactly `new-workspace`, 
typing a message in that channel should trigger the workspace creation flow.

If channels.json is missing or empty, run:
```bash
ls ~/helm-workspace/channels.json 2>/dev/null && echo "file exists" || echo "MISSING — bot may not know channel IDs"
```
If MISSING: the bot is using default hardcoded channel names. As long as your Discord channels
are named exactly `new-workspace`, `general`, `capture`, `help`, `preferences`, `daily-briefing`
the routing should work.

---

## PART 3 — Pull the latest code fixes

**Step 5: Update bot to latest version**
```bash
cd ~/helm/marvin-bot && git pull origin main
```
Expected: "Already up to date." or a list of updated files. Either is fine.

If git pull fails with "permission denied" or "not a git repo":
```bash
ls ~/helm/marvin-bot/bot.js && echo "bot.js exists"
```
If bot.js exists, the code is there — skip git pull and continue.

---

## PART 4 — Restart the bot

**Step 6: Stop and restart**
```bash
pkill -f "node.*bot.js" 2>/dev/null; sleep 2; cd ~/helm/marvin-bot && node bot.js >> ~/helm-workspace/system/marvin.log 2>&1 &
echo "Bot started. PID: $!"
```
Wait 5 seconds, then verify it's running:
```bash
pgrep -fl "node.*bot.js" || echo "Bot did not start — check the log"
```
If bot didn't start:
```bash
tail -20 ~/helm-workspace/system/marvin.log
```
That will show the exact error.

---

## PART 5 — Test in Discord

**Step 7: Run through each test in order**

In Discord, go to the channel named `general` and type:
```
onboarding
```
The bot should immediately ask your name (Stage 1, Question 1). If it says "already done" — the
CONFIG.md reset didn't land. Run Step 3 again and restart (Step 6).

Work through all the preference questions (name, tone, quiet hours, etc.) until the bot says
onboarding is complete.

Then go to the channel named `new-workspace` and type:
```
I want to track my email and summarize it every morning
```
The bot should ask 3-5 clarifying questions and then propose a build plan. If nothing happens:
1. Check the channel is named exactly `new-workspace` (Discord → Edit Channel → name)
2. Check the bot has permission to read and write in that channel

---

## PART 6 — Calendar and Email connectors

**Step 8: Connect Calendar and Email**

In Discord, type in any channel:
```
connect
```
The bot will walk through Calendar and Email setup with buttons. Follow the prompts.

If `connect` does nothing: the onboarding flow (Step 7) must complete first. The connector
step requires `ONBOARDING_COMPLETED: true` to be set (which onboarding writes when it
finishes the last step).

---

## PART 7 — Password manager (isolated vault, any manager)

**Step 9: Create a dedicated HELM vault**

This is manual — you do it in your password manager's UI, not in the terminal.

For **1Password**: Go to 1Password.com → Developer → Service Accounts. Create a service account
named "HELM". Grant it read access to ONE vault you create named "HELM". Copy the token.

For **Bitwarden**: Log in to vault.bitwarden.com → Organizations → create org "HELM" (free)
→ Collections → "HELM" collection. Create an API key for a machine account scoped to that
collection only. Copy the client_id and client_secret.

For **KeePass / KeePassXC**: Create a new database file named `HELM.kdbx`. Store only
the credentials HELM should access. The unlock file or master password for THIS database
is what you give HELM — never your main database.

For **any other manager**: Create a separate vault/folder/collection named "HELM" with
only the credentials you want HELM to see. Get the most restricted access token your
manager offers. If it can't scope below the full account: do not use it for HELM.

**Step 10: Store the token**

Once you have the scoped token, run:
```bash
echo "" >> ~/helm/marvin-bot/.env
echo "# Password manager — HELM vault only (read-only)" >> ~/helm/marvin-bot/.env
echo "PWMGR_TOKEN=PASTE_YOUR_TOKEN_HERE" >> ~/helm/marvin-bot/.env
echo "PWMGR_TYPE=1password" >> ~/helm/marvin-bot/.env  # or: bitwarden / keepass / other
```
Replace `PASTE_YOUR_TOKEN_HERE` with the actual token.
Replace `1password` with your manager name.

Verify it's there:
```bash
grep "PWMGR_TOKEN" ~/helm/marvin-bot/.env | cut -c1-30
```
Expected: shows the first 30 chars of the line (token is masked). Do NOT print the full token.

Confirm `.env` is git-ignored (it should be):
```bash
grep ".env" ~/helm/marvin-bot/.gitignore || echo "WARNING: .env not in .gitignore"
```

---

## PART 8 — VPS (optional — only if you want 24/7 uptime)

Skip this if HELM running on your Mac is fine.

**Step 11: Add VPS details**

If you have a VPS you want HELM to be able to use (for hosting, backups, or running
when your Mac is off), in Discord type:
```
@HELM add vps YOUR_VPS_IP_ADDRESS YOUR_DOMAIN_IF_YOU_HAVE_ONE
```
Example: `@HELM add vps 192.0.2.10 mysite.com`
If no domain yet: `@HELM add vps 192.0.2.10`

HELM stores this and can use the VPS for:
- Hosting websites you build
- Running tasks when your Mac is off (if you deploy HELM there too)
- Recovery fallback if your main machine is unreachable

You do NOT need to move HELM to the VPS — your Mac stays the primary.

---

## DONE — verify the full state

Run this final check:
```bash
echo "=== Onboarding state ==="
grep -E "ONBOARDING_COMPLETED|ONBOARDING_STEP|AGENT_NAME" ~/helm-workspace/CONFIG.md

echo "=== Bot running? ==="
pgrep -fl "node.*bot.js" || echo "NOT RUNNING"

echo "=== .env has Discord token? ==="
grep "DISCORD_TOKEN=" ~/helm/marvin-bot/.env | cut -c1-25

echo "=== Password manager configured? ==="
grep "PWMGR_TOKEN" ~/helm/marvin-bot/.env | cut -c1-30 || echo "not configured yet"
```

After verifying: go to Discord and type `onboarding` in `#general` to confirm the full
preference flow starts from scratch.
