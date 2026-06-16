#!/usr/bin/env bash
# second-brain-discord-ingest.sh — Shell entry point for Discord second brain ingest.
# Delegates to the Python implementation. Called by cron and onboarding.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/second-brain-discord-ingest.py" "$@"
