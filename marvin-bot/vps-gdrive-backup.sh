#!/usr/bin/env bash
# vps-gdrive-backup.sh — Upload latest VPS backup to Google Drive HELM/Backups folder.
# Called by launchd at 03:10 PT (30 min after vps-backup-pull.sh at 02:30 PT).
# Uses Claude CLI with Google Drive MCP integration — no separate OAuth or rclone needed.
# DESIGN NOTE: Claude reads the file itself (short prompt) to avoid large b64 in prompt.
# Retains last 7 backups in Drive; deletes older ones after upload.

set -euo pipefail

BACKUP_DIR="$HOME/backups/vps"
# "Backups" subfolder inside HELM Google Drive folder
HELM_BACKUPS_FOLDER_ID="1ZqiVxvP-pFm43Pq--VPKOvefvB5U3yTL"
AUDIT_LOG="$HOME/helm-workspace/system/helm-audit.log"
CLAUDE_BIN="$HOME/.local/bin/claude"
RETAIN_DAYS=7

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [vps-gdrive-backup] $*" >> "$AUDIT_LOG"; }

# Find latest backup file
LATEST=$(ls -t "$BACKUP_DIR"/agentos_*.sql.gz 2>/dev/null | head -1 || true)
if [[ -z "$LATEST" ]]; then
    log "SKIP: no backup files found in $BACKUP_DIR"
    exit 0
fi

FILENAME=$(basename "$LATEST")
SIZE=$(du -sh "$LATEST" | cut -f1)
log "Starting upload: $FILENAME ($SIZE) → Google Drive HELM/Backups"

# Call Claude CLI with Google Drive MCP.
# IMPORTANT: do NOT use --allowedTools — restricting tools breaks cloud MCP integration.
# Claude reads the backup file itself (keeping the prompt short and fast).
RESULT=$("$CLAUDE_BIN" --dangerously-skip-permissions \
    -p "Task: upload a VPS backup to Google Drive. Steps:
1. Read the file at $LATEST as base64 content using the Read tool.
2. Call mcp__claude_ai_Google_Drive__create_file with title=\"$FILENAME\", parentId=\"$HELM_BACKUPS_FOLDER_ID\", contentMimeType=\"application/gzip\", disableConversionToGoogleType=true, and the base64Content from step 1.
3. Search Google Drive folder $HELM_BACKUPS_FOLDER_ID for files matching 'agentos_' to find any older than $RETAIN_DAYS days and note their IDs for pruning.
Report in exactly this format:
UPLOAD_STATUS: SUCCESS or FAILED
FILE_ID: <google drive file id>
PRUNED: <comma-separated IDs or NONE>" 2>&1 || true)

# Parse result
if echo "$RESULT" | grep -q "UPLOAD_STATUS: SUCCESS"; then
    FILE_ID=$(echo "$RESULT" | grep "FILE_ID:" | sed 's/FILE_ID: //' | tr -d '[:space:]')
    PRUNED=$(echo "$RESULT" | grep "PRUNED:" | sed 's/PRUNED: //' | tr -d '[:space:]')
    log "SUCCESS: $FILENAME uploaded. Drive ID: ${FILE_ID}. Pruned: ${PRUNED}"
    exit 0
else
    FAILURE_SNIPPET=$(echo "$RESULT" | head -5 | tr '\n' ' ')
    log "FAILED: $FILENAME upload failed. Claude output: ${FAILURE_SNIPPET}"
    exit 1
fi
