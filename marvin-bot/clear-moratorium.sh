#!/usr/bin/env bash
# clear-moratorium.sh — clear restart moratorium flag at 10pm PT
# Called by com.pap.moratorium.clear.plist

LOG=~/marvin-bot/marvin.log
FLAG=~/helm-workspace/restart-moratorium.flag

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [moratorium] $*" | tee -a "$LOG"
}

if [[ -f "$FLAG" ]]; then
  rm -f "$FLAG"
  log "moratorium cleared (off-peak hours — auto-cleared 10pm PT)"
else
  log "moratorium clear-check: flag already absent, no action"
fi
