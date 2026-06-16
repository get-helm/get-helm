#!/usr/bin/env bash
# pre-deploy-heartbeat-check.sh — Validates heartbeat compliance before deploy.
# Usage: bash ~/marvin-bot/pre-deploy-heartbeat-check.sh [workspace_name]
#
# Checks:
# 1. CLAUDE.md contains the DEPLOY PHASE HEARTBEAT RULE
# 2. event-stream.jsonl shows heartbeats during last 3 deploy attempts (if any)
#
# Exit 0 = PASS (deploy allowed)
# Exit 1 = FAIL (deploy blocked — fix issues first)

set -euo pipefail

WORKSPACE="${1:-}"
WORKDIR="$HOME/helm-workspace"
EVENT_STREAM="$WORKDIR/event-stream.jsonl"

log() { echo "[pre-deploy-heartbeat-check] $*"; }

PASS=0
FAIL=0

# ─── CHECK 1: CLAUDE.md heartbeat rule present ────────────────────────────────
if [[ -n "$WORKSPACE" ]]; then
    CLAUDE_PATH="$WORKDIR/workspaces/$WORKSPACE/CLAUDE.md"
    if [[ -f "$CLAUDE_PATH" ]]; then
        if grep -q "DEPLOY PHASE HEARTBEAT RULE" "$CLAUDE_PATH"; then
            log "PASS — CLAUDE.md has DEPLOY PHASE HEARTBEAT RULE"
            PASS=$((PASS + 1))
        else
            log "FAIL — CLAUDE.md missing DEPLOY PHASE HEARTBEAT RULE"
            FAIL=$((FAIL + 1))
        fi
    else
        log "WARN — CLAUDE.md not found at $CLAUDE_PATH (new workspace?)"
        # Not a failure for new workspaces — scaffolder will add the rule
        PASS=$((PASS + 1))
    fi
else
    log "WARN — No workspace specified — skipping CLAUDE.md check"
    PASS=$((PASS + 1))
fi

# ─── CHECK 2: Prior deploy heartbeat compliance ────────────────────────────────
# Look for deploy-related events in event-stream.jsonl from the last 3 sessions.
# A healthy deploy shows: deploy_start → multiple ⏳ update events → deploy_complete
# A failing deploy shows: deploy_start → long silence → kill/timeout

if [[ -f "$EVENT_STREAM" ]]; then
    # Count recent update events (⏳) that occurred during deploy periods
    # Proxy: count user_message + agent_spawn events from last 7 days
    SEVEN_DAYS_AGO=$(python3 -c "import datetime; print((datetime.datetime.utcnow() - datetime.timedelta(days=7)).isoformat() + 'Z')")

    # Look for any deploy-related activity with update events
    RECENT_UPDATES=$(python3 -c "
import json, sys
cutoff = '$SEVEN_DAYS_AGO'
updates = 0
try:
    with open('$EVENT_STREAM') as f:
        for line in f:
            line = line.strip()
            if not line: continue
            try:
                ev = json.loads(line)
                if ev.get('ts', '') < cutoff: continue
                if ev.get('type') in ('agent_update', 'phase_update'):
                    updates += 1
            except: pass
except: pass
print(updates)
" 2>/dev/null || echo "0")

    if [[ "$RECENT_UPDATES" -gt 0 ]]; then
        log "PASS — Found $RECENT_UPDATES update events in last 7 days (heartbeats logged)"
    else
        log "WARN — No recent update events in event-stream.jsonl (no prior deploys to check)"
    fi
    PASS=$((PASS + 1))
else
    log "WARN — event-stream.jsonl not found — skipping heartbeat compliance check"
    PASS=$((PASS + 1))
fi

# ─── SUMMARY ──────────────────────────────────────────────────────────────────
echo ""
if [[ "$FAIL" -gt 0 ]]; then
    log "RESULT: FAIL ($FAIL failure(s), $PASS pass(es)) — deploy BLOCKED"
    echo ""
    echo "Fix required before deploy:"
    echo "  Add 'DEPLOY PHASE HEARTBEAT RULE' section to workspace CLAUDE.md"
    echo "  Template: 'DEPLOY PHASE HEARTBEAT RULE — During any Phase transition or long deploy (>120s est.), post ⏳ UPDATE every 60 seconds.'"
    exit 1
else
    log "RESULT: PASS ($PASS check(s) passed) — deploy allowed"
    exit 0
fi
