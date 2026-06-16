# HELM WSL2 Windows Installer
# Run from PowerShell as Administrator:
#   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
#   .\install.ps1

#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step   { param($msg) Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok     { param($msg) Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Warn   { param($msg) Write-Host "  [WARN] $msg" -ForegroundColor Yellow }
function Write-Fail   { param($msg) Write-Host "  [FAIL] $msg" -ForegroundColor Red; exit 1 }

# ─── 1. Check / install WSL2 ─────────────────────────────────────────────────
Write-Step "Checking WSL2 installation..."
$wslStatus = wsl --status 2>&1
if ($LASTEXITCODE -ne 0 -or ($wslStatus -match "not installed" -or $wslStatus -match "not found")) {
    Write-Warn "WSL2 not detected. Installing WSL2..."
    wsl --install
    Write-Warn "WSL2 installation triggered. A system restart is required."
    Write-Warn "After restarting, re-run this script to continue HELM setup."
    $restart = Read-Host "Restart now? (y/n)"
    if ($restart -eq 'y') { Restart-Computer -Force }
    exit 0
} else {
    Write-Ok "WSL2 is installed."
}

# ─── 2. Check / enable systemd in WSL2 ──────────────────────────────────────
Write-Step "Checking systemd in WSL2..."
$wslConf = wsl -e cat /etc/wsl.conf 2>&1
if ($LASTEXITCODE -ne 0 -or $wslConf -notmatch "systemd\s*=\s*true") {
    Write-Warn "systemd not enabled in /etc/wsl.conf. Writing configuration..."
    $wslConfContent = @"
[boot]
systemd=true

[automount]
enabled=true
root=/mnt/
options=""metadata,umask=22,fmask=11""

[network]
generateHosts=true
generateResolvConf=true

[interop]
enabled=true
appendWindowsPath=true
"@
    # Escape for bash here-string
    wsl -e bash -c "sudo tee /etc/wsl.conf > /dev/null << 'WSLEOF'
[boot]
systemd=true

[automount]
enabled=true
root=/mnt/
options=""metadata,umask=22,fmask=11""

[network]
generateHosts=true
generateResolvConf=true

[interop]
enabled=true
appendWindowsPath=true
WSLEOF"
    Write-Ok "wsl.conf written. Shutting down WSL2 to apply..."
    wsl --shutdown
    Start-Sleep -Seconds 3
    Write-Ok "WSL2 restarted with systemd enabled."
} else {
    Write-Ok "systemd=true already present in /etc/wsl.conf."
}

# ─── 3. Check default distro ─────────────────────────────────────────────────
Write-Step "Checking default WSL2 distro..."
$wslList = wsl --list --quiet 2>&1
$defaultDistro = ($wslList | Select-String "Ubuntu" | Select-Object -First 1)
if (-not $defaultDistro) {
    Write-Warn "Ubuntu does not appear to be the default WSL2 distro."
    Write-Warn "Current distros: $($wslList -join ', ')"
    Write-Warn "HELM is tested on Ubuntu. Other distros may work but are unsupported."
    Write-Warn "To set Ubuntu as default: wsl --set-default Ubuntu"
} else {
    Write-Ok "Ubuntu distro detected: $($defaultDistro.ToString().Trim())"
}

# ─── 4. Install Node.js 20 in WSL2 ──────────────────────────────────────────
Write-Step "Installing Node.js 20 in WSL2..."
$nodeCheck = wsl -e bash -c "node --version 2>/dev/null || echo 'not-found'" 2>&1
$nodeMajor = 0
if ($nodeCheck -match "v(\d+)\.") {
    $nodeMajor = [int]$Matches[1]
}

if ($nodeMajor -ge 18) {
    Write-Ok "Node.js $nodeCheck already installed in WSL2 (satisfies >=18)."
} else {
    Write-Warn "Node.js not found or too old ($nodeCheck). Installing Node.js 20 via NodeSource..."
    wsl -e bash -c "curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - && sudo apt-get install -y nodejs"
    $nodeVersion = wsl -e bash -c "node --version 2>/dev/null || echo 'failed'"
    if ($nodeVersion -match "v\d+") {
        Write-Ok "Node.js $nodeVersion installed in WSL2."
    } else {
        Write-Fail "Node.js installation failed. Check WSL2 internet connectivity."
    }
}

# ─── 5. Verify Windows home is accessible in WSL2 ───────────────────────────
Write-Step "Verifying Windows home mount in WSL2..."
$winUser = $env:USERNAME
$mountPath = "/mnt/c/Users/$winUser"
$mountCheck = wsl -e bash -c "test -d '$mountPath' && echo 'ok' || echo 'missing'" 2>&1
if ($mountCheck -match "ok") {
    Write-Ok "Windows home accessible at $mountPath"
} else {
    Write-Warn "Cannot find $mountPath inside WSL2. Check automount settings in /etc/wsl.conf."
}

# ─── 6. Set up helm-workspace symlink in WSL2 ───────────────────────────────
Write-Step "Setting up helm-workspace symlink in WSL2..."
wsl -e bash -c "ln -sfn /mnt/c/Users/$winUser/helm-workspace ~/helm-workspace 2>/dev/null || true"
Write-Ok "~/helm-workspace symlinked to /mnt/c/Users/$winUser/helm-workspace"

# ─── 7. Run HELM install script in WSL2 ──────────────────────────────────────
Write-Step "Running HELM install script in WSL2..."
$installScript = wsl -e bash -c "test -f ~/marvin-bot/install.sh && echo 'found' || echo 'missing'" 2>&1
if ($installScript -match "found") {
    wsl -e bash ~/marvin-bot/install.sh
    Write-Ok "HELM install script completed."
} else {
    Write-Warn "~/marvin-bot/install.sh not found in WSL2 — skipping."
    Write-Warn "Clone your HELM repo: wsl -e bash -c 'git clone <repo> ~/marvin-bot'"
}

# ─── 8. Create Task Scheduler keep-warm task ────────────────────────────────
Write-Step "Registering HELM-WSL2-KeepWarm scheduled task..."
$action = New-ScheduledTaskAction `
    -Execute "wsl.exe" `
    -Argument "-e bash -c 'pgrep -f bot.js || (cd ~/marvin-bot && node bot.js &)'"

$trigger = New-ScheduledTaskTrigger -AtLogOn

$settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
    -StartWhenAvailable

Register-ScheduledTask `
    -TaskName "HELM-WSL2-KeepWarm" `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -RunLevel Highest `
    -Force | Out-Null

Write-Ok "Scheduled task 'HELM-WSL2-KeepWarm' registered (runs at logon)."

# ─── 9. Done ─────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  HELM WSL2 setup complete. Open Discord and type in #general to begin." -ForegroundColor Green
Write-Host ""
Write-Host "  Useful next steps:" -ForegroundColor Cyan
Write-Host "    wsl                              # open WSL2 shell"
Write-Host "    systemctl status helm-bot        # check bot status"
Write-Host "    journalctl -u helm-bot -f        # follow bot logs"
Write-Host "    schtasks /query /tn HELM-WSL2-KeepWarm  # verify scheduled task"
Write-Host ""
