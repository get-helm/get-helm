#!/bin/bash
# Install git hooks for marvin-bot repo
REPO_DIR="${1:-$HOME/marvin-bot}"
HOOKS_DIR="$REPO_DIR/.git/hooks"

cat > "$HOOKS_DIR/pre-commit" << 'HOOK'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
SECURITY_CHECK="$SCRIPT_DIR/pre-deploy-security-check.sh"
LOG_FILE="$HOME/helm-workspace/logs/pap-audit.log"
CHANGED_JS=$(git diff --cached --name-only --diff-filter=ACM | grep '\.js$')
if [[ -z "$CHANGED_JS" ]]; then exit 0; fi
echo "[pre-commit] Running security check on changed JS files..."
FAIL=0
for JS_FILE in $CHANGED_JS; do
    if [[ -f "$SCRIPT_DIR/$JS_FILE" ]]; then
        RESULT=$(bash "$SECURITY_CHECK" "$SCRIPT_DIR/$JS_FILE" 2>&1)
        if [[ $? -eq 1 ]]; then
            echo "[pre-commit] SECURITY FAIL: $JS_FILE"
            echo "$RESULT"
            FAIL=1
        fi
    fi
done
CRED_FOUND=$(git diff --cached -- "$CHANGED_JS" | grep -E '^\+[^+]' | grep -iE '(password|token|key)\s*=\s*["\x27][a-zA-Z0-9_\-]{8,}' | grep -v "https://" | grep -v "example|sample|test|placeholder" | head -5)
if [[ -n "$CRED_FOUND" ]]; then
    echo "[pre-commit] WARNING: possible hardcoded credential found"
    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "{\"ts\":\"$TIMESTAMP\",\"type\":\"security_credential_scan\",\"result\":\"WARN\",\"details\":\"possible hardcoded credential in commit\"}" >> "$LOG_FILE"
fi
[[ $FAIL -eq 1 ]] && { echo "[pre-commit] BLOCKED: fix security issues."; exit 1; }
exit 0
HOOK
chmod +x "$HOOKS_DIR/pre-commit"
echo "Hooks installed in $HOOKS_DIR"
