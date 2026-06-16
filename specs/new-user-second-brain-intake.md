# 2nd Brain Setup — New User Intake Checklist

When a new user joins HELM, use this checklist to collect the information needed for their second brain (QMD) to work. Pass the completed checklist to the engineer or PM setting up their instance.

---

## ✅ **REQUIRED** — Discord Ingestion

Your second brain needs to index your Discord conversation history so that agents can search for prior decisions, designs, and context.

**Collect from user:**
- [ ] Discord server ID (Guild ID) — found in Server Settings > Widget
- [ ] Bot token for the HELM bot — request from the HELM PM if shared bot, or create a new bot token if dedicated instance
  - Bot must have these **read-only** scopes: `read:messages`, `read:message_history`, `read:channels`
- [ ] List of channel IDs to index
  - At minimum: `#general`, `#helm-improvements` (or equivalent), any workspace-specific channels
  - Format: provide channel names + IDs (e.g., "helm-improvements: {{USER_CHANNEL_HELM_IMPROVEMENTS}}")

**Result:** Discord ingestion will run hourly via cron, capturing all messages + threads.

---

## 🟡 **OPTIONAL** — Email Ingestion

Email ingestion is useful if you want to include important decision emails, meeting notes, or external communication in your second brain. It's optional but recommended.

**If the user wants email ingestion:**
- [ ] Gmail account (required — IMAP only, not standard OAuth2 at this time)
- [ ] App-specific password created in Gmail security settings
  - Do NOT use main Gmail password
  - Settings > Security > App Passwords > select "Mail" + "macOS" or "Linux" → Gmail generates a 16-character password
- [ ] Starting date for email history to index (e.g., "last 3 months" or "all since account creation")
  - Default: last 30 days of emails

**Result:** Email ingestion will run hourly, pulling new emails + indexing them into QMD.

---

## 🟡 **OPTIONAL** — SMS (via Gmail)

If the user receives SMS codes or messages via a Gmail forwarding service (e.g., Google Voice), they are automatically indexed in the email ingest. No additional setup needed.

---

## 📋 **OPTIONAL** — Fireflies (Meeting Transcripts)

If the user uses Fireflies.ai to transcribe meetings and wants those transcripts indexed:
- [ ] Fireflies API key
- [ ] Fireflies workspace ID (found in workspace settings)

**Result:** Meeting transcripts are pulled hourly and indexed into QMD.

---

## Configuration File (for setup team)

Once credentials are collected, the setup team will create these files on the user's machine:

```
~/.second-brain/
  ├── discord-config.json    (user provides: bot_token, guild_id, channel list)
  ├── email-config.json      (user provides: gmail address, app_password, email window)
  └── fireflies-config.json  (if opted in: api_key, workspace_id)
```

---

## Next Steps

1. **User provides answers above** (Discord required, email/SMS/Fireflies optional)
2. **Setup team runs installation:** `bash ~/marvin-bot/setup-second-brain.sh`
   - Installs QMD binary
   - Creates config files from user input
   - Sets up cron jobs
3. **Setup team tests ingest:** `bash ~/marvin-bot/second-brain-email-ingest.sh --test --verbose` + Discord test
4. **Agent queries work:** Agents can now search for context via `qmd-query.sh "[topic]" 3`

---

## Troubleshooting During Intake

**Q: Can I use regular Gmail password instead of app password?**  
A: Not currently. App password is required for security + IMAP compatibility.

**Q: Do I have to set up email?**  
A: No. Discord ingestion alone is sufficient. Email is optional and can be added later.

**Q: What if I don't want to share my Discord bot token?**  
A: Request a dedicated HELM bot token from the PM. The bot is read-only and has no permission to post or modify channels.

**Q: Can I index Slack instead of Discord?**  
A: Not yet. Slack ingestion is on the roadmap. For now, Discord only.

---

**Completion:** After user provides answers, they are ready for installation. The full technical spec is at `~/helm-workspace/specs/second-brain-onboarding.md`.
