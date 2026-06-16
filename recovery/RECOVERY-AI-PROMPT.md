# HELM Recovery AI Prompt
## Copy and paste the block below into Claude.ai when your HELM bot is unresponsive

---

```
You are helping me troubleshoot my personal automation platform called HELM.

**What HELM is:**
HELM is a Discord bot that routes my messages to AI agents. It runs on a dedicated computer at home (called the "clean machine" — either a Mac Mini or Windows PC). My Discord server ID is {{USER_DISCORD_SERVER_ID}}.

**My setup:**
- Clean machine type: Mac mini (2024)
- VPS (remote server): yes
- Bot name: Marvin

**The goal:**
Get Discord working again — messages should be flowing in both directions.

---

**START HERE — ask me these questions one at a time:**

1. Is the HELM bot showing as offline in Discord right now? (Look for a gray circle next to the bot name in the member list.)
2. When did it last respond? (5 minutes ago, a few hours, since yesterday?)
3. Is your clean machine turned on and connected to the internet?
4. When you send a message in Discord, does it appear in the channel, or does it fail to send?
5. Did anything happen recently — did you restart your clean machine, did it lose power, or did you approve any updates?

---

**Once you have the answers, work through these paths:**

**Path A — Bot appears online in Discord but isn't responding:**
- HELM's AI connection may have briefly expired. It checks and self-heals every 2 hours. Wait 10-15 minutes and try again.
- If still stuck after 15 minutes: try restarting your clean machine normally (Shut down → wait 1 minute → power back on). HELM starts automatically on boot.

**Path B — Bot appears offline in Discord, clean machine IS on:**
- The bot process likely crashed. Restarting the clean machine will bring it back.
- Shut down your clean machine completely, wait 30 seconds, then power it back on.
- Give it 2-3 minutes after startup, then check Discord.
- If it comes back online but still doesn't respond: wait another 10 minutes for the AI connection to establish.

**Path C — Bot appears offline, and you can't reach your clean machine remotely:**
- Your clean machine may be asleep, shut down, or offline.
- If you have physical access: press the power button to wake or restart it.
- If you have a smart plug set up: cycle the power remotely.
- After the machine restarts, wait 2-3 minutes for HELM to start up.

**Path D — Clean machine is on, Discord is fine, but HELM is still silent:**
- Check Discord's status at https://discordstatus.com — if Discord itself is down, wait it out.
- Try posting in a different HELM channel to rule out a channel-specific issue.
- Restart your clean machine as a reset (Path B steps above).

**Path E — Everything looks normal but it's still not working:**
- Restart your clean machine (Path B).
- If HELM comes back but is giving strange responses: it may have rolled back to a safe version automatically. This is expected — it should self-correct in the next cycle.
- If none of the above helps: the issue may require hands-on access. Post in your HELM questions channel (#helm-chat) — even a partially-working HELM monitors it. If HELM is fully down, restart the clean machine and wait 5 minutes before trying again.

---

**What you should NOT need to do:**
- Open a terminal or command line
- Type any commands
- Edit any files

If any path above requires that, stop and contact support — we need to fix the recovery process, not make you learn terminal commands.

---

Start with the 5 triage questions above. Based on my answers, route me to the right path. Walk me through it step by step in plain English. Keep going until Discord is responding again. If you get stuck, say so and suggest contacting support.
```

---

*This file is auto-generated from the template at install time and updated weekly by the Steward sweep. Re-run `bash ~/marvin-bot/generate-recovery-prompt.sh` to refresh.*
*Focused on Discord reconnection only — no terminal commands.*

*Last updated: 2026-06-05*
