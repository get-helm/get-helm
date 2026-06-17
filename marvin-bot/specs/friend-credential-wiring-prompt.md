# HELM Credential Reader — Complete Wiring Prompt
# Paste this entire block into your Claude Code terminal.
# This wires password manager reading into HELM end-to-end — no caveats, no missing pieces.

## STEP 1 — Detect your paths

```bash
echo "Bot dir: $(ls ~/helm/marvin-bot/bot.js 2>/dev/null && echo ~/helm/marvin-bot || echo 'NOT FOUND')"
echo "Workspace: $(ls ~/helm-workspace/CLAUDE.md 2>/dev/null && echo ~/helm-workspace || echo 'NOT FOUND')"
echo "PWMGR_TYPE: $(grep PWMGR_TYPE ~/helm/marvin-bot/.env 2>/dev/null || echo 'not set')"
echo "PWMGR_TOKEN: $(grep -c PWMGR_TOKEN ~/helm/marvin-bot/.env 2>/dev/null && echo 'set' || echo 'not set')"
```

If bot dir shows NOT FOUND, replace `~/helm/marvin-bot` in all commands below with the correct path.

---

## STEP 2 — Create the credential reader script

```bash
cat > ~/helm/marvin-bot/read-user-credential.sh << 'SCRIPT'
#!/usr/bin/env bash
# read-user-credential.sh — Read a credential from the user's HELM password manager vault.
# Usage: read-user-credential.sh "Item Name" [field]
# Returns: credential value on stdout, or exits 1 with error on stderr

set -euo pipefail

ITEM="${1:-}"
FIELD="${2:-password}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

if [[ -z "$ITEM" ]]; then
  echo "Usage: $0 'Item Name' [field]" >&2
  exit 1
fi

if [[ -f "$ENV_FILE" ]]; then
  set -a; source "$ENV_FILE"; set +a
fi

PWMGR="${PWMGR_TYPE:-}"

case "$PWMGR" in
  1password|1p|op)
    if ! command -v op &>/dev/null; then
      echo "ERROR: 1Password CLI (op) not installed." >&2
      echo "Install from: https://developer.1password.com/docs/cli/get-started/" >&2
      exit 1
    fi
    VAULT_NAME="${PWMGR_VAULT:-HELM}"
    op item get "$ITEM" --vault "$VAULT_NAME" --fields "$FIELD" --reveal 2>/dev/null || {
      echo "ERROR: Could not read '$ITEM' from 1Password vault '$VAULT_NAME'." >&2
      echo "Check: op item list --vault '$VAULT_NAME'" >&2
      exit 1
    }
    ;;
  bitwarden|bw)
    if ! command -v bw &>/dev/null; then
      echo "ERROR: Bitwarden CLI (bw) not installed." >&2
      echo "Install: npm install -g @bitwarden/cli" >&2
      exit 1
    fi
    TOKEN="${PWMGR_TOKEN:-}"
    if [[ -z "$TOKEN" ]]; then
      echo "ERROR: PWMGR_TOKEN not set in .env." >&2
      exit 1
    fi
    BWS_ACCESS_TOKEN="$TOKEN" bw get password "$ITEM" 2>/dev/null || {
      echo "ERROR: Could not read '$ITEM' from Bitwarden." >&2
      echo "List items: BWS_ACCESS_TOKEN='$TOKEN' bw list items | python3 -c \"import sys,json;[print(i['name']) for i in json.load(sys.stdin)]\"" >&2
      exit 1
    }
    ;;
  keepass|keepassxc|kdbx)
    if ! command -v keepassxc-cli &>/dev/null; then
      echo "ERROR: KeePassXC CLI not installed. Install KeePassXC desktop app." >&2
      exit 1
    fi
    KDBX="${PWMGR_KDBX_PATH:-$HOME/HELM.kdbx}"
    KDBX_PASS="${PWMGR_TOKEN:-}"
    if [[ ! -f "$KDBX" ]]; then
      echo "ERROR: KeePass database not found at $KDBX" >&2
      echo "Set PWMGR_KDBX_PATH in .env to point to your HELM.kdbx file." >&2
      exit 1
    fi
    if [[ -z "$KDBX_PASS" ]]; then
      echo "ERROR: PWMGR_TOKEN not set to KeePass database password in .env." >&2
      exit 1
    fi
    echo "$KDBX_PASS" | keepassxc-cli show -s "$KDBX" "$ITEM" -a Password 2>/dev/null || {
      echo "ERROR: Could not read '$ITEM' from KeePass at $KDBX." >&2
      exit 1
    }
    ;;
  env|envvar)
    VAR_NAME="HELM_CRED_$(echo "$ITEM" | tr ' a-z-' '_A-Z_' | tr -cd 'A-Z0-9_')"
    VAL="${!VAR_NAME:-}"
    if [[ -z "$VAL" ]]; then
      echo "ERROR: Env var $VAR_NAME not set in .env." >&2
      exit 1
    fi
    echo "$VAL"
    ;;
  "")
    echo "ERROR: PWMGR_TYPE not configured in .env" >&2
    echo "Add one of these to ~/helm/marvin-bot/.env:" >&2
    echo "  PWMGR_TYPE=1password" >&2
    echo "  PWMGR_TYPE=bitwarden" >&2
    echo "  PWMGR_TYPE=keepass" >&2
    echo "  PWMGR_TYPE=env" >&2
    exit 1
    ;;
  *)
    echo "ERROR: Unknown PWMGR_TYPE='$PWMGR'. Supported: 1password, bitwarden, keepass, env" >&2
    exit 1
    ;;
esac
SCRIPT

chmod +x ~/helm/marvin-bot/read-user-credential.sh

# Verify
echo "--- Script created:"
ls -la ~/helm/marvin-bot/read-user-credential.sh
echo "--- First line:"
head -1 ~/helm/marvin-bot/read-user-credential.sh
```

---

## STEP 3 — Configure your password manager in .env

**Run the block that matches your password manager:**

### 3A — 1Password
```bash
# You need: 1Password desktop app + CLI (op) + a vault named "HELM"
# Create vault: 1Password app → File → New Vault → name it "HELM"
# Install CLI: https://developer.1password.com/docs/cli/get-started/

echo "PWMGR_TYPE=1password" >> ~/helm/marvin-bot/.env
echo "PWMGR_VAULT=HELM" >> ~/helm/marvin-bot/.env

# Verify op is installed and signed in:
op account list 2>/dev/null || echo "NEED: Run 'op signin' first"
```

### 3B — Bitwarden
```bash
# You need: Bitwarden account + an Organization (free) named "HELM" with a Collection "HELM"
# Get API key: vault.bitwarden.com → Organizations → HELM → Settings → API Key
# Copy the client_secret value

echo "PWMGR_TYPE=bitwarden" >> ~/helm/marvin-bot/.env
echo "PWMGR_TOKEN=PASTE_YOUR_CLIENT_SECRET_HERE" >> ~/helm/marvin-bot/.env

# Install Bitwarden CLI if needed:
command -v bw || npm install -g @bitwarden/cli
```

### 3C — KeePassXC
```bash
# You need: KeePassXC desktop app + a database file HELM.kdbx
# Create it: KeePassXC → Database → New Database → save as ~/HELM.kdbx
# Use a strong unique password for this database (different from your main KeePass)

echo "PWMGR_TYPE=keepass" >> ~/helm/marvin-bot/.env
echo "PWMGR_TOKEN=YOUR_HELM_KDBX_PASSWORD" >> ~/helm/marvin-bot/.env
echo "PWMGR_KDBX_PATH=$HOME/HELM.kdbx" >> ~/helm/marvin-bot/.env
```

### 3D — Any other manager (env vars)
```bash
# Store credentials directly in .env as HELM_CRED_<NAME> vars
# Example: credential named "Gmail Password" → HELM_CRED_GMAIL_PASSWORD
echo "PWMGR_TYPE=env" >> ~/helm/marvin-bot/.env
# Then add your credentials:
# echo "HELM_CRED_GMAIL_PASSWORD=your_app_password_here" >> ~/helm/marvin-bot/.env
```

---

## STEP 4 — Add a test credential to your vault (to verify it works)

**For 1Password:**
```bash
# Create a test item in your HELM vault:
op item create --vault HELM --category login --title "HELM Test" --generate-password
# Verify you can read it:
bash ~/helm/marvin-bot/read-user-credential.sh "HELM Test"
```

**For Bitwarden:**
```bash
# Add a test item via the Bitwarden web vault or app to your HELM collection
# Name it "HELM Test", set any password value
# Then verify:
bash ~/helm/marvin-bot/read-user-credential.sh "HELM Test"
```

**For KeePassXC:**
```bash
# Open HELM.kdbx in KeePassXC → Add Entry → Title: "HELM Test", Password: any value → Save
# Verify:
bash ~/helm/marvin-bot/read-user-credential.sh "HELM Test"
```

Expected output: the password value you set (or an auto-generated one).
If you see an error instead, fix the error before continuing.

---

## STEP 5 — Teach HELM agents to use the credential reader

```bash
# This adds the credential reading instructions to your HELM workspace
# so every spawned agent knows how to retrieve credentials

cat >> ~/helm-workspace/CLAUDE.md << 'CLAUDE_END'

## Reading User Credentials (mandatory — never hardcode secrets)

To read a credential from the user's password manager HELM vault:
```bash
bash ~/helm/marvin-bot/read-user-credential.sh "Item Name"
bash ~/helm/marvin-bot/read-user-credential.sh "Item Name" fieldname
```

Supported managers (configured via PWMGR_TYPE in .env):
- `1password` — reads from 1Password HELM vault via op CLI
- `bitwarden` — reads from Bitwarden HELM collection via bw CLI
- `keepass` — reads from HELM.kdbx via keepassxc-cli
- `env` — reads HELM_CRED_<NAME> vars from .env

Rules:
- Never hardcode credentials in code, CLAUDE.md, or chat messages
- Always use this script; if it fails → BLOCK (do not fallback to hardcoding)
- Log every credential use to helm-audit
CLAUDE_END

echo "--- CLAUDE.md updated. Last 12 lines:"
tail -12 ~/helm-workspace/CLAUDE.md
```

---

## STEP 6 — Restart bot with the new capabilities

```bash
pkill -f "node.*bot.js" 2>/dev/null
sleep 2
cd ~/helm/marvin-bot && node bot.js >> ~/helm-workspace/system/marvin.log 2>&1 &
echo "Bot PID: $!"
sleep 5
pgrep -fl "node.*bot.js" && echo "BOT RUNNING ✓" || { echo "BOT FAILED"; tail -20 ~/helm-workspace/system/marvin.log; }
```

---

## STEP 7 — Full verification

```bash
echo "=== PWMGR config ==="
grep "PWMGR" ~/helm/marvin-bot/.env | sed 's/TOKEN=.*/TOKEN=****/' 

echo "=== Script present and executable ==="
ls -la ~/helm/marvin-bot/read-user-credential.sh

echo "=== CLAUDE.md has credential section ==="
grep -c "read-user-credential" ~/helm-workspace/CLAUDE.md && echo "WIRED ✓" || echo "MISSING — re-run Step 5"

echo "=== Bot running ==="
pgrep -fl "node.*bot.js" && echo "RUNNING ✓" || echo "NOT RUNNING"

echo "=== Test credential read ==="
bash ~/helm/marvin-bot/read-user-credential.sh "HELM Test" 2>&1 | head -3
```

All four checks should show ✓ or a credential value. If any fail, the error message tells you exactly what to fix.

---

## STEP 8 — Storing real credentials for agents to use

Once the wiring is verified, add real credentials to your HELM vault. Examples:

**Gmail app password** (so HELM can send/read email):
- Go to myaccount.google.com → Security → App passwords → create one named "HELM"
- Store in vault with the name "Gmail App Password"
- Agents can read it: `bash ~/helm/marvin-bot/read-user-credential.sh "Gmail App Password"`

**Google Calendar API key** (if using API mode instead of connector):
- Store in vault as "Google Calendar API Key"

**Any other service HELM needs to access**:
- Store in vault with a clear name
- HELM agents will call `read-user-credential.sh "Name"` when they need it

The vault is the source of truth. No credential ever goes into code or chat.
