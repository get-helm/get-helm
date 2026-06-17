# Friend Connector Walkthrough — paste-ready Claude Code prompt
# Created 2026-06-16 for {{USER_JERRY}}'s beta friend. Manager-agnostic.

---

You are helping me finish connecting HELM to my data sources and credentials.
HELM is already running as a Discord bot on this machine. Walk me through the
steps below ONE AT A TIME. Ask me a question, wait for my answer, then continue.
Never assume which tools I use — ask first. Do not skip a step without telling me.

## Step 1 — Calendar & Email (Claude-native connectors)
These connect through Claude itself, not through code.
1. Tell me to open the Claude desktop app (or claude.ai) → Settings → Connectors.
2. Have me click Connect on my Calendar provider (e.g. Google Calendar), then my Email provider (e.g. Gmail). Walk me through the OAuth screen.
3. Once I say I've connected one, tell me to go to my HELM Discord server and type:  connect
   HELM will walk the rest and run a test briefing. If HELM says the tools aren't visible yet, have me finish the Connect in Claude Settings, then type  connect  again.

## Step 2 — Password manager (any manager — isolated vault)
GOAL: give HELM access to ONLY a dedicated vault, never my main vault.
1. First ask me which password manager I use (1Password, Bitwarden, Dashlane, KeePass, other).
2. Walk me through creating a NEW, separate vault/collection/folder named exactly: HELM
3. Have me move into it ONLY the credentials I want HELM to use (e.g. a read-only financial login). Nothing else. My master vault stays untouched.
4. Generate the most scoped access credential my manager supports, limited to the HELM vault only:
   - 1Password: create a Service Account (1Password.com → Developer → Service Accounts) granted read access to the HELM vault ONLY. Copy the service-account token.
   - Bitwarden: use Secrets Manager → create a machine account scoped to a HELM project, OR create an Organization Collection "HELM" and an API key scoped to it. Copy the credential.
   - Dashlane / KeePass / other: create the separate vault/database, then export the access method that can be limited to it (team/service token, or a dedicated unlock file). If the manager can't scope below the whole account, STOP and tell me — we do NOT hand HELM full-account access.
5. Store the scoped token where HELM reads credentials: append it to  ~/helm/marvin-bot/.env  as a clearly-named variable (e.g. PWMGR_TOKEN=...). Show me the line before writing it, and confirm .env is git-ignored.
6. Test: confirm the token can read ONE item from the HELM vault and CANNOT read anything outside it. Tell me the result. If it can read outside the HELM vault, the scoping failed — stop and we fix it.

SECURITY RULES (do not violate): read-only credentials only; never store my master password; never give HELM access to a vault that contains anything beyond what I deliberately put in the HELM vault.

## Step 3 — VPS (optional — only if I want 24/7 uptime)
1. Ask if I want HELM hosted on a VPS for always-on uptime + a recovery webpage. If I say no, skip this step.
2. If yes, collect: VPS IP address, the SSH username, and (optional) my domain.
3. Tell me to go to my HELM Discord server and type:  @HELM add vps [IP] [domain]
   HELM stores it and uses it as an SSH recovery fallback. Confirm HELM acknowledges it.

## Step 4 — Confirm everything
List back to me what is now connected: Calendar (yes/no), Email (yes/no), Password manager isolated vault (yes/no + which manager), VPS (yes/no). Flag anything still missing and offer to retry it.
