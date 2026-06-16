# PII Channel-ID Leak Fix (PUBLISH-PII-CHANNELS-001)

## Problem
The published repo `get-helm/get-helm` (HEAD == origin/main == fbeff63) contains
{{USER_JERRY}}'s real Discord **channel** IDs in 110 committed files. The placeholder
converter (`helm-placeholder-convert.sh` / `placeholder-manifest.json`) replaces
the **server/guild** ID (`{{USER_DISCORD_SERVER_ID}}` → `{{USER_DISCORD_SERVER_ID}}`) but
has NO entries for the individual channel IDs, so every publish leaks them.

These are channel IDs, not access-granting credentials (you cannot read a private
server's channels without being an invited member). Severity = personal-config
leak + functional install-breaker (cloned installs reference {{USER_JERRY}}'s channels
and will misroute / fail to post for new users).

## Known leaked IDs (do NOT print in any user-facing message)
- {{USER_CHANNEL_HELM_IMPROVEMENTS}}  → {{USER_CHANNEL_HELM_IMPROVEMENTS}}  (main / helm-improvements)
- {{USER_CHANNEL_HELM_AUDIT}}  → {{USER_CHANNEL_HELM_AUDIT}}          (helm-audit / PM home)
- {{USER_CHANNEL_HELM_STATUS}}  → {{USER_CHANNEL_HELM_STATUS}}         (helm-status)
- {{USER_CHANNEL_BETA_USERS}}  → {{USER_CHANNEL_BETA_USERS}}           (beta/additional-users channel)

## Fix (3 parts)
1. **Manifest:** add the 4 channel IDs above to `placeholder-manifest.json` (and
   the inline replacements list in `helm-placeholder-convert.sh` if it is the
   source of truth). Map each to a `{{USER_CHANNEL_*}}` placeholder. Confirm the
   4th ID's purpose against `~/marvin-bot/config/channels.json` before naming it.
2. **Publish gate:** in `helm-publish.sh` (or `pre-deploy-security-check.sh`),
   after conversion, scan the staging dir for ANY 17-19 digit Discord snowflake
   that matches {{USER_JERRY}}'s known IDs (server + 4 channels). If found → FAIL the
   publish (exit 1) and print the offending file list. This prevents recurrence.
3. **Re-publish:** re-run helm-publish to overwrite the public working tree with
   genericized files.

## NOT in engineer scope — {{USER_JERRY}} decides (public-repo history)
Re-publishing overwrites the working tree but git **history** still contains the
IDs. Removing them from history requires one of: (a) `git filter-repo` history
rewrite + force-push, (b) delete & recreate the get-helm repo, or (c) make the
repo private until scrubbed. These are irreversible/public actions — {{USER_JERRY}} must
choose. Do NOT force-push or rewrite history autonomously.

## Verification
- After fix: `git grep -lE "{{USER_CHANNEL_HELM_IMPROVEMENTS}}|{{USER_CHANNEL_HELM_AUDIT}}|{{USER_CHANNEL_HELM_STATUS}}|{{USER_CHANNEL_BETA_USERS}}" HEAD` in staging → 0 files.
- Publish gate returns exit 1 when a known ID is reintroduced (add a test).
