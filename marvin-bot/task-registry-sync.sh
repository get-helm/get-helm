#!/usr/bin/env bash
# task-registry-sync.sh — nightly reconciliation of task-registry.jsonl against git commits
# Per REGISTRY-RECONCILE-C-001 ({{USER_JERRY}}-approved Option C)
# Runs at 02:15 PT nightly (after engineer 2am deploy)

set -euo pipefail
REGISTRY="/Users/{{USER_HOME}}/helm-workspace/task-registry.jsonl"
LOG="/Users/{{USER_HOME}}/helm-workspace/system/decisions-log.md"
MARVIN_BOT="/Users/{{USER_HOME}}/marvin-bot"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "[task-registry-sync] Starting reconciliation at $NOW"

python3 << 'PYEOF'
import json, subprocess, re, os
from datetime import datetime, timezone

REGISTRY = "/Users/{{USER_HOME}}/helm-workspace/task-registry.jsonl"
LOG = "/Users/{{USER_HOME}}/helm-workspace/system/decisions-log.md"
MARVIN_BOT = "/Users/{{USER_HOME}}/marvin-bot"
NOW = os.popen("date -u +%Y-%m-%dT%H:%M:%SZ").read().strip()

# Load registry — get most-recent status per ID
latest = {}
queued_at = {}
try:
    with open(REGISTRY) as f:
        for line in f:
            try:
                r = json.loads(line.strip())
                iid = r.get('id')
                if iid:
                    latest[iid] = r.get('status', 'unknown')
                    if r.get('status') == 'queued' and 'queued_at' in r:
                        queued_at[iid] = r['queued_at']
            except: pass
except Exception as e:
    print(f"Error reading registry: {e}")

# Find IDs where latest status = queued
phantom_ids = [iid for iid, status in latest.items() if status == 'queued']
print(f"Queued-status IDs to check: {len(phantom_ids)}")

reconciled = []
orphaned = []

for iid in phantom_ids:
    qa = queued_at.get(iid, '')
    # Search git log for mentions of this ID in commits since it was queued
    try:
        git_cmd = ['git', '-C', MARVIN_BOT, 'log', '--oneline', f'--since={qa or "2026-01-01"}', '--all']
        result = subprocess.run(git_cmd, capture_output=True, text=True, timeout=10)
        commits = result.stdout.strip()
        
        # Check if iid appears in any commit message
        if iid in commits:
            # Find matching commit hash and date
            for line in commits.split('\n'):
                if iid in line:
                    commit_hash = line.split(' ')[0]
                    # Get commit date
                    date_result = subprocess.run(
                        ['git', '-C', MARVIN_BOT, 'log', '-1', '--format=%aI', commit_hash],
                        capture_output=True, text=True, timeout=5
                    )
                    commit_date = date_result.stdout.strip()
                    reconciled.append({'id': iid, 'hash': commit_hash, 'date': commit_date})
                    break
    except Exception as e:
        pass

print(f"Git-matched (reconciled): {len(reconciled)}")
print(f"No git match: {len(phantom_ids) - len(reconciled)}")

if reconciled:
    with open(REGISTRY, 'a') as f:
        for r in reconciled:
            entry = {
                'id': r['id'],
                'status': 'done',
                'shipped_at': NOW,
                'notes': f"auto-reconciled by task-registry-sync.sh from git commit {r['hash']} ({r['date']})"
            }
            f.write(json.dumps(entry) + '\n')

# Log summary
orphaned = [iid for iid in phantom_ids if not any(r['id'] == iid for r in reconciled)]
with open(LOG, 'a') as f:
    f.write(f"\n## [{NOW}] — task-registry-sync.sh: {len(reconciled)} reconciled from git, {len(orphaned)} still orphaned\n")
    if orphaned[:5]:
        f.write(f"  Orphaned IDs (first 5): {', '.join(orphaned[:5])}\n")

print(f"Done. {len(reconciled)} reconciled, {len(orphaned)} genuinely orphaned.")
PYEOF

echo "[task-registry-sync] Complete"
