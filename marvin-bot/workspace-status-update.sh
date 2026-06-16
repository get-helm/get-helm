#!/bin/bash
# workspace-status-update.sh — generate + update pinned status message for a workspace channel
# Usage: workspace-status-update.sh WORKSPACE_NAME CHANNEL_ID

set -euo pipefail

WORKSPACE_NAME="$1"
CHANNEL_ID="$2"

if [[ -z "$WORKSPACE_NAME" || -z "$CHANNEL_ID" ]]; then
  echo "Usage: workspace-status-update.sh WORKSPACE_NAME CHANNEL_ID" >&2
  exit 1
fi

WORKSPACE_DIR=~/helm-workspace/workspaces/"$WORKSPACE_NAME"
STATE_FILE="$WORKSPACE_DIR/pinned-status-msg.txt"

if [[ ! -d "$WORKSPACE_DIR" ]]; then
  echo "workspace-status-update.sh: workspace dir not found: $WORKSPACE_DIR" >&2
  exit 1
fi

# Generate status message via Python
STATUS_MSG=$(python3 - "$WORKSPACE_NAME" "$WORKSPACE_DIR" << 'PYEOF'
import json, os, sys, re
from datetime import datetime, timezone

workspace_name = sys.argv[1]
workspace_dir = os.path.expanduser(sys.argv[2])
streams_file = os.path.join(workspace_dir, 'workspace-streams.json')
decisions_log = os.path.expanduser('~/helm-workspace/system/decisions-log.md')

# Load streams
streams = []
try:
    with open(streams_file) as f:
        data = json.load(f)
        streams = data.get('streams', [])
except Exception:
    pass

# Bucket streams by status
ready = [s for s in streams if s.get('status') == 'ready']
blocked = [s for s in streams if s.get('status') == 'blocked-on-jerry']
in_prog = [s for s in streams if s.get('status') == 'in-progress']
done = [s for s in streams if s.get('status') == 'done']

# Determine phase + current status (plain English — no A/B/C/D labels)
if blocked:
    phase = 'Waiting for Input'
    current = blocked[0].get('blocked_on', 'Question pending')[:80]
elif in_prog:
    phase = 'Building & Testing'
    current = in_prog[0].get('next_action', 'Working...')[:80]
elif ready:
    phase = 'Building & Testing'
    current = ready[0].get('next_action', 'Ready to advance')[:80]
elif done and not ready:
    phase = 'Live'
    current = 'All streams complete'
else:
    phase = 'Planning'
    current = 'Setting up'

ts = datetime.now(timezone.utc).strftime('%b %d %I:%M %p UTC')

# Build stream list (cap at 6)
lines = []
for s in streams[:6]:
    st = s.get('status', '')
    title = s.get('title', 'Untitled')[:55]
    icon = {'done': '✅', 'in-progress': '🔄', 'blocked-on-jerry': '⏸', 'ready': '⏳'}.get(st, '⬜')
    lines.append(f'  {icon} {title}')

streams_block = '\n'.join(lines) if lines else '  (no work items yet)'

title = workspace_name.replace('-', ' ').title()
print(f"📊 **{title} — Status**\n\n**Phase:** {phase}\n**Now:** {current}\n**Updated:** {ts}\n\n**Work items:**\n{streams_block}\n\nQuestions? Just ask.")
PYEOF
)

if [[ -z "$STATUS_MSG" ]]; then
  echo "workspace-status-update.sh: failed to generate status message" >&2
  exit 1
fi

# Update pinned message
bash ~/marvin-bot/discord-update-pinned.sh "$CHANNEL_ID" "$STATUS_MSG" "$STATE_FILE"
