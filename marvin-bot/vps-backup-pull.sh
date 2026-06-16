#!/usr/bin/env bash
# vps-backup-pull.sh — Daily pull of VPS pg_dump to Mac mini.
# Runs via launchd nightly at 2:30am PT.
# Keeps 7 daily backups. Results log to helm-workspace/logs/vps-backup.log (PM reads during sweeps).

set -euo pipefail

VPS="root@{{USER_VPS_IP}}"
BACKUP_DIR="$HOME/backups/vps"
# Discord notifications removed 2026-06-15: backup results go to log only (PM reads during sweeps).
# Do NOT re-add Discord posting here — {{USER_JERRY}} directed this 3 times (Jun 8, 9, 10).
DATE=$(date +%Y-%m-%d)
DUMP_FILE="agentos_${DATE}.sql.gz"
LOCAL_PATH="$BACKUP_DIR/$DUMP_FILE"
LOG_FILE="$HOME/helm-workspace/logs/vps-backup.log"
RETAIN_DAYS=7
GITHUB_TOKEN_CMD="op item get 'GitHub PAP Backup Token' --vault 'PAP Vault' --fields password --reveal"
GITHUB_REPO="{{USER_GITHUB}}/platform-config"
GITHUB_BACKUP_PATH="vps-backups/${DUMP_FILE}"

mkdir -p "$BACKUP_DIR"
mkdir -p "$(dirname "$LOG_FILE")"

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >> "$LOG_FILE"; }

log "Starting VPS backup pull"

# Run pg_dump on VPS and stream to local file
if ssh -o ConnectTimeout=10 -o BatchMode=yes "$VPS" \
    "su -c 'pg_dump agentos' postgres | gzip" > "$LOCAL_PATH" 2>>/tmp/vps-backup-err.log; then

    SIZE=$(du -sh "$LOCAL_PATH" | cut -f1)
    log "SUCCESS — $DUMP_FILE ($SIZE)"

    # Prune old backups
    find "$BACKUP_DIR" -name "agentos_*.sql.gz" -mtime +${RETAIN_DAYS} -delete
    COUNT=$(ls "$BACKUP_DIR"/agentos_*.sql.gz 2>/dev/null | wc -l | tr -d ' ')

    # Off-device cloud backup — upload to private GitHub repo as second copy.
    # Guards against Mac mini + VPS failing simultaneously.
    GITHUB_TOKEN=$(eval "$GITHUB_TOKEN_CMD" 2>/dev/null || true)
    CLOUD_STATUS="skipped"
    if [[ -n "$GITHUB_TOKEN" ]]; then
        B64=$(base64 < "$LOCAL_PATH" | tr -d '\n')
        # Get current file SHA if it already exists (required for GitHub API update)
        EXISTING_SHA=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
            "https://api.github.com/repos/${GITHUB_REPO}/contents/${GITHUB_BACKUP_PATH}" \
            2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin).get('sha',''))" 2>/dev/null || echo "")

        PAYLOAD="{\"message\":\"backup: ${DUMP_FILE}\",\"content\":\"${B64}\""
        [[ -n "$EXISTING_SHA" ]] && PAYLOAD="${PAYLOAD},\"sha\":\"${EXISTING_SHA}\""
        PAYLOAD="${PAYLOAD}}"

        HTTP=$(curl -s -o /tmp/gh-backup-response.txt -w "%{http_code}" \
            -X PUT \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Content-Type: application/json" \
            -d "$PAYLOAD" \
            "https://api.github.com/repos/${GITHUB_REPO}/contents/${GITHUB_BACKUP_PATH}" \
            2>/dev/null || echo "000")

        if [[ "$HTTP" == "200" || "$HTTP" == "201" ]]; then
            CLOUD_STATUS="github-ok"
            log "Off-device backup uploaded to ${GITHUB_REPO}/${GITHUB_BACKUP_PATH} (HTTP $HTTP)"
            # Prune GitHub backups older than 7 days
            curl -s -H "Authorization: token $GITHUB_TOKEN" \
                "https://api.github.com/repos/${GITHUB_REPO}/contents/vps-backups" \
                2>/dev/null | python3 -c "
import json,sys,subprocess,datetime
files = json.load(sys.stdin)
if not isinstance(files, list): files = []
cutoff = (datetime.date.today() - datetime.timedelta(days=7)).isoformat()
for f in files:
    name = f.get('name','')
    if name.startswith('agentos_') and name.endswith('.sql.gz'):
        date_part = name[len('agentos_'):-len('.sql.gz')]
        if date_part < cutoff:
            print(f['path'], f['sha'])
" 2>/dev/null | while read -r fpath fsha; do
                curl -s -X DELETE \
                    -H "Authorization: token $GITHUB_TOKEN" \
                    -H "Content-Type: application/json" \
                    -d "{\"message\":\"prune old backup\",\"sha\":\"${fsha}\"}" \
                    "https://api.github.com/repos/${GITHUB_REPO}/contents/${fpath}" > /dev/null 2>&1 || true
            done
        else
            CLOUD_STATUS="github-failed-${HTTP}"
            log "Off-device backup FAILED (HTTP $HTTP): $(cat /tmp/gh-backup-response.txt 2>/dev/null | head -1)"
        fi
    else
        log "GitHub token unavailable — off-device backup skipped"
    fi

    log "Done. $COUNT backups retained. Cloud: ${CLOUD_STATUS}"
else
    ERR=$(cat /tmp/vps-backup-err.log 2>/dev/null | tail -3)
    log "FAILED — $ERR"
    rm -f "$LOCAL_PATH"  # remove partial file

    exit 1
fi
