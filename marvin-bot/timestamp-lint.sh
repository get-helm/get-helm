#!/usr/bin/env bash
# timestamp-lint.sh — detect fabricated/future timestamps in key HELM files
# Root cause: 2026-06-10 — agent hand-typed updated_at: 2026-06-10T16:45Z when real time was 03:22Z (13h future)
# Maps to B-01 (truthfulness — claim-verify)
# Usage: bash timestamp-lint.sh [--quiet]    quiet = no stdout, just friction-log writes

set -euo pipefail

FRICTION_LOG="/Users/{{USER_HOME}}/helm-workspace/system/friction-log.md"
TARGET_FILES=(
  "/Users/{{USER_HOME}}/helm-workspace/system/decisions-log.md"
  "/Users/{{USER_HOME}}/helm-workspace/system/engineer-queue.md"
  "/Users/{{USER_HOME}}/helm-workspace/system/pm-pending-decisions.json"
  "/Users/{{USER_HOME}}/helm-workspace/workspaces/options-helper/workstreams.json"
)

QUIET="${1:-}"
NOW_SEC=$(date +%s)
FUTURE_GRACE=300     # 5 minutes ahead = allowed clock skew
MTIME_MAX=86400      # 24h — timestamp >24h different from file mtime is suspicious
VIOLATIONS=0

log_violation() {
  local file="$1" ts="$2" reason="$3"
  local entry="[$(date -u +%Y-%m-%dT%H:%M:%S.000Z)] TIMESTAMP-FABRICATED file=${file##*/} ts=${ts} reason=${reason}"
  echo "$entry" >> "$FRICTION_LOG"
  VIOLATIONS=$((VIOLATIONS + 1))
  if [[ "$QUIET" != "--quiet" ]]; then
    echo "VIOLATION: $entry"
  fi
}

scan_iso_timestamps() {
  local file="$1"
  [[ -f "$file" ]] || return 0

  # File modification time
  local file_mtime
  file_mtime=$(stat -f "%m" "$file" 2>/dev/null || stat -c "%Y" "$file" 2>/dev/null || echo "0")

  # Extract ISO 8601 timestamps (YYYY-MM-DDThh:mm or YYYY-MM-DDThh:mmZ or full with seconds)
  local ts_pattern='[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}'
  local timestamps
  timestamps=$(grep -oE "$ts_pattern(:[0-9]{2})?(\.[0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})?" "$file" 2>/dev/null || true)

  while IFS= read -r ts; do
    [[ -z "$ts" ]] && continue

    # Normalize to epoch — always parse as UTC (all HELM timestamps are UTC/Z)
    local ts_norm="${ts%%.*}"
    ts_norm="${ts_norm%Z}"
    ts_norm="${ts_norm%+00:00}"
    # macOS date -j doesn't parse T; use TZ=UTC to ensure UTC interpretation
    local ts_epoch
    ts_epoch=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "${ts_norm}:00" "+%s" 2>/dev/null \
              || TZ=UTC date -d "${ts_norm/T/ }" +%s 2>/dev/null \
              || echo "0")

    [[ "$ts_epoch" == "0" ]] && continue

    # Check 1: future timestamp (>5 min ahead of now)
    local delta_future=$(( ts_epoch - NOW_SEC ))
    if (( delta_future > FUTURE_GRACE )); then
      local mins_ahead=$(( delta_future / 60 ))
      log_violation "$file" "$ts" "future_timestamp_${mins_ahead}m_ahead"
    fi

    # Check 2: mtime divergence (timestamp >24h different from file mtime)
    if (( file_mtime > 0 )); then
      local delta_mtime=$(( ts_epoch - file_mtime ))
      if (( delta_mtime < 0 )); then delta_mtime=$(( -delta_mtime )); fi
      if (( delta_mtime > MTIME_MAX )); then
        local hours_diff=$(( delta_mtime / 3600 ))
        # Only flag when the timestamp is ahead of mtime (past timestamps are expected in logs)
        if (( ts_epoch > file_mtime + MTIME_MAX )); then
          log_violation "$file" "$ts" "timestamp_${hours_diff}h_ahead_of_file_mtime"
        fi
      fi
    fi
  done <<< "$timestamps"
}

for file in "${TARGET_FILES[@]}"; do
  scan_iso_timestamps "$file"
done

if [[ "$QUIET" != "--quiet" ]]; then
  if (( VIOLATIONS == 0 )); then
    echo "timestamp-lint: PASS — no fabricated timestamps found in ${#TARGET_FILES[@]} files"
  else
    echo "timestamp-lint: $VIOLATIONS violation(s) logged to friction-log"
  fi
fi

exit 0
