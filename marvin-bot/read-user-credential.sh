#!/usr/bin/env bash
# read-user-credential.sh — Read a credential from the user's HELM password manager vault.
# Usage: read-user-credential.sh "Item Name" [field]
#   Item Name: name of the credential entry in the HELM vault
#   field:     optional field to read (default: password)
# Returns: credential value on stdout, or exits 1 with error message on stderr
# Requires: PWMGR_TYPE in .env (1password | bitwarden | keepass | env)

set -euo pipefail

ITEM="${1:-}"
FIELD="${2:-password}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

if [[ -z "$ITEM" ]]; then
  echo "Usage: $0 'Item Name' [field]" >&2
  echo "Example: $0 'Gmail App Password' password" >&2
  exit 1
fi

# Load .env
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
      echo "ERROR: PWMGR_TOKEN not set in .env for Bitwarden." >&2
      echo "Set PWMGR_TOKEN=<your-api-client-secret> in ~/helm/marvin-bot/.env" >&2
      exit 1
    fi
    # Try BWS (Secrets Manager) first, fall back to personal vault via session
    if BW_RESULT=$(BWS_ACCESS_TOKEN="$TOKEN" bw get password "$ITEM" 2>/dev/null); then
      echo "$BW_RESULT"
    else
      echo "ERROR: Could not read '$ITEM' from Bitwarden. Check item name and token." >&2
      echo "List available: BWS_ACCESS_TOKEN='$TOKEN' bw list items 2>/dev/null | python3 -m json.tool | grep '\"name\"'" >&2
      exit 1
    fi
    ;;

  keepass|keepassxc|kdbx)
    if ! command -v keepassxc-cli &>/dev/null; then
      echo "ERROR: KeePassXC CLI not installed." >&2
      echo "Install KeePassXC desktop app — CLI is included." >&2
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
      echo "Check entry name: echo '$KDBX_PASS' | keepassxc-cli ls '$KDBX'" >&2
      exit 1
    }
    ;;

  env|envvar)
    # Read from env var: HELM_CRED_<ITEM_UPPERCASED_SPACES_TO_UNDERSCORES>
    VAR_NAME="HELM_CRED_$(echo "$ITEM" | tr ' a-z-' '_A-Z_' | tr -cd 'A-Z0-9_')"
    VAL="${!VAR_NAME:-}"
    if [[ -z "$VAL" ]]; then
      echo "ERROR: Env var $VAR_NAME not set in .env." >&2
      echo "Add: $VAR_NAME=your_secret_here to ~/helm/marvin-bot/.env" >&2
      exit 1
    fi
    echo "$VAL"
    ;;

  "")
    echo "ERROR: PWMGR_TYPE not configured in .env" >&2
    echo "Add one of these to ~/helm/marvin-bot/.env:" >&2
    echo "  PWMGR_TYPE=1password    # 1Password with op CLI" >&2
    echo "  PWMGR_TYPE=bitwarden    # Bitwarden with bw CLI" >&2
    echo "  PWMGR_TYPE=keepass      # KeePassXC with keepassxc-cli" >&2
    echo "  PWMGR_TYPE=env          # Store as env vars in .env" >&2
    exit 1
    ;;

  *)
    echo "ERROR: Unknown PWMGR_TYPE='$PWMGR'" >&2
    echo "Supported: 1password, bitwarden, keepass, env" >&2
    exit 1
    ;;
esac
