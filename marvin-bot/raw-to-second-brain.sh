#!/usr/bin/env bash
# raw-to-second-brain.sh — Convert raw JSONL message files to QMD-indexable .md files.
# Run nightly after second-brain-discord-ingest.py.
# Reads: ~/helm-workspace/second-brain-raw/YYYY-MM-DD.jsonl
# Writes: ~/helm-workspace/second-brain/YYYY-MM-DD-raw-messages.md (one file per day)

set -euo pipefail

RAW_DIR=~/helm-workspace/second-brain-raw
SB_DIR=~/helm-workspace/second-brain
LOG=~/marvin-bot/marvin.log

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [raw-to-second-brain] $*" | tee -a "$LOG"
}

if [[ ! -d "$RAW_DIR" ]]; then
  log "Raw index dir not found — nothing to convert"
  exit 0
fi

CONVERTED=0
for JSONL_FILE in "$RAW_DIR"/*.jsonl; do
  [[ -f "$JSONL_FILE" ]] || continue
  DATE=$(basename "$JSONL_FILE" .jsonl)
  MD_FILE="$SB_DIR/${DATE}-raw-messages.md"

  # Count entries
  ENTRY_COUNT=$(wc -l < "$JSONL_FILE" | tr -d ' ')
  if [[ "$ENTRY_COUNT" -eq 0 ]]; then
    log "Skip $DATE — empty JSONL"
    continue
  fi

  # Write or overwrite the .md file (idempotent — safe to run multiple times per day)
  python3 - "$JSONL_FILE" "$MD_FILE" "$DATE" << 'PYEOF'
import sys, json

jsonl_path, md_path, date = sys.argv[1], sys.argv[2], sys.argv[3]
lines = []
with open(jsonl_path) as f:
    for raw in f:
        raw = raw.strip()
        if not raw:
            continue
        try:
            entry = json.loads(raw)
            ts = entry.get("ts", "")[:19].replace("T", " ")
            ch = entry.get("channelName", entry.get("channelId", "unknown"))
            content = entry.get("content", "").replace("\n", " ").strip()
            if content and content != "[attachment]":
                lines.append(f"- [{ts}] #{ch}: {content}")
        except Exception:
            pass

if not lines:
    sys.exit(0)

with open(md_path, "w") as out:
    out.write(f"# Raw Discord Messages — {date}\n\n")
    out.write("Source: bot.js raw message index\n\n")
    out.write("\n".join(lines))
    out.write("\n")

print(f"Wrote {len(lines)} entries to {md_path}")
PYEOF
  CONVERTED=$((CONVERTED + 1))
  log "Converted $DATE — $ENTRY_COUNT entries → $(basename $MD_FILE)"
done

if [[ $CONVERTED -gt 0 ]]; then
  log "Running qmd update..."
  cd ~/helm-workspace
  PATH="/opt/homebrew/bin:$PATH" ~/.bun/install/global/node_modules/@tobilu/qmd/bin/qmd update --collection second-brain >> "$LOG" 2>&1 || log "qmd update failed (non-fatal)"
  log "Done — $CONVERTED day(s) converted"
else
  log "No new JSONL files to convert"
fi
