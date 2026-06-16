#!/usr/bin/env bash
# install.sh — HELM bootstrap entry point
# Usage: curl -fsSL https://raw.githubusercontent.com/get-helm/get-helm/main/install.sh | bash
#   OR:  bash install.sh
#
# Detects OS, installs prerequisites, clones/updates the HELM repo to ~/helm,
# runs npm install, then shows the Claude Desktop Code tab → Local install prompt URL.

set -euo pipefail

HELM_REPO="https://github.com/get-helm/get-helm.git"
HELM_HOME="${HOME}/helm"
NODE_MIN_MAJOR=18
GIT_MIN_MINOR=30   # git >= 2.30

# ─── Banner ──────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║           HELM — Personal Automation Platform        ║"
echo "║                     Installer                        ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "This installer will:"
echo "  1. Detect your OS and install prerequisites (Node.js, git)"
echo "  2. Clone or update the HELM repo to ~/helm"
echo "  3. Install npm dependencies"
echo "  4. Create ~/helm-workspace"
echo "  5. Run the HELM onboarding wizard"
echo ""

# ─── OS Detection ────────────────────────────────────────────────────────────
detect_os() {
  local uname_out
  uname_out="$(uname -s)"
  case "$uname_out" in
    Darwin)
      echo "macos"
      ;;
    Linux)
      # Detect WSL2
      if grep -qi "microsoft" /proc/version 2>/dev/null || \
         grep -qi "wsl" /proc/version 2>/dev/null; then
        echo "wsl2"
      elif [ -f /etc/os-release ]; then
        local distro
        distro=$(grep -i '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"' | tr '[:upper:]' '[:lower:]')
        case "$distro" in
          ubuntu|debian|linuxmint|pop|elementary)
            echo "debian"
            ;;
          *)
            echo "linux-other"
            ;;
        esac
      else
        echo "linux-other"
      fi
      ;;
    *)
      echo "unsupported"
      ;;
  esac
}

OS="$(detect_os)"
echo "Detected OS: ${OS}"
echo ""

# ─── Prerequisites Install ────────────────────────────────────────────────────
install_prerequisites_macos() {
  echo "Installing prerequisites for macOS..."

  # Install Homebrew if missing
  if ! command -v brew &>/dev/null; then
    echo "  Homebrew not found — installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add brew to PATH for this session (Apple Silicon path)
    if [ -f /opt/homebrew/bin/brew ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -f /usr/local/bin/brew ]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
    echo "  Homebrew installed"
  else
    echo "  Homebrew already installed"
  fi

  # Install node and git via brew (idempotent)
  echo "  Installing node and git via Homebrew..."
  brew install node git
  echo "  node and git installed"
}

install_prerequisites_debian() {
  echo "Installing prerequisites for Ubuntu/Debian..."
  sudo apt-get update -qq
  sudo apt-get install -y nodejs npm git
  echo "  nodejs, npm, git installed"
}

install_prerequisites_wsl2() {
  echo "Installing prerequisites for WSL2..."

  # Check for systemd in wsl.conf
  if [ -f /etc/wsl.conf ]; then
    if ! grep -q "systemd=true" /etc/wsl.conf; then
      echo ""
      echo "WARNING: systemd is not enabled in /etc/wsl.conf"
      echo "  For best results, add the following to /etc/wsl.conf:"
      echo "    [boot]"
      echo "    systemd=true"
      echo "  Then restart WSL: wsl --shutdown (in PowerShell), then reopen."
      echo ""
    fi
  else
    echo ""
    echo "WARNING: /etc/wsl.conf not found — systemd may not be enabled."
    echo "  For best results, create /etc/wsl.conf with:"
    echo "    [boot]"
    echo "    systemd=true"
    echo ""
  fi

  sudo apt-get update -qq
  sudo apt-get install -y nodejs npm git
  echo "  nodejs, npm, git installed"
}

install_prerequisites_linux_other() {
  echo "WARNING: Unrecognized Linux distribution."
  echo "  Attempting installation with available package manager..."

  if command -v apt-get &>/dev/null; then
    sudo apt-get update -qq && sudo apt-get install -y nodejs npm git
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y nodejs npm git
  elif command -v yum &>/dev/null; then
    sudo yum install -y nodejs npm git
  else
    echo "ERROR: No supported package manager found (apt/dnf/yum)."
    echo "  Please install Node.js >= ${NODE_MIN_MAJOR} and git >= 2.${GIT_MIN_MINOR} manually."
    exit 1
  fi
}

case "$OS" in
  macos)         install_prerequisites_macos ;;
  debian)        install_prerequisites_debian ;;
  wsl2)          install_prerequisites_wsl2 ;;
  linux-other)   install_prerequisites_linux_other ;;
  unsupported)
    echo "ERROR: Unsupported operating system: $(uname -s)"
    echo "  HELM supports macOS, Ubuntu/Debian, and WSL2."
    exit 1
    ;;
esac
echo ""

# ─── Version Checks ───────────────────────────────────────────────────────────
echo "Checking versions..."

# Node.js >= 18
if ! command -v node &>/dev/null; then
  echo "ERROR: node not found after installation. Check your PATH."
  exit 1
fi
NODE_VERSION="$(node --version)"          # e.g. v20.11.0
NODE_MAJOR="$(echo "$NODE_VERSION" | tr -d 'v' | cut -d. -f1)"
if [ "$NODE_MAJOR" -lt "$NODE_MIN_MAJOR" ]; then
  echo "ERROR: Node.js ${NODE_VERSION} is too old. Need >= v${NODE_MIN_MAJOR}."
  echo "  Visit https://nodejs.org or use nvm: https://github.com/nvm-sh/nvm"
  exit 1
fi
echo "  Node.js ${NODE_VERSION} — OK"

# git >= 2.30
if ! command -v git &>/dev/null; then
  echo "ERROR: git not found after installation. Check your PATH."
  exit 1
fi
GIT_VERSION="$(git --version | awk '{print $3}')"   # e.g. 2.39.2
GIT_MINOR="$(echo "$GIT_VERSION" | cut -d. -f2)"
if [ "$(echo "$GIT_VERSION" | cut -d. -f1)" -lt 2 ] || \
   { [ "$(echo "$GIT_VERSION" | cut -d. -f1)" -eq 2 ] && [ "$GIT_MINOR" -lt "$GIT_MIN_MINOR" ]; }; then
  echo "ERROR: git ${GIT_VERSION} is too old. Need >= 2.${GIT_MIN_MINOR}."
  exit 1
fi
echo "  git ${GIT_VERSION} — OK"
echo ""

# ─── Clone or Update HELM Repo ────────────────────────────────────────────────
echo "Setting up HELM repo at ${HELM_HOME}..."
if [ -d "$HELM_HOME" ]; then
  echo "  Repo already exists — pulling latest changes..."
  git -C "$HELM_HOME" pull --ff-only
  echo "  Updated"
else
  echo "  Cloning HELM repo..."
  git clone "$HELM_REPO" "$HELM_HOME"
  echo "  Cloned to ${HELM_HOME}"
fi
echo ""

# ─── npm install ──────────────────────────────────────────────────────────────
echo "Installing npm dependencies..."
if [ -f "$HELM_HOME/marvin-bot/package.json" ]; then
  npm install --prefix "$HELM_HOME/marvin-bot" --quiet
  echo "  Dependencies installed"
elif [ -f "$HELM_HOME/package.json" ]; then
  npm install --prefix "$HELM_HOME" --quiet
  echo "  Dependencies installed"
else
  echo "  Dependencies will be installed by Claude Desktop during setup (no package.json in repo)"
fi
echo ""

# ─── HELM_HOME env var ────────────────────────────────────────────────────────
echo "Setting HELM_HOME environment variable..."
EXPORT_LINE="export HELM_HOME=\"${HOME}/helm\""

for RC_FILE in "${HOME}/.zshrc" "${HOME}/.bashrc"; do
  if [ -f "$RC_FILE" ]; then
    if grep -qF 'HELM_HOME' "$RC_FILE"; then
      echo "  HELM_HOME already set in ${RC_FILE} — skipping"
    else
      echo "" >> "$RC_FILE"
      echo "# HELM" >> "$RC_FILE"
      echo "$EXPORT_LINE" >> "$RC_FILE"
      echo "  Added HELM_HOME to ${RC_FILE}"
    fi
  fi
done
# Export for current session
export HELM_HOME="${HOME}/helm"
echo ""

# ─── Create helm-workspace ────────────────────────────────────────────────────
echo "Creating ~/helm-workspace..."
if [ ! -d "${HOME}/helm-workspace" ]; then
  mkdir -p "${HOME}/helm-workspace"
  echo "  Created ~/helm-workspace"
else
  echo "  ~/helm-workspace already exists"
fi
echo ""

# ─── Run onboarding wizard ────────────────────────────────────────────────────
# HELM_SKIP_WIZARD=1 exits here without launching wizard (used by smoke tests)
if [ "${HELM_SKIP_WIZARD:-0}" = "1" ]; then
  echo "HELM_SKIP_WIZARD=1 — skipping wizard (smoke test mode)"
  echo "SMOKE_TEST_PASS: install.sh completed without errors"
  exit 0
fi
echo ""
echo "══════════════════════════════════════════"
echo "  Dependencies ready. Next: install HELM."
echo "══════════════════════════════════════════"
echo ""
echo "Open Claude Desktop → click the 'Code' tab → switch to 'Local' mode, then paste this prompt:"
echo ""
echo "  → https://github.com/get-helm/get-helm/blob/main/specs/helm-cowork-install-prompt.md"
echo ""
echo "Copy the prompt from that page and paste it into Claude Desktop."
echo "The AI will walk you through the rest."
echo ""
echo "If you don't have Claude Desktop yet: anthropic.com/claude-desktop"
echo ""
