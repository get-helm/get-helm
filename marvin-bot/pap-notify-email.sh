#!/bin/bash
# pap-notify-email.sh — send fallback email when Discord is down
# Usage: pap-notify-email.sh "subject" "body"
# PL-05
#
# SMTP credentials: stored in PAP Vault as "Dreamhost" (username field = online@{{USER_DOMAIN}}).
# IMPORTANT: The password field must be the EMAIL MAILBOX password, NOT the panel login password.
# The current "Dreamhost" vault entry contains the panel password — SMTP auth will fail until
# the mailbox password is set:
#   1. Go to panel.dreamhost.com → Manage Email → online@{{USER_DOMAIN}} → Edit → set a password
#   2. Update PAP Vault "Dreamhost" entry: op item edit "Dreamhost" --vault "PAP Vault" password=NEW_MAILBOX_PASS
#   3. Test: bash ~/marvin-bot/pap-notify-email.sh "Test" "Test body"

set -e

SUBJECT="${1:-PAP Fallback Notification}"
BODY="${2:-PAP system notification — Discord may be offline.}"
TO="online@{{USER_DOMAIN}}"
FROM="online@{{USER_DOMAIN}}"
SMTP_HOST="smtp.dreamhost.com"
SMTP_PORT="587"
LOG="$HOME/helm-workspace/pap-email-fallback.log"

# Read SMTP credentials from vault ("Dreamhost" entry — username=online@{{USER_DOMAIN}})
SMTP_USER=$(op item get "Dreamhost" --vault "PAP Vault" --fields username --reveal 2>/dev/null)
SMTP_PASS=$(op item get "Dreamhost" --vault "PAP Vault" --fields password --reveal 2>/dev/null)

if [[ -z "$SMTP_USER" || -z "$SMTP_PASS" ]]; then
  TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  echo "[$TS] SMTP not configured — 'Dreamhost' vault entry missing or unreadable. Subject: $SUBJECT" >> "$LOG"
  echo "pap-notify-email.sh: vault entry 'Dreamhost' not found or vault locked — email not sent" >&2
  echo "ACTION NEEDED: Update PAP Vault 'Dreamhost' password field with the online@{{USER_DOMAIN}} mailbox password (not panel password)" >&2
  exit 1
fi

# Write email to temp file (required by curl --upload-file)
TMPMAIL=$(mktemp /tmp/pap-email-XXXXXX.txt)
cat > "$TMPMAIL" << EOF
From: PAP Marvin <${FROM}>
To: {{USER_JERRY}} <${TO}>
Subject: ${SUBJECT}
MIME-Version: 1.0
Content-Type: text/plain; charset=utf-8

${BODY}

---
Sent at: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
Mac Mini PID 1 uptime: $(uptime | awk '{print $3,$4}' | tr -d ',')
EOF

# Send via Dreamhost SMTP (STARTTLS on port 587)
RESULT=$(curl -s \
  --url "smtp://${SMTP_HOST}:${SMTP_PORT}" \
  --ssl-reqd \
  --mail-from "$FROM" \
  --mail-rcpt "$TO" \
  --user "${SMTP_USER}:${SMTP_PASS}" \
  --upload-file "$TMPMAIL" 2>&1)
EXIT=$?

rm -f "$TMPMAIL"

TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
if [[ $EXIT -eq 0 ]]; then
  echo "[$TS] Email sent — Subject: $SUBJECT" >> "$LOG"
  echo "Email sent successfully."
else
  echo "[$TS] Email FAILED (exit $EXIT) — Subject: $SUBJECT — Error: $RESULT" >> "$LOG"
  echo "pap-notify-email.sh: SMTP failed (exit $EXIT): $RESULT" >&2
  exit 1
fi
