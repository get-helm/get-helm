#!/bin/bash
# helm-drive-drift-check.sh — Nightly Google Drive HELM folder drift check
# Logs DRIVE-DRIFT entries to helm-audit.log + friction-log for any loose files in HELM root.
# Move capability requires GOOGLE_DRIVE_REFRESH_TOKEN in env; otherwise logs-only mode.
# Called from engineer-nightly.sh after primary backup step.

set -euo pipefail

HELM_FOLDER_ID="18K6lKS7Tpp97EZzUU3O7qyS_pRPvw8Rs"
HELM_AUDIT_LOG="$HOME/helm-workspace/system/helm-audit.log"
FRICTION_LOG="$HOME/helm-workspace/system/friction-log.md"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

CANONICAL_FOLDERS=("Backups" "Dashboards" "Reports" "Specs" "Workspaces" "Archive")
CANONICAL_IDS=(
  "1ZqiVxvP-pFm43Pq--VPKOvefvB5U3yTL"  # Backups
  "1savny98IyoPmazvKQIvrfXRMsleehyvD"  # Dashboards
  "1tJH2Ww7IOYDMBnRzN5PbC3YQlcs2f3TX"  # Reports
  "1c9Ib7biXIec0wBveWlRTwvXUvQxZSTmQ"  # Specs
  "1NvFwkhSoKgO6ecR20wpIgmuBav9AnqRd"  # Workspaces
  "1XJmHIyB0v_Lnt1Hmrw0pFB6mdbDwgblU"  # Archive
)

# Get access token via refresh token (requires GOOGLE_DRIVE_REFRESH_TOKEN + GOOGLE_CLIENT_ID + GOOGLE_CLIENT_SECRET)
get_access_token() {
  if [[ -z "${GOOGLE_DRIVE_REFRESH_TOKEN:-}" ]]; then
    echo ""
    return 1
  fi
  curl -s -X POST "https://oauth2.googleapis.com/token" \
    -d "client_id=${GOOGLE_CLIENT_ID}&client_secret=${GOOGLE_CLIENT_SECRET}&refresh_token=${GOOGLE_DRIVE_REFRESH_TOKEN}&grant_type=refresh_token" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('access_token',''))"
}

# List files in HELM root
list_helm_root() {
  local token="$1"
  curl -s \
    -H "Authorization: Bearer $token" \
    "https://www.googleapis.com/drive/v3/files?q=parents+in+'${HELM_FOLDER_ID}'+and+trashed=false&fields=files(id,name,mimeType)&pageSize=100"
}

# Get canonical folder IDs as a space-separated list for matching
canonical_id_list="${CANONICAL_IDS[*]}"

# Attempt to get Drive access
ACCESS_TOKEN=""
if ACCESS_TOKEN=$(get_access_token 2>/dev/null) && [[ -n "$ACCESS_TOKEN" ]]; then
  echo "[helm-drive-drift-check] $TIMESTAMP — Drive credentials available, scanning HELM root" >> "$HELM_AUDIT_LOG"

  LISTING=$(list_helm_root "$ACCESS_TOKEN")
  DRIFT_COUNT=0

  while IFS= read -r line; do
    file_id=$(echo "$line" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))" 2>/dev/null || true)
    file_name=$(echo "$line" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('name',''))" 2>/dev/null || true)
    mime_type=$(echo "$line" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('mimeType',''))" 2>/dev/null || true)

    # Skip canonical folders
    if echo "$canonical_id_list" | grep -q "$file_id"; then
      continue
    fi

    # Any other file/folder in root = drift
    DRIFT_COUNT=$((DRIFT_COUNT + 1))
    echo "[DRIVE-DRIFT] $TIMESTAMP — Loose item in HELM root: \"$file_name\" (id:$file_id, type:$mime_type)" >> "$HELM_AUDIT_LOG"
    echo "- $TIMESTAMP DRIVE-DRIFT: loose item in HELM root: \"$file_name\" (id:$file_id)" >> "$FRICTION_LOG"

  done < <(echo "$LISTING" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for f in data.get('files', []):
    print(json.dumps(f))
")

  if [[ $DRIFT_COUNT -eq 0 ]]; then
    echo "[helm-drive-drift-check] $TIMESTAMP — CLEAN: no loose files in HELM root" >> "$HELM_AUDIT_LOG"
  else
    echo "[helm-drive-drift-check] $TIMESTAMP — DRIFT: $DRIFT_COUNT loose items found, logged to friction-log" >> "$HELM_AUDIT_LOG"
  fi

else
  # No credentials — log audit note only
  echo "[helm-drive-drift-check] $TIMESTAMP — SKIP: no Drive credentials configured (GOOGLE_DRIVE_REFRESH_TOKEN not set)" >> "$HELM_AUDIT_LOG"
fi
