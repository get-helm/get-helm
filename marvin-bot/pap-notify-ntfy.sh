#!/bin/bash
# pap-notify-ntfy.sh — credential-free push notification fallback via ntfy.sh
# No account needed. {{USER_JERRY}} installs ntfy app (ntfy.sh) and subscribes to the topic below.
# Usage: pap-notify-ntfy.sh "Title" "Body"

TOPIC_FILE="$HOME/marvin-bot/.ntfy-topic"
LOG="$HOME/marvin-bot/pap-notify-ntfy.log"

TITLE="${1:-PAP Alert}"
BODY="${2:-PAP needs your attention}"

# Generate topic on first run and save it
if [ ! -f "$TOPIC_FILE" ]; then
  # Random enough for personal use — not a security-sensitive secret
  TOPIC="pap-marvin-$(openssl rand -hex 6)"
  echo "$TOPIC" > "$TOPIC_FILE"
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Generated new ntfy topic: $TOPIC" >> "$LOG"
fi

TOPIC=$(cat "$TOPIC_FILE")

HTTP_CODE=$(curl -s -o /tmp/ntfy-response.txt -w "%{http_code}" \
  -H "Title: ${TITLE}" \
  -H "Priority: high" \
  -H "Tags: bell,pap" \
  -d "${BODY}" \
  "https://ntfy.sh/${TOPIC}")

if [ "$HTTP_CODE" = "200" ]; then
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] ntfy sent OK — topic=${TOPIC} title='${TITLE}'" >> "$LOG"
else
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] ntfy FAILED HTTP ${HTTP_CODE} — $(cat /tmp/ntfy-response.txt)" >> "$LOG"
  exit 1
fi
