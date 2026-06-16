#!/bin/bash
# preferences-pinned-update.sh — regenerate and update the pinned preferences message
# Usage: preferences-pinned-update.sh CHANNEL_ID
# Reads VOICE-AND-STYLE.md + ABOUT-ME.md, formats settings display, calls discord-update-pinned.sh

set -euo pipefail

CHANNEL_ID="$1"
if [[ -z "$CHANNEL_ID" ]]; then
  echo "Usage: preferences-pinned-update.sh CHANNEL_ID" >&2
  exit 1
fi

STATE_FILE=~/helm-workspace/system/preferences-pinned-msg.txt

MSG=$(python3 << 'PYEOF'
import os, re
from datetime import datetime, timezone

vs = os.path.expanduser('~/helm-workspace/VOICE-AND-STYLE.md')
am = os.path.expanduser('~/helm-workspace/ABOUT-ME.md')

def read_key(filepath, key):
    try:
        for line in open(filepath):
            if line.startswith(f'{key}='):
                return line[len(key)+1:].strip()
    except Exception:
        pass
    return '(not set)'

# Read values
tone = read_key(vs, 'PREFERRED_TONE')
length = read_key(vs, 'RESPONSE_LENGTH_PREFERENCE')
info_style = read_key(vs, 'INFORMATION_STYLE')
display = read_key(vs, 'DISPLAY_MODE')

name = read_key(am, 'USER_PREFERRED_NAME')
role = read_key(am, 'OCCUPATION')
tz = read_key(am, 'TIMEZONE')
email = read_key(am, 'GOOGLE_EMAIL')

ts = datetime.now(timezone.utc).strftime('%b %d %I:%M %p UTC')

# Truncate long values for display
def short(s, n=60):
    return s[:n] + '...' if len(s) > n else s

msg = f"""⚙️ **Your HELM Preferences**
Last updated: {ts}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
**📢 Communication Style**

Tone: {short(tone)}
Response length: {short(length)}
Information style: {short(info_style)}
Display mode: {display}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
**🎯 Profile**

Name: {name}
Role: {short(role)}
Timezone: {tz}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
**✏️ Change a Setting**

Just ask in plain English in this channel.

Examples:
  "Set tone to professional"
  "Make verbosity brief"
  "Change my role to CEO"

HELM confirms + updates this panel instantly."""

print(msg, end='')
PYEOF
)

if [[ -z "$MSG" ]]; then
  echo "preferences-pinned-update.sh: failed to generate message" >&2
  exit 1
fi

bash ~/marvin-bot/discord-update-pinned.sh "$CHANNEL_ID" "$MSG" "$STATE_FILE"
