#!/bin/bash
# discord-post.sh — post a message to Discord as a colored embed
# Usage: discord-post.sh [--stage] CHANNEL_ID "message text"
# --stage: write DELIVER to post-queue for bot.js batching check instead of posting directly.
#          ACK/UPDATE/BLOCK with --stage still post directly (staging is a DELIVER-only concept).
# The phase emoji (👍 ⏳ ⏸ ✅) determines the sidebar color automatically.

STAGE_MODE=0
POSITIONAL_ARGS=()
for arg in "$@"; do
  if [[ "$arg" == "--stage" ]]; then
    STAGE_MODE=1
  else
    POSITIONAL_ARGS+=("$arg")
  fi
done
CHANNEL_ID="${POSITIONAL_ARGS[0]}"
MESSAGE="${POSITIONAL_ARGS[1]}"

if [[ -z "$CHANNEL_ID" || -z "$MESSAGE" ]]; then
  echo "Usage: discord-post.sh [--stage] CHANNEL_ID 'message text'" >&2
  exit 1
fi

# SILENT_RUN gate: redirect automated agent messages to pm-log instead of Discord.
# Rules:
#   1. helm-audit ({{USER_CHANNEL_HELM_AUDIT}}) → ALWAYS silent (it's a read-only log channel)
#   2. SILENT_RUN=1 + helm-status ({{USER_CHANNEL_HELM_STATUS}}) → pm-log
#   3. SILENT_RUN=1 + helm-improvements ({{USER_CHANNEL_HELM_IMPROVEMENTS}}) + no decision marker → pm-log
#      Decision markers = [CONFIRM:, [BUTTON:, ⏸ (block), or explicit DECISION: in message
HELM_AUDIT_CHANNEL='{{USER_CHANNEL_HELM_AUDIT}}'
HELM_STATUS_CHANNEL='{{USER_CHANNEL_HELM_STATUS}}'
HELM_IMPROVEMENTS_CHANNEL='{{USER_CHANNEL_HELM_IMPROVEMENTS}}'
PM_LOG=~/helm-workspace/pm-log.md

_should_silence=0
if [[ "$CHANNEL_ID" == "$HELM_AUDIT_CHANNEL" ]]; then
  _should_silence=1
elif [[ "${SILENT_RUN:-}" == "1" && "$CHANNEL_ID" == "$HELM_STATUS_CHANNEL" ]]; then
  _should_silence=1
elif [[ "${SILENT_RUN:-}" == "1" && "$CHANNEL_ID" == "$HELM_IMPROVEMENTS_CHANNEL" ]]; then
  # Let through: blocks (⏸), confirm/button sentinels, explicit decision markers
  if printf '%s' "$MESSAGE" | grep -qE '\[CONFIRM:|\[BUTTON:|DECISION:'; then
    _should_silence=0
  elif printf '%s' "$MESSAGE" | head -c 8 | grep -q "⏸"; then
    _should_silence=0
  else
    _should_silence=1
  fi
fi

if [[ "$_should_silence" == "1" ]]; then
  _ts=$(date '+%Y-%m-%d %H:%M:%S')
  _label="silenced:${CHANNEL_ID}"
  if [[ "$CHANNEL_ID" == "$HELM_AUDIT_CHANNEL" ]]; then
    # helm-audit posts go to helm-audit.log (file-only per channel consolidation directive)
    HELM_AUDIT_LOG=~/helm-workspace/system/helm-audit.log
    printf '[%s] [%s] %s\n\n' "$_ts" "$_label" "$MESSAGE" >> "$HELM_AUDIT_LOG" 2>/dev/null || true
    echo "discord-post.sh: silenced → helm-audit.log (channel=$CHANNEL_ID)" >&2
  else
    printf '[%s] [%s] %s\n\n' "$_ts" "$_label" "$MESSAGE" >> "$PM_LOG" 2>/dev/null || true
    echo "discord-post.sh: silenced → pm-log (channel=$CHANNEL_ID)" >&2
  fi
  exit 0
fi

BOT_TOKEN="${DISCORD_BOT_TOKEN}"
if [[ -z "$BOT_TOKEN" ]]; then
  # Try reading from .env
  BOT_TOKEN=$(grep "^DISCORD_BOT_TOKEN=" ~/marvin-bot/.env 2>/dev/null | cut -d= -f2-)
fi
if [[ -z "$BOT_TOKEN" ]]; then
  echo "discord-post.sh: DISCORD_BOT_TOKEN not set" >&2
  exit 1
fi

# Read active palette colors
VS_FILE=~/helm-workspace/VOICE-AND-STYLE.md
PRIMARY=$(grep "^COLOR_PRIMARY=" "$VS_FILE" 2>/dev/null | cut -d= -f2 | tr -d '[:space:]' || echo "#7C3AED")
ACCENT1=$(grep "^COLOR_ACCENT_1=" "$VS_FILE" 2>/dev/null | cut -d= -f2 | tr -d '[:space:]' || echo "#06B6D4")
ACCENT2=$(grep "^COLOR_ACCENT_2=" "$VS_FILE" 2>/dev/null | cut -d= -f2 | tr -d '[:space:]' || echo "#F59E0B")

# Detect phase from first bytes (emoji are multi-byte)
FIRST=$(printf '%s' "$MESSAGE" | head -c 6)
PHASE=""
if printf '%s' "$FIRST" | grep -q "✅"; then PHASE="deliver"
elif printf '%s' "$FIRST" | grep -q "👍"; then PHASE="ack"
elif printf '%s' "$FIRST" | grep -q "⏳"; then PHASE="update"
elif printf '%s' "$FIRST" | grep -q "⏸"; then PHASE="block"
fi

# GAP-AUDIT-DELIVER-CHECKMARK: if agent posted a DELIVER without ✅ prefix, auto-prepend it.
# Schema fields (PUSHBACK: + VERIFICATION_REQUIRED:) identify agent DELIVERs — safe to check here
# because discord-post.sh is only invoked by bot scripts, never directly by Discord users.
if [[ -z "$PHASE" ]] && printf '%s' "$MESSAGE" | grep -q "PUSHBACK:" && printf '%s' "$MESSAGE" | grep -q "VERIFICATION_REQUIRED:"; then
  MESSAGE="✅ ${MESSAGE}"
  FIRST=$(printf '%s' "$MESSAGE" | head -c 6)
  PHASE="deliver"
  echo "discord-post.sh: GAP-AUDIT-DELIVER-CHECKMARK — auto-prepended ✅ to DELIVER missing prefix" >&2
fi

# ACK+DELIVER combined: agent used 👍 but included schema fields — override phase to 'deliver'
# so checkpoint is cleared and post-exit-watchdog doesn't treat this turn as incomplete.
if [[ "$PHASE" == "ack" ]] && printf '%s' "$MESSAGE" | grep -q "PUSHBACK:" && printf '%s' "$MESSAGE" | grep -q "VERIFICATION_REQUIRED:"; then
  PHASE="deliver"
  echo "discord-post.sh: ACK+DELIVER combined — phase overridden to deliver (schema fields present)" >&2
fi

if printf '%s' "$FIRST" | grep -q "⏳"; then
  HEX="${ACCENT1/#\#/}"
elif printf '%s' "$FIRST" | grep -q "⏸"; then
  HEX="${ACCENT2/#\#/}"
else
  HEX="${PRIMARY/#\#/}"
fi

COLOR=$((16#${HEX}))

# Run prose/embed validator on DELIVER messages — log violations to friction-log.md
if printf '%s' "$FIRST" | grep -q "✅"; then
  VALIDATOR=~/helm-workspace/validator.py
  if [[ -f "$VALIDATOR" ]]; then
    python3 "$VALIDATOR" "$MESSAGE" >> ~/helm-workspace/friction-log.md 2>&1 || true
  fi
fi

# AGENT-SELF-REFLECTION-001 + SELF-REFLECT-COVERAGE-001: Pre-post self-reflection gate.
# DELIVER: B-17/B-22/schema/B-06/B-13/B-14/RESEARCH-QUALITY checks + auto-rewrite.
# UPDATE:  vagueness_flag check (still working / almost done with no new info) + rewrite.
# Passes CHANNEL_ID as second arg so script can read checkpoint notes for B-13/B-14.
# Never blocks delivery — rewrites replace MESSAGE when successful, else pass through.
# PERF-SELFREFLECT-LATENCY-001: only gate DELIVER. UPDATEs are ephemeral and must not
# pay a blocking LLM-rewrite tax (was adding 15-60s per UPDATE → primary cause of the
# 2026-06-15 slowdown). Vague-UPDATE logging is not worth a synchronous model round-trip.
if [[ "$PHASE" == "deliver" ]]; then
  SELF_REFLECT=~/marvin-bot/self-reflect.py
  if [[ -f "$SELF_REFLECT" ]]; then
    REFLECT_OUT=$(python3 "$SELF_REFLECT" "$MESSAGE" "$CHANNEL_ID" 2>/dev/null || echo '{"approved":true}')
    APPROVED=$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print('yes' if d.get('approved',True) else 'no')" "$REFLECT_OUT" 2>/dev/null || echo "yes")
    if [[ "$APPROVED" == "no" ]]; then
      REWRITTEN=$(python3 -c "import json,sys; print(json.loads(sys.argv[1]).get('rewritten',''))" "$REFLECT_OUT" 2>/dev/null || echo "")
      if [[ -n "$REWRITTEN" && ${#REWRITTEN} -gt 20 ]]; then
        MESSAGE="$REWRITTEN"
        echo "discord-post.sh: SELF-REFLECT rewrite applied (violations auto-corrected)" >&2
      fi
    fi
  fi
fi

# B11-B12-RESEARCH-ENFORCEMENT-001: detect ask-before-research patterns on all agent messages.
# Logs RESEARCH-SKIPPED violations to friction-log; never blocks delivery.
RESEARCH_CHECK=~/marvin-bot/research-check.py
if [[ -f "$RESEARCH_CHECK" ]]; then
  python3 "$RESEARCH_CHECK" "$MESSAGE" 2>/dev/null || true
fi

# Parse sentinels: extract button defs and [EMBED:] data, then strip all sentinels from text
PARSE_OUT=$(DISCORD_MSG="$MESSAGE" COLOR_INT="$COLOR" python3 -c "
import sys, re, json, os

msg = os.environ.get('DISCORD_MSG', '')
color_int = int(os.environ.get('COLOR_INT', '0'))

# Extract [EMBED: title|description|field:value|color:#hex|footer:text|thumb:URL|url:URL|ts:auto|author:Name] — structured data card
# Field prefixes: plain Field:Value = inline, ~Field:Value = full-width non-inline
import datetime
embed_data = None
m_embed = re.search(r'\[EMBED:\s*([^\]]+)\]', msg)
if m_embed:
    parts = [p.strip() for p in m_embed.group(1).split('|')]
    edata = {'title': (parts[0] or 'Summary')[:256], 'color': color_int}
    if len(parts) > 1 and parts[1]:
        edata['description'] = parts[1][:2048]
    fields = []
    for p in parts[2:]:
        pl = p.lower()
        if pl.startswith('color:'):
            hex_val = p[6:].strip().lstrip('#')
            try:
                edata['color'] = int(hex_val, 16)
            except Exception:
                pass
        elif pl.startswith('footer:'):
            edata['footer'] = {'text': p[7:].strip()[:2048]}
        elif pl.startswith('thumb:'):
            edata['thumbnail'] = {'url': p[6:].strip()}
        elif pl.startswith('url:'):
            edata['url'] = p[4:].strip()
        elif pl.startswith('ts:'):
            ts_val = p[3:].strip()
            if ts_val.lower() == 'auto':
                edata['timestamp'] = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
            else:
                edata['timestamp'] = ts_val
        elif pl.startswith('author:'):
            edata['author'] = {'name': p[7:].strip()[:256]}
        else:
            # ~Field:Value = non-inline (full width); Field:Value = inline
            inline = True
            raw = p
            if raw.startswith('~'):
                inline = False
                raw = raw[1:]
            colon_idx = raw.find(':')
            if colon_idx > -1:
                fname = raw[:colon_idx].strip()[:256]
                fval = raw[colon_idx+1:].strip()[:1024]
                if fname and fval:
                    fields.append({'name': fname, 'value': fval, 'inline': inline})
    if fields:
        edata['fields'] = fields
    embed_data = edata
    msg = re.sub(r'\[EMBED:\s*[^\]]+\]', '', msg).strip()

# Render [PROGRESS: N/M label] sentinel — replaces sentinel with Unicode bar inline
m_prog = re.search(r'\[PROGRESS:\s*(\d+)/(\d+)(?:\s+([^\]]*))?\]', msg)
if m_prog:
    n, m_total = int(m_prog.group(1)), int(m_prog.group(2))
    label = (m_prog.group(3) or '').strip()
    filled = min(10, max(0, int(n / m_total * 10) if m_total > 0 else 0))
    bar = '▓' * filled + '░' * (10 - filled)
    progress_text = f'{bar} {n}/{m_total}' + (f' {label}' if label else '')
    msg = msg[:m_prog.start()] + progress_text + msg[m_prog.end():]

# Extract [BUTTON: ...] defs before stripping so we can include them as Discord components
components_json = ''
m = re.search(r'\[BUTTON:\s*([^\]]*)\]', msg)
if m:
    defs = [d.strip() for d in m.group(1).split(';') if d.strip()]
    buttons = []
    for d in defs:
        if '|' in d:
            label, cid = d.split('|', 1)
        else:
            label, cid = d, re.sub(r'\W+', '_', d.lower())
        btn = {'type': 2, 'style': 1, 'label': label.strip()[:80], 'custom_id': cid.strip()[:100]}
        if btn['label']:
            buttons.append(btn)
    if buttons:
        rows = [{'type': 1, 'components': buttons[i:i+5]} for i in range(0, len(buttons), 5)]
        components_json = json.dumps(rows)

# Strip all remaining sentinels from the display text
msg = re.sub(r'\[SHOW_PALETTE_SELECTION\]', '', msg)
msg = re.sub(r'\[CONFIRM:[^\]]*\]', '', msg)
msg = re.sub(r'\[BUTTON:[^\]]*\]', '', msg)
msg = re.sub(r'\[MODAL_BUTTON:[^\]]*\]', '', msg)
msg = msg.strip()

# B-17 length enforcement: bot.js gate flags violations via friction-log + reaction.
# Hard truncation removed — cutting messages mid-sentence loses content and is worse than a long post.

print(json.dumps({'text': msg, 'components': components_json, 'embed_data': embed_data}))
")

MESSAGE=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['text'])" "$PARSE_OUT")
BUTTON_COMPONENTS=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['components'])" "$PARSE_OUT")
EMBED_DATA=$(python3 -c "import json,sys; d=json.loads(sys.argv[1])['embed_data']; print(json.dumps(d) if d else '')" "$PARSE_OUT")

# If [EMBED:] sentinel found, post it as a structured Discord embed
if [[ -n "$EMBED_DATA" ]]; then
  if [[ -n "$BUTTON_COMPONENTS" ]]; then
    PAYLOAD="{\"embeds\":[${EMBED_DATA}],\"components\":${BUTTON_COMPONENTS}}"
  else
    PAYLOAD="{\"embeds\":[${EMBED_DATA}]}"
  fi
else
  # JSON-encode the message for plain text embed
  JSON_MSG=$(python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))" <<< "$MESSAGE")
  if [[ -n "$BUTTON_COMPONENTS" ]]; then
    PAYLOAD="{\"embeds\":[{\"color\":${COLOR},\"description\":${JSON_MSG}}],\"components\":${BUTTON_COMPONENTS}}"
  else
    PAYLOAD="{\"embeds\":[{\"color\":${COLOR},\"description\":${JSON_MSG}}]}"
  fi
fi

# ENG-STAGED-POST-001: if --stage flag is set, write to post-queue for bot.js batching check.
# Only DELIVER phases are staged; ACK/UPDATE/BLOCK post directly even if --stage is passed.
if [[ "$STAGE_MODE" == "1" && "$PHASE" == "deliver" ]]; then
  POST_QUEUE_DIR=~/helm-workspace/post-queue
  mkdir -p "$POST_QUEUE_DIR"
  STAGED_AT=$(python3 -c "import time; print(int(time.time() * 1000))")
  # Unique filename: channelId-timestamp-random
  UUID_PART=$(python3 -c "import random, string; print(''.join(random.choices(string.ascii_lowercase+string.digits, k=8)))")
  STAGE_FILE="${POST_QUEUE_DIR}/${CHANNEL_ID}-${STAGED_AT}-${UUID_PART}.json"
  # invocation_started_at from env (set by bot.js), fallback to staged_at
  INVOCATION_STARTED_AT="${INVOCATION_STARTED_AT:-$STAGED_AT}"
  AUTHOR_ID="${AUTHOR_ID:-}"
  python3 -c "
import json, sys, os
data = {
    'channel_id': sys.argv[1],
    'phase': 'deliver',
    'content': sys.argv[2],
    'staged_at': int(sys.argv[3]),
    'invocation_started_at': int(sys.argv[4]),
    'user_id': sys.argv[5]
}
open(sys.argv[6], 'w').write(json.dumps(data))
" "$CHANNEL_ID" "$MESSAGE" "$STAGED_AT" "$INVOCATION_STARTED_AT" "$AUTHOR_ID" "$STAGE_FILE" 2>/dev/null
  echo "discord-post.sh: STAGED SUCCESSFULLY to ${STAGE_FILE} — bot.js will dispatch (post to Discord) and DELETE this file within ~2-5 seconds. If you check later and the file is GONE, that means your DELIVER POSTED SUCCESSFULLY. Do NOT re-post. File absence = success." >&2
  exit 0
fi

# DELIVER-SEND-DEDUP-001: send-side duplicate gate. This is the only point that can stop a
# duplicate BEFORE it reaches Discord — bot.js's dedup observes messages after they post.
# Incident 2026-06-10T01:22Z: agent staged a DELIVER, bot.js dispatched+deleted the staged
# file within 2s, agent saw the file gone, assumed staging failed, re-posted directly → dupe.
# Rules: any DELIVER within 30s of the last one in the channel is suppressed; a DELIVER with
# an identical first-100-chars header within 10 min is suppressed (same-task regeneration).
MARKER_FILE=~/helm-workspace/channel-state/.deliver-marker-${CHANNEL_ID}
if [[ "$PHASE" == "deliver" ]]; then
  # V6 (AGENT-SLEEP-HARDENING-002): include INVOCATION_STARTED_AT in dedup key so
  # two different tasks with similar headers don't suppress each other.
  DEDUP_RESULT=$(DISCORD_MSG="$MESSAGE" INVOCATION_STARTED_AT="${INVOCATION_STARTED_AT:-}" python3 -c "
import os, sys, time, re
marker = sys.argv[1]
msg = os.environ.get('DISCORD_MSG', '')
curr_invoc = os.environ.get('INVOCATION_STARTED_AT', '')
header = re.sub(r'\s+', ' ', msg)[:100]
if os.path.exists(marker):
    try:
        parts = open(marker).read().split('\n', 2)
        age = time.time() - float(parts[0])
        prev_invoc = parts[1] if len(parts) > 1 else ''
        prev_header = parts[2] if len(parts) > 2 else ''
        # Always suppress within 30s (same-turn duplicate)
        if age < 30:
            print(f'SUPPRESS {int(age)}')
            sys.exit()
        # 10-min header match: only suppress if same invocation (not a new task with similar opener)
        if age < 600 and prev_header == header and curr_invoc and prev_invoc == curr_invoc:
            print(f'SUPPRESS {int(age)}')
            sys.exit()
    except Exception:
        pass
print('OK')
" "$MARKER_FILE")
  if [[ "$DEDUP_RESULT" == SUPPRESS* ]]; then
    AGE_S="${DEDUP_RESULT#SUPPRESS }"
    echo "discord-post.sh: DUPLICATE DELIVER SUPPRESSED — a DELIVER already posted ${AGE_S}s ago in channel ${CHANNEL_ID}. If you staged a DELIVER and the staged file is gone, it WAS dispatched successfully (bot.js deletes staged files on dispatch). Your DELIVER is already in Discord. Do NOT re-post or retry." >&2
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] DELIVER-SEND-DEDUP suppressed channel=${CHANNEL_ID} age=${AGE_S}s" >> ~/helm-workspace/system/friction-log.md 2>/dev/null || true
    exit 0
  fi
fi

TMPFILE=$(mktemp)
RESPONSE=$(curl -s -o "$TMPFILE" -w "%{http_code}" \
  -X POST "https://discord.com/api/v10/channels/${CHANNEL_ID}/messages" \
  -H "Authorization: Bot ${BOT_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

if [[ "$RESPONSE" != "200" ]]; then
  echo "discord-post.sh: HTTP $RESPONSE" >&2
  rm -f "$TMPFILE"
  exit 1
fi

# DELIVER-SEND-DEDUP-001: record successful DELIVER post so the send-side gate can
# suppress duplicates on subsequent calls.
if [[ "$PHASE" == "deliver" ]]; then
  DISCORD_MSG="$MESSAGE" INVOCATION_STARTED_AT="${INVOCATION_STARTED_AT:-}" python3 -c "
import os, sys, time, re
msg = os.environ.get('DISCORD_MSG', '')
invoc = os.environ.get('INVOCATION_STARTED_AT', '')
header = re.sub(r'\s+', ' ', msg)[:100]
open(sys.argv[1], 'w').write(f'{time.time()}\n{invoc}\n{header}')
" "$MARKER_FILE" 2>/dev/null || true
fi

# Save message ID to channel state so bot.js can attach buttons without orphaning them
MSG_ID=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('id',''))" "$TMPFILE" 2>/dev/null || echo "")
rm -f "$TMPFILE"
STATE_FILE=~/helm-workspace/channel-state/${CHANNEL_ID}.json
if [[ -n "$MSG_ID" ]]; then
  python3 -c "
import json, time, os, sys
f, mid = sys.argv[1], sys.argv[2]
s = json.load(open(f)) if os.path.exists(f) else {}
s['lastDiscordMsgId'] = mid
open(f,'w').write(json.dumps(s, indent=2))
" "$STATE_FILE" "$MSG_ID" 2>/dev/null || true
fi

# Write phase to channel state so bot.js skips re-posting this message from stdout.
# This closes the race where bot.js processes stdout before the Discord MESSAGE_CREATE
# event arrives back and updates lastAgentMsgPhase.
# Note: PHASE was already detected above (early phase detection).

if [[ -n "$PHASE" ]]; then
  python3 -c "
import json, time, os, sys
f, phase = sys.argv[1], sys.argv[2]
s = json.load(open(f)) if os.path.exists(f) else {}
s['lastAgentMsgPhase'] = phase
s['lastAgentMsgAt'] = int(time.time() * 1000)
if phase == 'deliver':
    s['checkpoint'] = None
open(f, 'w').write(json.dumps(s, indent=2))
" "$STATE_FILE" "$PHASE" 2>/dev/null || true
fi
