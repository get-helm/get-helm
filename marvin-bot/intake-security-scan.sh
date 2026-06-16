#!/bin/bash
# Standalone security scan for HELM intake gate.
# Usage: echo "content" | ./intake-security-scan.sh
#        ./intake-security-scan.sh --file /tmp/content.txt [--author-id ID]
#
# Exit codes: 0 = clean, 1 = threat detected, 2 = warning (suspicious but not definitive)
# Stdout: JSON { threats: [], level: "clean|warn|block", details: "" }

OWNER_ID="{{USER_DISCORD_USER_ID}}"
AUTHOR_ID=""
INPUT_FILE=""
CONTENT=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --file) INPUT_FILE="$2"; shift 2 ;;
    --author-id) AUTHOR_ID="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [[ -n "$INPUT_FILE" ]]; then
  CONTENT=$(cat "$INPUT_FILE" 2>/dev/null)
elif [[ ! -t 0 ]]; then
  CONTENT=$(cat)
fi

if [[ -z "$CONTENT" ]]; then
  echo '{"threats":[],"level":"clean","details":"no content"}'
  exit 0
fi

TRUST_LEVEL="external"
if [[ "$AUTHOR_ID" == "$OWNER_ID" ]]; then
  TRUST_LEVEL="owner"
fi

THREATS=()
LEVEL="clean"
CONTENT_LOWER=$(echo "$CONTENT" | tr '[:upper:]' '[:lower:]')

# --- Prompt injection patterns ---
if echo "$CONTENT_LOWER" | grep -qE 'ignore (all |previous |the )?(previous |above |prior )?(instructions?|directives?|rules?|prompts?)'; then
  THREATS+=("prompt_injection:ignore_instructions")
  LEVEL="block"
fi

if echo "$CONTENT_LOWER" | grep -qE '(you are now|pretend (you are|to be)|act as if you are|roleplay as|from now on you (are|must|will))'; then
  THREATS+=("prompt_injection:persona_override")
  LEVEL="block"
fi

if echo "$CONTENT_LOWER" | grep -qE '(forget everything|disregard (all|your|previous)|override (your|all|the) (instructions?|settings?|rules?))'; then
  THREATS+=("prompt_injection:context_override")
  LEVEL="block"
fi

if echo "$CONTENT_LOWER" | grep -qE '(jailbreak|do anything now|dan mode|developer mode|unrestricted mode|god mode)'; then
  THREATS+=("prompt_injection:jailbreak_attempt")
  LEVEL="block"
fi

if echo "$CONTENT_LOWER" | grep -qE '(new (system )?instructions?:|revised (system )?prompt:|updated (system )?rules?:|<system>|</system>|\[system\]|\[instructions\])'; then
  THREATS+=("prompt_injection:system_prompt_spoof")
  LEVEL="block"
fi

# --- Malicious URL patterns ---
if echo "$CONTENT_LOWER" | grep -qE 'javascript:|data:text/html|vbscript:'; then
  THREATS+=("malicious_url:script_protocol")
  LEVEL="block"
fi

# --- Executable content in text ---
if echo "$CONTENT" | grep -qE '^#!/(bin|usr)/(bash|sh|zsh|python)'; then
  THREATS+=("embedded_script:shebang_detected")
  LEVEL="warn"
  [[ "$LEVEL" != "block" ]] && LEVEL="warn"
fi

if echo "$CONTENT_LOWER" | grep -qE '<script[^>]*>|eval\s*\(|document\.cookie|window\.location'; then
  THREATS+=("embedded_script:xss_pattern")
  LEVEL="block"
fi

# --- Data exfiltration patterns ---
if echo "$CONTENT_LOWER" | grep -qE '(send|exfiltrate|leak|post|forward) (all |the )?(credentials?|passwords?|api keys?|secrets?|tokens?)'; then
  THREATS+=("data_exfiltration:credential_theft_request")
  LEVEL="block"
fi

if echo "$CONTENT_LOWER" | grep -qE '(delete|rm -rf|drop (table|database)|truncate|wipe) '; then
  THREATS+=("destructive_command:deletion_pattern")
  [[ "$LEVEL" != "block" ]] && LEVEL="warn"
fi

# --- Suspicious encoding ---
if echo "$CONTENT" | grep -qE '[A-Za-z0-9+/]{40,}={0,2}' && echo "$CONTENT_LOWER" | grep -qE '(base64|decode|atob)'; then
  THREATS+=("encoding:suspicious_base64_with_decode")
  [[ "$LEVEL" != "block" ]] && LEVEL="warn"
fi

# Build JSON output
THREATS_JSON="["
for i in "${!THREATS[@]}"; do
  [[ $i -gt 0 ]] && THREATS_JSON+=","
  THREATS_JSON+="\"${THREATS[$i]}\""
done
THREATS_JSON+="]"

DETAIL=""
if [[ "${#THREATS[@]}" -gt 0 ]]; then
  DETAIL="${#THREATS[@]} threat(s) found, trust_level=${TRUST_LEVEL}"
else
  DETAIL="no threats found, trust_level=${TRUST_LEVEL}"
fi

echo "{\"threats\":${THREATS_JSON},\"level\":\"${LEVEL}\",\"trust_level\":\"${TRUST_LEVEL}\",\"details\":\"${DETAIL}\"}"

if [[ "$LEVEL" == "block" ]]; then
  exit 1
elif [[ "$LEVEL" == "warn" ]]; then
  exit 2
else
  exit 0
fi
