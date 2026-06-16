#!/usr/bin/env bash
# qmd-install.sh — Install QMD search engine + download models (idempotent)
# Part of HELM onboarding (Step E2). Run before second-brain ingest crons fire.
#
# What this does:
#   1. Installs @tobilu/qmd globally via bun (or npm fallback)
#   2. Downloads the 3 local models (~2.1GB) by running a minimal embed warm-up
#   3. Verifies qmd --version responds
#
# Models live in ~/.cache/qmd/models/ (auto-downloaded by node-llama-cpp on first embed).
# No Anthropic API key needed — all inference is local via GGUF models.
# QMD data (.qmd index) is intentionally NOT included — new users start with empty index.

set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$HOME/.bun/bin:$PATH"

QMD_BIN="$HOME/.bun/bin/qmd"
LOG_FILE="${1:-/tmp/qmd-install.log}"
STAMP_FILE="$HOME/.cache/qmd/.installed"

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [qmd-install] $*" | tee -a "$LOG_FILE"; }

# ── Idempotent check ──────────────────────────────────────────────────────────
if [[ -f "$STAMP_FILE" ]] && [[ -x "$QMD_BIN" ]]; then
  VERSION=$("$QMD_BIN" --version 2>/dev/null || echo "unknown")
  log "QMD already installed ($VERSION) — skipping. Remove $STAMP_FILE to force reinstall."
  exit 0
fi

log "Starting QMD install..."

# ── Step 1: Install bun if missing ───────────────────────────────────────────
if ! command -v bun &>/dev/null; then
  log "bun not found — installing bun..."
  if command -v curl &>/dev/null; then
    curl -fsSL https://bun.sh/install | bash >> "$LOG_FILE" 2>&1
    export PATH="$HOME/.bun/bin:$PATH"
  else
    log "ERROR: curl not available. Install bun manually: https://bun.sh"
    exit 1
  fi
fi

# ── Step 2: Install or update QMD ────────────────────────────────────────────
if [[ -x "$QMD_BIN" ]]; then
  log "QMD binary found — updating to latest..."
  bun install -g @tobilu/qmd >> "$LOG_FILE" 2>&1 || true
else
  log "Installing @tobilu/qmd via bun..."
  if ! bun install -g @tobilu/qmd >> "$LOG_FILE" 2>&1; then
    log "bun install failed — trying npm fallback..."
    npm install -g @tobilu/qmd >> "$LOG_FILE" 2>&1
    # npm puts qmd in a different PATH — find it
    QMD_BIN=$(which qmd 2>/dev/null || echo "$HOME/.bun/bin/qmd")
  fi
fi

if [[ ! -x "$QMD_BIN" ]]; then
  log "ERROR: qmd binary not found at $QMD_BIN after install"
  exit 1
fi

VERSION=$("$QMD_BIN" --version 2>/dev/null || echo "unknown")
log "QMD installed: $VERSION"

# ── Step 3: Download models via warm-up embed ─────────────────────────────────
# Models download automatically on first embed. We run a warm-up on a temp
# collection so models are cached before any real ingest runs.
WARMUP_DIR=$(mktemp -d)
echo "# QMD install warm-up" > "$WARMUP_DIR/warmup.md"
echo "This file exists to trigger model downloads during HELM installation." >> "$WARMUP_DIR/warmup.md"

WARMUP_INDEX=$(mktemp -d)
export QMD_INDEX_DIR="$WARMUP_INDEX"

log "Downloading models via warm-up embed (~2.1GB, may take 5-10 min on first install)..."
log "(Progress: embeddinggemma-300M → qmd-query-expansion-1.7B → qwen3-reranker-0.6b)"

"$QMD_BIN" collection add "$WARMUP_DIR" --name warmup >> "$LOG_FILE" 2>&1 || true
"$QMD_BIN" update >> "$LOG_FILE" 2>&1 || true

# Run embed — this is what triggers the model downloads
if "$QMD_BIN" embed >> "$LOG_FILE" 2>&1; then
  log "Model warm-up complete"
else
  log "WARNING: embed warm-up returned non-zero (models may still have downloaded)"
fi

# Clean up warm-up collection and temp dirs
"$QMD_BIN" collection remove warmup >> "$LOG_FILE" 2>&1 || true
rm -rf "$WARMUP_DIR" "$WARMUP_INDEX"
unset QMD_INDEX_DIR

# ── Step 4: Verify ────────────────────────────────────────────────────────────
MODEL_DIR="$HOME/.cache/qmd/models"
if [[ -d "$MODEL_DIR" ]]; then
  MODEL_COUNT=$(ls "$MODEL_DIR"/*.gguf 2>/dev/null | wc -l | tr -d ' ')
  MODEL_SIZE=$(du -sh "$MODEL_DIR" 2>/dev/null | cut -f1 || echo "unknown")
  log "Models ready: $MODEL_COUNT GGUF files, $MODEL_SIZE total"
else
  log "WARNING: Model dir $MODEL_DIR not found — models may not have downloaded"
fi

# ── Step 5: Mark installed ────────────────────────────────────────────────────
mkdir -p "$(dirname "$STAMP_FILE")"
echo "$VERSION installed $(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$STAMP_FILE"

log "QMD install complete. Run 'qmd --version' to verify."
log "Next: add collections with 'qmd collection add <path> --name <name>'"
