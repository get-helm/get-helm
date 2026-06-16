# Second Brain — New-User Onboarding Intake Checklist

Purpose: the exact information to collect from a new HELM user so their second brain
ingests Discord (required) and email (optional) reliably from day one.
Hand this to the onboarding agent. Collect everything in section 1 before any setup.

---

## 1. Information to collect from the user

### Discord ingest — REQUIRED (always set up)
1. **Bot token** — they create a bot at the Discord Developer Portal:
   New Application → Bot → Reset Token → copy. Must enable **Message Content Intent**.
2. **Server (guild) ID** — their HELM Discord server. Right-click server → Copy Server ID
   (Developer Mode must be on: User Settings → Advanced → Developer Mode).
3. **Channels to ingest** — either "all channels" or a specific list of channel IDs + names.
   Default: all channels the bot can read.
4. **Alert channel** — which channel should receive ingest-failure alerts.
   Must be a durable channel the user reads (their equivalent of helm-improvements),
   NOT an ephemeral thread.

### Email ingest — OPTIONAL (only if the user wants email/SMS in their second brain)
1. **Do they want email ingested at all?** If no → skip this whole section.
2. **Gmail address.**
3. **App password** — Google Account → Security → enable 2-Step Verification →
   App Passwords → generate one for "Mail". This is NOT their main password.
4. **SMS?** If they forward texts to that Gmail (e.g. Google Voice), SMS is captured
   automatically by the email pass — confirm whether they do this.

### QMD search engine — REQUIRED (shared by all sources)
1. **Platform + disk** — confirm macOS 14+ or Linux, and ~2–5 GB free for the index.
   Note: QMD uses local GGUF models for reranking — no Anthropic API key required.

---

## 2. Decisions to confirm with the user
1. **Ingest frequency** — default: hourly. Confirm acceptable.
2. **Thread/email history depth** — default: 90 days of Discord thread history,
   full email backfill window on first run. Confirm.
3. **Failure-alert routing** — confirm the durable alert channel from section 1.4.

---

## 3. What the setup must produce (so onboarding can verify success)
After setup, all of these must be true — the onboarding agent confirms each:
1. A scheduled hourly ingest job exists and runs (Discord + optional email + QMD update).
2. A freshness watchdog runs every ~2h and alerts the durable channel if **any** source
   has no successful run in 25h. (Coverage must include every source the user enabled —
   not just Discord and email.)
3. A health file records each source's last successful run.
4. A test query returns results (not an error) within minutes of first ingest.
5. Failure alerts land in the durable channel, never an ephemeral thread.

---

## 4. Security requirements (non-negotiable)
- Gmail app password, Discord bot token, and any OAuth token stored with `600` file
  permissions, never shared, never committed.
- Discord bot scoped read-only on target channels.
- The index stores parsed message text only — no credentials or API keys.

---

## 5. Known pitfalls to warn the user about
1. **"0 new emails" is not success.** A broken email fetch can report zero results and
   look healthy. The watchdog must key off *last successful fetch*, not exit code alone.
2. **Silent source failures.** Every enabled source (Discord, email, SMS, any meeting/
   transcript source) must be in the watchdog loop. A source that ingests but isn't
   monitored will go dark unnoticed — this is the exact failure that caused a multi-day
   email gap in the reference instance.
3. **Search-engine crash noise.** The QMD binary may print "Abort trap: 6" on queries;
   the query wrapper handles it and returns valid results. Always query through the
   wrapper, never the raw binary.
