#!/bin/bash
# preferences-update.sh — update a HELM user preference setting
# Usage: preferences-update.sh SETTING VALUE CHANNEL_ID
# Updates the appropriate file (VOICE-AND-STYLE.md, ABOUT-ME.md, or CONFIG.md)
# Outputs: JSON with {success, old_value, new_value, file_updated, confirmation_msg}

set -euo pipefail

SETTING="$1"
VALUE="$2"
CHANNEL_ID="${3:-}"

VOICE_STYLE=~/helm-workspace/VOICE-AND-STYLE.md
ABOUT_ME=~/helm-workspace/ABOUT-ME.md

# Settings registry: maps setting name → (file, key, valid_values, description)
python3 << PYEOF
import json, re, sys, os
from datetime import datetime, timezone

setting = "${SETTING}".lower().strip()
value = "${VALUE}".strip()

# Registry maps canonical setting name to config
SETTINGS = {
    "formality": {
        "file": "VOICE-AND-STYLE",
        "key": "PREFERRED_TONE",
        "valid": None,  # free text
        "description": "How HELM communicates with you",
        "transform": lambda v: f"Conversational and brief. Like a capable assistant giving a quick update, not an engineer submitting a ticket." if v.lower() == "casual" else f"Professional and precise. Clear, structured responses." if v.lower() == "professional" else v
    },
    "verbosity": {
        "file": "VOICE-AND-STYLE",
        "key": "RESPONSE_LENGTH_PREFERENCE",
        "valid": ["brief", "detailed", "short", "long"],
        "description": "How much detail you want in responses",
        "transform": lambda v: "Short. Mobile-first. If it takes more than 30 seconds to read, it's too long." if v.lower() in ["brief","short"] else "Detailed. Include context, reasoning, and full implementation details."
    },
    "pushback_volume": {
        "file": "VOICE-AND-STYLE",
        "key": "STANDING_PREFERENCES",
        "valid": ["often", "occasionally", "never"],
        "description": "How much HELM challenges your ideas",
        "update_mode": "append_context",
    },
    "activity_reporting": {
        "file": "VOICE-AND-STYLE",
        "key": "STANDING_PREFERENCES",
        "valid": ["silent", "brief", "detailed"],
        "description": "How HELM reports completed tasks",
        "update_mode": "append_context",
    },
    "display_mode": {
        "file": "VOICE-AND-STYLE",
        "key": "DISPLAY_MODE",
        "valid": ["dark", "light"],
        "description": "Discord theme preference",
        "transform": lambda v: v.lower()
    },
    "role": {
        "file": "ABOUT-ME",
        "key": "OCCUPATION",
        "valid": None,  # free text
        "description": "Your role or title",
        "transform": lambda v: v
    },
    "timezone": {
        "file": "ABOUT-ME",
        "key": "TIMEZONE",
        "valid": None,
        "description": "Your timezone",
        "transform": lambda v: v
    },
    "tone": {
        "file": "VOICE-AND-STYLE",
        "key": "PREFERRED_TONE",
        "valid": None,
        "description": "How HELM communicates with you",
        "transform": lambda v: f"Conversational and brief." if v.lower() == "casual" else f"Professional and precise. Clear, structured responses." if v.lower() == "professional" else v
    },
    "communication_style": {
        "file": "VOICE-AND-STYLE",
        "key": "PREFERRED_TONE",
        "valid": None,
        "description": "How HELM communicates with you",
        "transform": lambda v: f"Conversational and brief." if v.lower() == "casual" else f"Professional and precise." if v.lower() == "professional" else v
    },
    "response_length": {
        "file": "VOICE-AND-STYLE",
        "key": "RESPONSE_LENGTH_PREFERENCE",
        "valid": None,
        "description": "How long HELM's responses are",
        "transform": lambda v: v
    },
    "information_style": {
        "file": "VOICE-AND-STYLE",
        "key": "INFORMATION_STYLE",
        "valid": None,
        "description": "How HELM presents information",
        "transform": lambda v: v
    },
    "name": {
        "file": "ABOUT-ME",
        "key": "USER_PREFERRED_NAME",
        "valid": None,
        "description": "Your preferred name",
        "transform": lambda v: v
    },
}

# Fuzzy match setting name
cfg = SETTINGS.get(setting)
if not cfg:
    # Try partial match
    matches = [k for k in SETTINGS if setting in k or k in setting]
    if len(matches) == 1:
        cfg = SETTINGS[matches[0]]
        setting = matches[0]
    elif len(matches) > 1:
        print(json.dumps({"success": False, "error": f"Ambiguous setting '{setting}' — did you mean: {', '.join(matches)}?"}))
        sys.exit(0)
    else:
        valid_list = ", ".join(sorted(SETTINGS.keys()))
        print(json.dumps({"success": False, "error": f"Unknown setting '{setting}'. Valid settings: {valid_list}"}))
        sys.exit(0)

# Validate value
if cfg.get("valid") and value.lower() not in cfg["valid"]:
    print(json.dumps({"success": False, "error": f"Invalid value '{value}' for '{setting}'. Valid options: {', '.join(cfg['valid'])}"}))
    sys.exit(0)

# Apply transform
transform = cfg.get("transform")
new_val = transform(value) if transform else value

# Determine file path
file_map = {
    "VOICE-AND-STYLE": os.path.expanduser("~/helm-workspace/VOICE-AND-STYLE.md"),
    "ABOUT-ME": os.path.expanduser("~/helm-workspace/ABOUT-ME.md"),
}
filepath = file_map.get(cfg["file"])
if not filepath or not os.path.exists(filepath):
    print(json.dumps({"success": False, "error": f"Config file not found: {cfg['file']}"}))
    sys.exit(0)

key = cfg["key"]
content = open(filepath).read()

# Find current value
old_val = None
pattern = re.compile(rf'^{re.escape(key)}=(.*)$', re.MULTILINE)
m = pattern.search(content)
if m:
    old_val = m.group(1).strip()

if old_val == new_val:
    print(json.dumps({"success": True, "changed": False, "message": f"'{setting}' is already set to that value."}))
    sys.exit(0)

# Update the file
if m:
    new_content = pattern.sub(f'{key}={new_val}', content, count=1)
else:
    new_content = content + f'\n{key}={new_val}\n'

with open(filepath, 'w') as f:
    f.write(new_content)

# Format confirmation
confirm = f"✅ Updated: **{setting}**\n  old: {old_val or '(not set)'}\n  new: {new_val}"

print(json.dumps({
    "success": True,
    "changed": True,
    "setting": setting,
    "key": key,
    "file": cfg["file"],
    "old_value": old_val,
    "new_value": new_val,
    "confirmation": confirm
}))
PYEOF
