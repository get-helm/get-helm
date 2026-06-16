#!/usr/bin/env bash
# set-moratorium.sh — set restart moratorium flag at 9am PT
# Called by com.pap.moratorium.set.plist

LOG=~/marvin-bot/marvin.log
FLAG=~/helm-workspace/restart-moratorium.flag

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [moratorium] $*" | tee -a "$LOG"
}

touch "$FLAG"
log "moratorium set (peak hours — auto-set 9am PT)"
