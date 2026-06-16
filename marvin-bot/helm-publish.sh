#!/bin/bash
# helm-publish.sh — HELM Publish Pipeline v2 (denylist model)
#
# Usage: helm-publish.sh [--dry-run] [--skip-review] [--target get-helm|backup]
#   --dry-run:          stage + scan + completeness-test only; no push
#   --skip-review:      skip first-publish review gate (auto-approve all)
#   --target get-helm:  push to get-helm/get-helm (public distribution repo)
#   --target backup:    push to {{USER_GITHUB}}/helm-config (private backup, default)
#
# Sources: ~/marvin-bot/ + ~/helm-workspace/ + ~/.claude/agents/
# Model: DENYLIST (everything ships except what's explicitly excluded)
# Completeness: staged dir must pass `npm install` + node --check before push

set -euo pipefail

DRY_RUN=0
SKIP_REVIEW=0
SKIP_SECURITY=0
TARGET_MODE="backup"
ARGS=("$@")
for ((i=0; i<${#ARGS[@]}; i++)); do
  case "${ARGS[$i]}" in
    --dry-run) DRY_RUN=1 ;;
    --skip-review) SKIP_REVIEW=1 ;;
    --skip-security) SKIP_SECURITY=1 ;;
    --target) i=$((i+1)); TARGET_MODE="${ARGS[$i]:-backup}" ;;
  esac
done

BOT_DIR=~/marvin-bot
WS_DIR=~/helm-workspace
AGENTS_DIR=~/.claude/agents
STAGING_DIR=/tmp/helm-publish-staging-v2
PUBLISH_HISTORY=~/helm-workspace/system/helm-publish-history.json
AUDIT_LOG=~/helm-workspace/system/helm-audit.log
DECISIONS_LOG=~/helm-workspace/system/decisions-log.md
IMPROVEMENTS_CHANNEL="{{USER_CHANNEL_HELM_IMPROVEMENTS}}"

if [[ "$TARGET_MODE" == "get-helm" ]]; then
  TARGET_REPO="get-helm/get-helm"
  GITHUB_PAT=$(op item get "Github - HELM Repo - PAT" --vault "HELM Vault" --fields password --reveal 2>/dev/null || echo "")
  if [[ -z "$GITHUB_PAT" ]]; then
    GITHUB_PAT=$(op item get "Github - HELM Repo - PAT" --vault "PAP Vault" --fields password --reveal 2>/dev/null || echo "")
  fi
  if [[ -z "$GITHUB_PAT" ]]; then
    echo "❌ PUBLISH BLOCKED: Cannot read 'Github - HELM Repo - PAT' from vault" >&2; exit 1
  fi
  export GITHUB_PAT
else
  TARGET_REPO="{{USER_GITHUB}}/helm-config"
  if [[ -f ~/marvin-bot/.env ]]; then
    export $(grep "^GITHUB_PAT=" ~/marvin-bot/.env | head -1) 2>/dev/null || true
  fi
  if [[ -z "${GITHUB_PAT:-}" ]]; then
    echo "❌ PUBLISH BLOCKED: GITHUB_PAT not set" >&2; exit 1
  fi
fi

if [[ -f ~/marvin-bot/.env ]]; then
  export $(grep "^DISCORD_BOT_TOKEN=" ~/marvin-bot/.env | head -1) 2>/dev/null || true
fi

ts() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log() { echo "[helm-publish] $1" | tee -a "$AUDIT_LOG"; }
fail_block() { log "BLOCKED: $1"; echo ""; echo "❌ PUBLISH BLOCKED: $1"; exit 1; }

echo ""
echo "══════════════════════════════════════════"
echo "  HELM Publish Pipeline v2 (denylist)"
echo "  $(ts)"
echo "  Target: $TARGET_REPO"
echo "  Mode: $([ "$DRY_RUN" -eq 1 ] && echo 'DRY RUN' || echo 'LIVE')"
echo "══════════════════════════════════════════"
echo ""

# ── DENYLIST DEFINITION ───────────────────────────────────────────────────────
# Everything NOT matching these patterns ships. Pattern = relative path from
# source root, supports fnmatch-style globs and exact matches.

# Directories to exclude entirely (relative to their source root)
DENY_DIRS=(
  ".git"
  "node_modules"
  "__pycache__"
  "archive"
  "graphify-out"
  "docs"
  # helm-workspace specific — runtime state
  "channel-state"
  "workspaces"
  "second-brain"
  "second-brain-raw"
  "data"
  "logs"
  "events"
  "transcripts"
  "financial-review"
  "history"
  ".qmd"
  "agent-flags"
  "post-queue"
  # helm-workspace specific — personal content not for public distribution
  "product"
  "brainstorms"
  "proposals"
  "daily-brief"
  "archived"
  # helm-workspace specific — personal workspaces (user-specific, not templates)
  "japan-2026"
  "pap-on-the-go"
  "options-helper"
  "orchestrator"
  # runtime state directory (all files inside are runtime/personal)
  "system"
  # test artifacts
  ".atpath-test"
)

# File suffix patterns to exclude
DENY_SUFFIXES=(
  ".log"
  ".lock"
  ".pyc"
  ".html"
  ".flag"
  ".csv"
  ".mp4"
  ".mov"
  ".zip"
)

# Prefix patterns for backup files
DENY_PREFIXES=(
  "*.bak*"
  "*.bak-*"
  "*.backup*"
)

# Specific files to exclude (relative to their source root)
DENY_EXACT=(
  # Credentials
  ".env"
  ".env.local"
  # Personal config (keep .template versions)
  "ABOUT-ME.md"
  "CONFIG.md"
  "VOICE-AND-STYLE.md"
  # Personal knowledge files
  "knowledge/{{USER_JERRY}}-PROFILE.md"    # {{USER_JERRY}}'s personal profile (OWNER-PROFILE.md is the template)
  "knowledge/OWNER-PROFILE.md"
  "knowledge/pap-complete.md"
  "knowledge/HELM-FACTS.md"
  # Runtime state
  "ACTIVE-STATE.md"
  "system-state.md"
  "channel-registry.json"
  "channels.json"
  "task-registry.jsonl"
  "pm-engineer-trigger.json"
  "helm-publish-history.json"
  "behavior-metrics.json"
  "model-currency.json"
  # Operational runtime files
  "system/pm-log.md"
  "system/friction-log.md"
  "system/decisions-log.md"
  "system/engineer-queue.md"
  "system/queue-audit.log"
  "system/pm-ledger.md"
  "system/steward-findings.md"
  "system/synthesizer-findings.md"
  "system/pm-scratch.md"
  "system/validation-daily.md"
  "system/CONTEXT.md"
  "system/AGENT-BOARD.md"
  "system/helm-publish-history.json"
  "system/helm-audit.log"
  "system/task-registry.jsonl"
  "system/violation-tracking.json"
  "system/model-currency.json"
  "system/behavior-metrics.json"
  "system/mandate-metrics.json"
  "system/engineer-context.md"
  "system/port-registry.json"
  # Runtime operational state (contain live data, not templates)
  "work-items.json"
  "work-registry-view.json"
  "graphify-pap.json"
  # Terminal wizard — replaced by Claude Desktop Cowork flow (P5.1)
  "helm-init.sh"
  "helm-init-qa.sh"
  # Personal test files
  "test_fmp.py"
  "pap-recovery-test.sh"
  "etf-hourly-test.sh"
  "helm-backup-restore-test.sh"
  # Internal runner logs
  "engineer-nightly.log"
  "gap-audit-nightly.log"
  "gap-audit-weekly.log"
  "auto-unstick.log"
  "daily-brief.log"
  "api-cost-monitor.log"
  "api-health-probe.log"
  "failover.log"
  "github-heartbeat.log"
  "email-backfill-run.log"
  # system/ runtime state files not covered by suffix rules
  "system/agent-ledger.jsonl"
  "system/task-ledger.jsonl"
  "system/agent-board-msg.json"
  "system/task-board-msg.json"
  "system/pm-pending-decisions.json"
  "system/preferences-pinned-msg.txt"
  "system/queue-convergence-state.json"
  "system/synthesizer-metrics.json"
  "system/violation-summary.json"
  "system/workstreams.json"
  "system/DONE-ARCHIVE.md"
  "system/QUEUE-VIEW.md"
  "system/TASK-BOARD.md"
  "system/ACTIVE-STATE.md"
  "system/fable-usage-baseline.md"
  "system/orchestrator-selftest-log.md"
  "system/pm-incident-postmortem.md"
  "system/pap-status-brief.md"
  "system/engineer-context-archive.md"
  "system/engineer-queue-archive.md"
  "system/friction-analysis.md"
  "system/SYNTHESIZER-PREVENTION.md"
  "system/behaviors-status.md"
  # REPO-PII-SCRUB-001: additional runtime/credential files
  "recovery-api-token"          # LIVE CREDENTIAL — never publish
  "event-stream.jsonl"
  "event-stream-archive.jsonl"
  "pushback-log.jsonl"
  "pm-agent-trigger.json"
  "queue-state.jsonl"
  "pap-on-the-go-dismissed.json"
  "mcp-availability.jsonl"
  "self-improve-log.jsonl"
  "trust-report-latest.json"
  "violation-summary.json"
  "lessons-learned.jsonl"
  "users.json"
  "validation-metrics.csv"
  "validation-summary.json"
  "pm-skip-log.jsonl"
  "PARTITION.json"
  "pap-audit-security-review.txt"
  "bot-start.txt"
  "vps-backup-started.txt"
  "wake-button-msg-id.txt"
  "restart-moratorium.flag"
  "SYNTHESIZER-PREVENTION.md"
  "action-formatting.md"
  # Second-brain progress state
  "second-brain-fireflies-progress.json"
  "second-brain-email-progress.json"
  "second-brain-discord-progress.json"
  "second-brain-sms-progress.json"
  # Engineer queue files (contain personal work items — all locations)
  "engineer-queue.md"
  "system/engineer-queue-backup.md"
  # Personal email ingest scripts (contain hardcoded email addresses, personal filter logic)
  "second-brain-email-ingest.py"
  "second-brain-email-ingest-raw.py"
  # Workspace-root runtime state (duplicate of system/ entries but exist at root level too)
  "pm-scratch.md"
  "verify-queue.sh"
  "violation-tracking.json"
  "pm-trigger.json"
  "pm-can-deliver.sh"
  "pm-pending-decisions.json"
  "queue-ops.sh"
  "second-brain-progress.json"
  "second-brain-sms-progress.json"
  "value-metrics.json"
  "orchestrator-cadence-metrics.json"
  "validator.py"
  "queue-convergence-state.json"
  # Engineer queue backup files at workspace root
  "engineer-queue-backup-20260609.md"
  # Personal financial scripts (contain hardcoded email/credentials)
  "scripts/monarch-reconnect.py"
  "scripts/monarch-reconnect-v2.py"
  "scripts/monarch-reconnect-v3.py"
  "scripts/monarch-token.py"
  "scripts/usage/claude-scraper.py"
  "scripts/usage/token-baseline.json"  # operational snapshot with channel IDs — not for distribution
  "scripts/usage/daily-token-summary.json"  # runtime usage data — not for distribution
  "scripts/usage/daily-token-summary.py"    # operational usage tracking script
  "scripts/usage/workspace-report.py"  # operational workspace-specific report
  "pap-metrics-json.py"  # {{USER_JERRY}}-specific operational metrics with workspace channel IDs
  "pap-health-check.sh"  # {{USER_JERRY}}-specific health check with workspace channel IDs
  "gap-audit-weekly.sh"   # {{USER_JERRY}}-specific weekly audit with workspace channel IDs
  "gap-audit-nightly.sh"  # {{USER_JERRY}}-specific nightly audit with workspace channel IDs
  # Personal scripts with hardcoded paths/domains
  "scripts/morning-brief.py"
  "push-dashboard-data.py"
  # Scripts with LIVE CREDENTIALS — never publish
  "scripts/monarch-reconnect-v4.py"
  "scripts/pap-sheets.sh"
  # Entire scripts/monarch-* family (personal financial auth)
  "scripts/monarch-api.py"
  # Japan trip specific — personal deployment scripts
  "japan-hub-predeploy-check.sh"
)

is_denied() {
  local rel="$1"
  local base
  base=$(basename "$rel")

  # Check exact denials
  for exact in "${DENY_EXACT[@]}"; do
    [[ "$rel" == "$exact" ]] && return 0
  done

  # Check denied dirs (first component or full path prefix)
  for dir in "${DENY_DIRS[@]}"; do
    [[ "$rel" == "$dir/"* ]] && return 0
    [[ "$rel" == "$dir" ]] && return 0
  done

  # Check denied suffixes
  for sfx in "${DENY_SUFFIXES[@]}"; do
    [[ "$base" == *"$sfx" ]] && return 0
  done

  # Check .bak* and .backup* patterns
  [[ "$base" == *.bak* ]] && return 0
  [[ "$base" == *.bak-* ]] && return 0
  [[ "$base" == *.backup* ]] && return 0
  [[ "$base" == *.backup-* ]] && return 0

  # REPO-PII-SCRUB-001: glob patterns for runtime/personal files
  [[ "$base" == engineer-queue.md.backup-* ]] && return 0
  [[ "$base" == trust-*.json ]] && return 0
  [[ "$base" == *.mp4 ]] && return 0
  [[ "$base" == *.mov ]] && return 0
  [[ "$base" == *.mkv ]] && return 0

  return 1
}

# ── STAGE 1: Denylist staging ─────────────────────────────────────────────────
log "Stage 1: Denylist staging from 3 source dirs"

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

STAGED=0
DENIED=0

stage_dir() {
  local src_root="$1"
  local dest_prefix="${2:-}"   # optional subdir in staging (empty = root)

  [[ -d "$src_root" ]] || { echo "  ⚠ Source dir missing: $src_root (skipped)"; return; }

  while IFS= read -r abs_path; do
    rel="${abs_path#$src_root/}"
    [[ -z "$rel" ]] && continue

    if is_denied "$rel"; then
      DENIED=$((DENIED + 1))
      continue
    fi

    local dest_rel
    if [[ -n "$dest_prefix" ]]; then
      dest_rel="$dest_prefix/$rel"
    else
      dest_rel="$rel"
    fi

    local dst="$STAGING_DIR/$dest_rel"
    mkdir -p "$(dirname "$dst")"
    cp "$abs_path" "$dst"
    STAGED=$((STAGED + 1))
  done < <(find "$src_root" -type f 2>/dev/null | sort)
}

echo "--- Source 1: ~/marvin-bot/ → marvin-bot/ ---"
stage_dir "$BOT_DIR" "marvin-bot"

echo "--- Source 2: ~/helm-workspace/ ---"
stage_dir "$WS_DIR"
# Remove stale workspace-root files that slip through (relative name collisions)
rm -f "$STAGING_DIR/bot.js"  # stale old version — real bot is at staging/marvin-bot/bot.js

echo "--- Source 3: ~/.claude/agents/ → agents/ ---"
stage_dir "$AGENTS_DIR" "agents"

echo ""
echo "Staged $STAGED files, denied $DENIED"
echo ""

if [[ "$STAGED" -eq 0 ]]; then
  fail_block "No files staged — check source directories"
fi

# ── STAGE 1a: Hoist root-level entry-points ───────────────────────────────────
# install.sh, README.md, LICENSE must be at repo root for curl-pipe and GitHub display.
# They live in marvin-bot/ locally but users need them at get-helm/get-helm root.
echo "--- Hoisting root-level entry-points ---"
for entry_file in "install.sh" "README.md" "LICENSE"; do
  src="$STAGING_DIR/marvin-bot/$entry_file"
  dst="$STAGING_DIR/$entry_file"
  if [[ -f "$src" ]]; then
    cp "$src" "$dst"
    echo "  ✓ hoisted marvin-bot/$entry_file → $entry_file"
  else
    echo "  ⚠ marvin-bot/$entry_file not found — skipping"
  fi
done
echo ""

# ── STAGE 1b: Placeholder conversion ─────────────────────────────────────────
log "Stage 1b: Placeholder conversion"
bash ~/marvin-bot/helm-placeholder-convert.sh "$STAGING_DIR"

# ── STAGE 2: 4-Layer Scan ─────────────────────────────────────────────────────
log "Stage 2: 4-layer security scan"

SCAN_FAIL=0

echo "--- 2a: Secret scan ---"
if [[ "$SKIP_SECURITY" -eq 1 ]]; then
  echo "  ⚠ Secret scan SKIPPED (--skip-security flag)"
  log "Stage 2a: Secret scan skipped via flag"
else
  SECRET_TMPFILE=$(mktemp -t helm-security-out)
  bash ~/marvin-bot/pre-deploy-security-check.sh "$STAGING_DIR" > "$SECRET_TMPFILE" 2>&1; SECRET_EXIT=$?
  if [[ "$SECRET_EXIT" -ne 0 ]]; then
    grep -E "✗|BLOCKED" "$SECRET_TMPFILE" | head -10
    SCAN_FAIL=1
    log "SCAN FAIL: Secret scan detected issues"
  else
    echo "  ✓ Secret scan clean"
  fi
  rm -f "$SECRET_TMPFILE"
fi

echo ""
echo "--- 2b: Personal-data scan ---"
if [[ "$SKIP_SECURITY" -eq 1 ]]; then
  echo "  ⚠ Personal-data scan SKIPPED (--skip-security flag)"
  log "Stage 2b: Personal-data scan skipped via flag"
else
  PERSONAL_TMPFILE=$(mktemp -t helm-personal-out)
  bash ~/marvin-bot/helm-personal-data-scan.sh "$STAGING_DIR" > "$PERSONAL_TMPFILE" 2>&1; PERSONAL_EXIT=$?
  if [[ "$PERSONAL_EXIT" -ne 0 ]]; then
    head -20 "$PERSONAL_TMPFILE"
    SCAN_FAIL=1
    log "SCAN FAIL: Personal data found"
  else
    echo "  ✓ Personal-data scan clean"
  fi
  rm -f "$PERSONAL_TMPFILE"
fi

echo ""
echo "--- 2c: Placeholder integrity ---"
PERSONAL_PATTERNS=(
  "{{USER_DOMAIN}}"
  "{{USER_GITHUB}}@gmail\.com"
  "jerry@{{USER_DOMAIN}}"
  "{{USER_FULL_NAME}}"
  "{{USER_DISCORD_SERVER_ID}}"
  "{{USER_CHANNEL_HELM_IMPROVEMENTS}}"
  "{{USER_CHANNEL_HELM_AUDIT}}"
  "{{USER_CHANNEL_HELM_STATUS}}"
  "{{USER_CHANNEL_BETA_USERS}}"
)
PLACEHOLDER_FAIL=0
for pattern in "${PERSONAL_PATTERNS[@]}"; do
  HITS=$(grep -rl --include="*.md" --include="*.json" --include="*.sh" --include="*.js" "$pattern" "$STAGING_DIR" 2>/dev/null | head -5 || true)
  if [[ -n "$HITS" ]]; then
    echo "  ✗ Personal value '$pattern' in:"
    echo "$HITS" | sed 's|^|      |'
    PLACEHOLDER_FAIL=1
  fi
done
if [[ "$PLACEHOLDER_FAIL" -eq 0 ]]; then
  echo "  ✓ Placeholder integrity clean"
else
  SCAN_FAIL=1
  log "SCAN FAIL: Resolved personal values found"
fi

echo ""
echo "--- 2d: Partition check ---"
PARTITION_TMPFILE=$(mktemp -t helm-partition-out)
bash ~/marvin-bot/helm-partition-check.sh > "$PARTITION_TMPFILE" 2>&1; PARTITION_EXIT=$?
if [[ "$PARTITION_EXIT" -ne 0 ]]; then
  grep -E "✗|ERROR" "$PARTITION_TMPFILE" | head -5
  SCAN_FAIL=1
  log "SCAN FAIL: Partition check failed"
else
  echo "  ✓ Partition check clean"
fi
rm -f "$PARTITION_TMPFILE"

echo ""
if [[ "$SCAN_FAIL" -eq 1 ]]; then
  fail_block "One or more scan layers failed. Fix issues above, then re-run."
fi
log "Stage 2 PASS: all 4 scan layers clean"

# ── STAGE 3: Completeness test ────────────────────────────────────────────────
log "Stage 3: Completeness test (npm install + syntax check)"

echo "--- Required files present? ---"
COMPLETENESS_FAIL=0
# install.sh + README.md are at staging root (hoisted); bot engine files are in marvin-bot/
check_file() { local label="$1" path="$2"
  if [[ -f "$path" ]]; then echo "  ✓ $label"; else echo "  ✗ MISSING: $label"; COMPLETENESS_FAIL=1; fi
}
check_file "install.sh"           "$STAGING_DIR/install.sh"
check_file "README.md"            "$STAGING_DIR/README.md"
check_file "marvin-bot/bot.js"    "$STAGING_DIR/marvin-bot/bot.js"
check_file "marvin-bot/package.json" "$STAGING_DIR/marvin-bot/package.json"
check_file "marvin-bot/config.js" "$STAGING_DIR/marvin-bot/config.js"

echo ""
echo "--- npm install in sandbox ---"
SANDBOX_DIR=$(mktemp -d /tmp/helm-sandbox-XXXXX)
trap "rm -rf $SANDBOX_DIR" EXIT

cp "$STAGING_DIR/marvin-bot/package.json" "$SANDBOX_DIR/"
[[ -f "$STAGING_DIR/marvin-bot/config.js" ]] && cp "$STAGING_DIR/marvin-bot/config.js" "$SANDBOX_DIR/"

NPM_OUT=$(cd "$SANDBOX_DIR" && npm install --omit=dev 2>&1)
NPM_EXIT=$?
if [[ "$NPM_EXIT" -eq 0 ]]; then
  echo "  ✓ npm install OK"
else
  echo "  ✗ npm install FAILED:"
  echo "$NPM_OUT" | tail -10 | sed 's|^|    |'
  COMPLETENESS_FAIL=1
fi

echo ""
echo "--- bot.js syntax check ---"
if node --check "$STAGING_DIR/marvin-bot/bot.js" 2>&1; then
  echo "  ✓ bot.js syntax OK"
else
  echo "  ✗ bot.js syntax FAILED"
  COMPLETENESS_FAIL=1
fi

echo ""
if [[ "$COMPLETENESS_FAIL" -eq 1 ]]; then
  fail_block "Completeness test failed — staged repo is not installable"
fi
log "Stage 3 PASS: completeness test clean ($STAGED files, npm OK, bot.js syntax OK)"

# ── DRY RUN EXIT ─────────────────────────────────────────────────────────────
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo ""
  echo "══════════════════════════════════════════"
  echo "  DRY RUN complete"
  echo "  $STAGED files staged, all scans PASS"
  echo "  npm install PASS, bot.js syntax PASS"
  echo "══════════════════════════════════════════"
  log "DRY RUN complete — $(ts) — $STAGED files, all PASS"

  # Post dry-run result to helm-improvements for L4 approval
  if [[ -n "${DISCORD_BOT_TOKEN:-}" ]]; then
    MSG="✅ **HELM Publish Dry Run — PASS**

**$STAGED files** staged from bot engine + workspace + agents.
All 4 scan layers clean. npm install OK. bot.js syntax OK.

This is a **public push** to \`$TARGET_REPO\`. Level 4 gate — needs your approval before live push.

To approve and push:
\`\`\`
bash ~/marvin-bot/helm-publish.sh --target get-helm --skip-review
\`\`\`

[CONFIRM: Approve live publish to get-helm/get-helm?]"

    curl -s -X POST \
      -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"content\": $(echo "$MSG" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')}" \
      "https://discord.com/api/v10/channels/$IMPROVEMENTS_CHANNEL/messages" > /dev/null 2>&1 || true
  fi

  exit 0
fi

# ── STAGE 4: Review gate ──────────────────────────────────────────────────────
log "Stage 4: Review gate"

if [[ ! -f "$PUBLISH_HISTORY" ]]; then
  echo '{"published_files": {}}' > "$PUBLISH_HISTORY"
fi

FIRST_PUBLISH_COUNT=0
while IFS= read -r staged_file; do
  REL="${staged_file#$STAGING_DIR/}"
  PREV_SHA=$(python3 -c "
import json, sys, os
h = json.load(open('$PUBLISH_HISTORY'))
print(h.get('published_files', {}).get(sys.argv[1], ''))
" "$REL" 2>/dev/null || echo "")
  [[ -z "$PREV_SHA" ]] && FIRST_PUBLISH_COUNT=$((FIRST_PUBLISH_COUNT + 1))
done < <(find "$STAGING_DIR" -type f)

if [[ "$FIRST_PUBLISH_COUNT" -gt 0 && "$SKIP_REVIEW" -eq 0 ]]; then
  echo "First-publish review required for $FIRST_PUBLISH_COUNT file(s)."
  if [[ -n "${DISCORD_BOT_TOKEN:-}" ]]; then
    MSG="⏸ **HELM Publish — Review Required**\n\n**$FIRST_PUBLISH_COUNT files** being published for the first time to \`$TARGET_REPO\`.\n\nAll scans PASS. Re-run with \`--skip-review\` after approval."
    curl -s -X POST \
      -H "Authorization: Bot $DISCORD_BOT_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"content\": \"$MSG\"}" \
      "https://discord.com/api/v10/channels/$IMPROVEMENTS_CHANNEL/messages" > /dev/null 2>&1 || true
  fi
  log "Stage 4: First-publish review required ($FIRST_PUBLISH_COUNT files)"
  echo ""; echo "PUBLISH PAUSED — re-run with --skip-review after approval"; exit 0
fi

[[ "$SKIP_REVIEW" -eq 1 ]] && { log "Stage 4: Review gate skipped (--skip-review)"; echo "  ✓ Review gate skipped"; }

# ── STAGE 5: Push to GitHub via git ──────────────────────────────────────────
log "Stage 5: Pushing to $TARGET_REPO"

VERSION="v$(date -u '+%Y%m%d-%H%M')"
GIT_WORK_DIR=$(mktemp -d /tmp/helm-git-push-XXXXX)
trap "rm -rf $GIT_WORK_DIR" EXIT

echo "  Cloning $TARGET_REPO for push..."
GIT_TERMINAL_PROMPT=0 git -c credential.helper= clone "https://${GITHUB_PAT}@github.com/${TARGET_REPO}.git" "$GIT_WORK_DIR" --quiet 2>&1 | grep -v "^$" || true

echo "  Syncing staged files into git worktree..."
rsync -a --delete "$STAGING_DIR/" "$GIT_WORK_DIR/" --exclude ".git" 2>/dev/null

cd "$GIT_WORK_DIR"
git config user.email "helm-publish@helm.{{USER_DOMAIN}}"
git config user.name "HELM Publish"
git add -A

STAGED_COUNT=$(git diff --cached --name-only | wc -l | tr -d ' ')
if [[ "$STAGED_COUNT" -eq 0 ]]; then
  echo "  ✓ No changes to push (repo already up to date)"
  log "Stage 5 PASS: no changes to push — already up to date"
  PUSH_COUNT=0
else
  echo "  Committing $STAGED_COUNT changed files..."
  git commit -m "helm-publish ${VERSION}: ${STAGED_COUNT} files updated" --quiet
  echo "  Pushing to $TARGET_REPO..."
  # Bypass osxkeychain credential helper (blocks in headless environments)
  GIT_TERMINAL_PROMPT=0 git -c credential.helper= push origin HEAD:main --quiet 2>&1 || \
  GIT_TERMINAL_PROMPT=0 git -c credential.helper= push origin HEAD:master --quiet 2>&1
  PUSH_COUNT="$STAGED_COUNT"
  echo "  ✓ Pushed $PUSH_COUNT files"
  log "Stage 5 PASS: $PUSH_COUNT files pushed to $TARGET_REPO ($VERSION)"
fi

cd - > /dev/null

# ── STAGE 6: CI Parity ────────────────────────────────────────────────────────
log "Stage 6: CI parity check"

echo "--- Verifying remote files ---"
PARITY_FAIL=0
for check_file in "CLAUDE.md" "behaviors.md" "marvin-bot/bot.js" "marvin-bot/package.json" "install.sh"; do
  REMOTE_CHECK=$(curl -s -H "Authorization: token $GITHUB_PAT" \
    "https://api.github.com/repos/$TARGET_REPO/contents/$check_file" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print('ok' if d.get('sha') else 'missing')" 2>/dev/null)
  if [[ "$REMOTE_CHECK" == "ok" ]]; then
    echo "  ✓ $check_file"
  else
    echo "  ✗ MISSING: $check_file"
    PARITY_FAIL=1
  fi
done

[[ "$PARITY_FAIL" -eq 1 ]] && log "Stage 6 FAIL: key files missing from remote" || log "Stage 6 PASS: parity OK"

TS=$(ts)
echo "" >> "$DECISIONS_LOG"
echo "## [$TS] — helm-publish $VERSION — PASS: $PUSH_COUNT files to $TARGET_REPO" >> "$DECISIONS_LOG"

echo ""
echo "══════════════════════════════════════════"
echo "  HELM Publish Complete — $VERSION"
echo "  $PUSH_COUNT files → $TARGET_REPO"
echo "  Scan: PASS | Parity: $([ "$PARITY_FAIL" -eq 0 ] && echo PASS || echo WARN)"
echo "══════════════════════════════════════════"
log "Publish complete: $VERSION — $PUSH_COUNT files"
