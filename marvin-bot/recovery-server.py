#!/usr/bin/env python3
"""HELM Recovery Server — port 8080.

Serves a mobile-first recovery page at /recovery.
Auth via HELM_RECOVERY_TOKEN env var (or falls back to mission-control config.json).

Actions:
  - restart_bot: SSH-based restart via safe-restart.sh --force
  - rollback: Roll back bot.js to last good git commit + restart
  - test_ping: Confirm VPS connectivity

The page polls /api/recovery-status to show live command outcome.
"""
import os, json, time, hmac, hashlib, subprocess, threading
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

PORT = 8080
CFG_FILE = '/opt/mission-control/config.json'
LOG_FILE = '/var/log/helm-recovery.log'
STATE_FILE = '/tmp/helm-recovery-state.json'

# SSH delegation — recovery-server runs on VPS, must restart the Mac mini's HELM
MAC_SSH_KEY = os.environ.get('HELM_MAC_SSH_KEY', '/root/.ssh/vps_to_mac')
MAC_SSH_TARGET = os.environ.get('HELM_MAC_SSH_TARGET', '{{USER_SSH_HOST}}')
MAC_MARVIN_BOT = os.environ.get('HELM_MAC_MARVIN_BOT', '~/marvin-bot')
SSH_OPTS = ['-i', MAC_SSH_KEY, '-o', 'StrictHostKeyChecking=no', '-o', 'ConnectTimeout=10', '-o', 'BatchMode=yes']


def ssh_cmd(remote_cmd, timeout=120):
    """Run a command on the Mac mini via SSH. Returns CompletedProcess."""
    return subprocess.run(
        ['ssh'] + SSH_OPTS + [MAC_SSH_TARGET, remote_cmd],
        capture_output=True, text=True, timeout=timeout
    )


def load_token():
    """Load recovery password from env. Accepts HELM_RECOVERY_PASSWORD or legacy HELM_RECOVERY_TOKEN."""
    return os.environ.get('HELM_RECOVERY_PASSWORD', '') or os.environ.get('HELM_RECOVERY_TOKEN', '')


def load_user_domain():
    """Load user domain from env or config.json; defaults to '{{USER_DOMAIN}}'."""
    domain = os.environ.get('HELM_USER_DOMAIN', '')
    if domain:
        return domain
    try:
        cfg = json.load(open(CFG_FILE))
        return cfg.get('user_domain', cfg.get('domain', '{{USER_DOMAIN}}'))
    except Exception:
        return '{{USER_DOMAIN}}'


USER_DOMAIN = load_user_domain()


def log(msg):
    ts = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
    line = f'[{ts}] [recovery-server] {msg}\n'
    try:
        with open(LOG_FILE, 'a') as f:
            f.write(line)
    except Exception:
        pass


def read_state():
    try:
        return json.load(open(STATE_FILE))
    except Exception:
        return {'status': 'idle', 'action': '', 'result': '', 'updated_at': 0}


def write_state(state):
    state['updated_at'] = time.time()
    with open(STATE_FILE, 'w') as f:
        json.dump(state, f)


def fresh_heartbeat_secs():
    """Return seconds since last Mac heartbeat. Inf if file missing."""
    try:
        hb = open('/opt/pap-health/last-heartbeat.txt').read().strip()
        from datetime import datetime, timezone
        ts = datetime.fromisoformat(hb.replace('Z', '+00:00'))
        return (datetime.now(timezone.utc) - ts).total_seconds()
    except Exception:
        return float('inf')


def update_step(step, total, label, started_at):
    """Update state with current cascade step."""
    write_state({
        'status': 'running', 'action': 'auto_recover',
        'step': step, 'total': total, 'step_label': label,
        'step_started_at': time.time(), 'started_at': started_at,
        'result': ''
    })


def wait_for_heartbeat(timeout_secs=90):
    """Poll until heartbeat is fresh or timeout. Returns True on success."""
    deadline = time.time() + timeout_secs
    while time.time() < deadline:
        if fresh_heartbeat_secs() < 60:
            return True
        time.sleep(2)
    return False


def run_auto_recover():
    """7-step cascade: ping → lifeline check → restart → rollback → force-kill → network → escalation."""
    started = time.time()
    total = 7

    # Step 1: Is HELM already alive? (heartbeat check)
    update_step(1, total, 'Checking HELM connection', started)
    log('auto_recover step 1: checking heartbeat')
    if fresh_heartbeat_secs() < 60:
        write_state({'status': 'done', 'action': 'auto_recover', 'step': 1, 'total': total,
                     'result': 'ok — HELM was already alive (no action needed)'})
        return

    # Step 2: Test backup bot connection
    update_step(2, total, 'Testing backup bot connection', started)
    log('auto_recover step 2: testing lifeline connection')
    lifeline_ok = False
    try:
        import urllib.request
        r = urllib.request.urlopen(f'http://localhost:{os.environ.get("HEALTH_PORT","3001")}/health', timeout=10)
        lifeline_ok = r.status == 200
    except Exception as e:
        log(f'auto_recover step 2: lifeline health check failed: {e}')
    # Even if lifeline unreachable, continue — it just means we can't verify via that path

    # Step 3: Restart bot.js via SSH
    update_step(3, total, 'Restarting HELM', started)
    log('auto_recover step 3: SSH restart')
    r = ssh_cmd(f'bash {MAC_MARVIN_BOT}/safe-restart.sh --force', timeout=120)
    if r.returncode == 0 and wait_for_heartbeat(90):
        write_state({'status': 'done', 'action': 'auto_recover', 'step': 3, 'total': total,
                     'result': 'ok — restart succeeded (HELM heartbeat resumed)'})
        return
    log(f'auto_recover step 3: restart did not restore heartbeat (rc={r.returncode})')

    # Step 4: Rollback to last good commit + restart
    update_step(4, total, 'Rolling back to last good commit', started)
    log('auto_recover step 4: rollback')
    git_r = ssh_cmd(f'cd {MAC_MARVIN_BOT} && git log --before=yesterday --format=%H -1', timeout=30)
    prev = git_r.stdout.strip()
    if prev:
        ssh_cmd(f'cd {MAC_MARVIN_BOT} && git checkout {prev} -- bot.js', timeout=30)
        ssh_cmd(f'bash {MAC_MARVIN_BOT}/safe-restart.sh --force', timeout=120)
        if wait_for_heartbeat(120):
            write_state({'status': 'done', 'action': 'auto_recover', 'step': 4, 'total': total,
                         'result': f'ok — rollback to {prev[:8]} succeeded (HELM heartbeat resumed)'})
            return
    log('auto_recover step 4: rollback did not restore heartbeat')

    # Step 5: Force-kill zombie processes + re-launch
    update_step(5, total, 'Force-restart with cleanup', started)
    log('auto_recover step 5: force-kill zombies')
    ssh_cmd(f"pkill -f 'node bot.js' || true", timeout=15)
    time.sleep(3)
    launch_r = ssh_cmd(
        f'cd {MAC_MARVIN_BOT} && nohup node bot.js >> ~/helm-workspace/system/marvin.log 2>&1 &',
        timeout=30
    )
    if wait_for_heartbeat(90):
        write_state({'status': 'done', 'action': 'auto_recover', 'step': 5, 'total': total,
                     'result': 'ok — force-restart with cleanup succeeded'})
        return
    log('auto_recover step 5: force-kill+relaunch did not restore heartbeat')

    # Step 6: Check network/Tailscale state
    update_step(6, total, 'Checking network connection', started)
    log('auto_recover step 6: network/tailscale check')
    net_r = ssh_cmd('tailscale status --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get(\'BackendState\',\'unknown\'))" 2>/dev/null || echo "unknown"', timeout=30)
    ts_state = net_r.stdout.strip() if net_r.returncode == 0 else 'unreachable'
    log(f'auto_recover step 6: tailscale state={ts_state}')
    if ts_state not in ('Running', 'unknown', 'unreachable'):
        # Try to restart Tailscale
        ssh_cmd('sudo tailscale up 2>/dev/null || true', timeout=30)
        if wait_for_heartbeat(300):
            write_state({'status': 'done', 'action': 'auto_recover', 'step': 6, 'total': total,
                         'result': f'ok — network fix worked (Tailscale was {ts_state}; restarted)'})
            return

    # Step 7: All failed — generate escalation prompt
    update_step(7, total, 'Generating help prompt for Claude.ai', started)
    log('auto_recover step 7: escalating to Claude.ai')
    elapsed = round(time.time() - started)
    write_state({
        'status': 'done', 'action': 'auto_recover', 'step': 7, 'total': total,
        'result': f'ESCALATE: All {total-1} automatic fixes tried ({elapsed}s). Open the link below for a Claude.ai prompt that can guide you through the rest.',
        'escalation_url': f'https://status.{USER_DOMAIN}/recovery/prompt'
    })


def run_action(action):
    """Execute a recovery action in a background thread."""
    log(f'Starting action: {action}')
    write_state({'status': 'running', 'action': action, 'result': '', 'started_at': time.time()})

    try:
        if action == 'restart_bot':
            result = ssh_cmd(f'bash {MAC_MARVIN_BOT}/safe-restart.sh --force', timeout=120)
            outcome = 'ok' if result.returncode == 0 else f'failed (exit {result.returncode}: {result.stderr[:120]})'
            log(f'restart_bot result: {outcome} | stderr: {result.stderr[:200]}')
            write_state({'status': 'done', 'action': action, 'result': outcome})

        elif action == 'rollback':
            # Find last commit before today on the Mac
            git_result = ssh_cmd(f'cd {MAC_MARVIN_BOT} && git log --before=yesterday --format=%H -1', timeout=30)
            prev_commit = git_result.stdout.strip()
            if not prev_commit:
                log('rollback: no previous commit found')
                write_state({'status': 'done', 'action': action, 'result': 'no-rollback-target'})
                return
            # Checkout bot.js from that commit on Mac
            co_result = ssh_cmd(f'cd {MAC_MARVIN_BOT} && git checkout {prev_commit} -- bot.js', timeout=30)
            if co_result.returncode != 0:
                log(f'rollback checkout failed: {co_result.stderr[:200]}')
                write_state({'status': 'done', 'action': action, 'result': f'checkout-failed: {co_result.stderr[:80]}'})
                return
            # Restart on Mac
            result = ssh_cmd(f'bash {MAC_MARVIN_BOT}/safe-restart.sh --force', timeout=120)
            outcome = f'ok (rolled back to {prev_commit[:8]})' if result.returncode == 0 else f'rollback-restart-failed: {result.stderr[:80]}'
            log(f'rollback result: {outcome}')
            write_state({'status': 'done', 'action': action, 'result': outcome})

        elif action == 'test_ping':
            # Test connectivity — SSH to Mac and check heartbeat
            try:
                hb_file = '/opt/pap-health/last-heartbeat.txt'
                last_hb = open(hb_file).read().strip()
            except Exception:
                last_hb = 'unknown'
            # Verify SSH to Mac actually works
            ssh_test = ssh_cmd('echo mac-reachable', timeout=15)
            if ssh_test.returncode == 0 and 'mac-reachable' in ssh_test.stdout:
                outcome = f'ok (Mac reachable, last heartbeat: {last_hb})'
            else:
                outcome = f'WARN: Mac SSH unreachable (last heartbeat: {last_hb}, ssh err: {ssh_test.stderr[:80]})'
            log(f'test_ping: {outcome}')
            write_state({'status': 'done', 'action': action, 'result': outcome})

        elif action == 'auto_recover':
            # Cascade: test_ping → restart → rollback → escalation
            run_auto_recover()

        else:
            log(f'Unknown action: {action}')
            write_state({'status': 'done', 'action': action, 'result': 'unknown-action'})

    except Exception as e:
        log(f'Action {action} error: {e}')
        write_state({'status': 'done', 'action': action, 'result': f'error: {str(e)[:100]}'})


RECOVERY_HTML = r"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
<title>HELM Recovery</title>
<style>
* { box-sizing: border-box; margin: 0; padding: 0; }
body {
  background: #0f1117;
  color: #e8eaf0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  min-height: 100vh;
  padding: 24px 16px 40px;
  max-width: 480px;
  margin: 0 auto;
}
header { margin-bottom: 28px; }
h1 { font-size: 22px; font-weight: 700; color: #e8eaf0; margin-bottom: 4px; }
.sub { font-size: 13px; color: #7c8399; }
.btn {
  display: block;
  width: 100%;
  padding: 18px 20px;
  margin-bottom: 14px;
  border: none;
  border-radius: 14px;
  font-size: 17px;
  font-weight: 600;
  cursor: pointer;
  text-align: left;
  transition: opacity 0.15s, transform 0.1s;
  position: relative;
  overflow: hidden;
}
.btn:active { transform: scale(0.97); opacity: 0.85; }
.btn:disabled { opacity: 0.45; cursor: not-allowed; transform: none; }
.btn-icon { font-size: 22px; margin-right: 12px; vertical-align: middle; }
.btn-label { vertical-align: middle; }
.btn-desc { display: block; font-size: 12px; font-weight: 400; color: rgba(255,255,255,0.6); margin-top: 3px; margin-left: 38px; }
.btn-fix { background: #16a34a; color: #fff; padding: 22px 20px; font-size: 19px; box-shadow: 0 4px 16px rgba(22,163,74,0.3); }
.btn-fix .btn-desc { font-size: 13px; }
.btn-restart { background: #d97706; color: #fff; }
.btn-rollback { background: #7c3aed; color: #fff; }
.btn-test { background: #0ea5e9; color: #fff; }
.advanced { margin-top: 24px; }
.advanced-toggle { font-size: 13px; color: #7c8399; cursor: pointer; padding: 8px 0; user-select: none; }
.advanced-toggle:hover { color: #e8eaf0; }
.advanced-content { display: none; margin-top: 8px; }
.advanced.open .advanced-content { display: block; }
.advanced-divider { border-top: 1px solid #2e3347; margin: 16px 0; }
.status-box {
  background: #1a1d27;
  border: 1px solid #2e3347;
  border-radius: 12px;
  padding: 16px;
  margin-top: 20px;
  min-height: 80px;
}
.status-box h3 { font-size: 12px; font-weight: 600; color: #7c8399; text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 10px; }
#status-content { font-size: 15px; color: #e8eaf0; }
#status-result { font-size: 13px; color: #4ade80; margin-top: 6px; word-break: break-all; }
.spinner { display: inline-block; width: 16px; height: 16px; border: 2px solid #4a7c59; border-top-color: transparent; border-radius: 50%; animation: spin 0.7s linear infinite; vertical-align: middle; margin-right: 8px; }
@keyframes spin { to { transform: rotate(360deg); } }
.idle-msg { color: #7c8399; font-size: 14px; }
footer { margin-top: 32px; font-size: 12px; color: #4a5268; text-align: center; }
</style>
</head>
<body>
<header>
  <h1>🛡️ HELM Recovery</h1>
  <div class="sub">Emergency controls — use only when HELM is unresponsive</div>
</header>

<button class="btn btn-fix" id="btn-fix" onclick="doAction('auto_recover')">
  <span class="btn-icon">🛡️</span><span class="btn-label">Fix HELM</span>
  <span class="btn-desc">Auto-tries every recovery option until HELM is back, or guides you to Claude.ai for help</span>
</button>

<div class="advanced" id="advanced">
  <div class="advanced-toggle" onclick="document.getElementById('advanced').classList.toggle('open')">
    ▾ Advanced (individual commands)
  </div>
  <div class="advanced-content">
    <div class="advanced-divider"></div>
    <button class="btn btn-restart" id="btn-restart" onclick="doAction('restart_bot')">
      <span class="btn-icon">🔄</span><span class="btn-label">Restart Bot Only</span>
      <span class="btn-desc">SSH restart via safe-restart.sh — takes ~30s</span>
    </button>
    <button class="btn btn-rollback" id="btn-rollback" onclick="doAction('rollback')">
      <span class="btn-icon">⏪</span><span class="btn-label">Roll Back to Last Good Commit</span>
      <span class="btn-desc">Reverts bot.js to yesterday's commit and restarts — ~60s</span>
    </button>
    <button class="btn btn-test" id="btn-test" onclick="doAction('test_ping')">
      <span class="btn-icon">📡</span><span class="btn-label">Test Connection</span>
      <span class="btn-desc">Verify VPS → Mac Mini channel is alive</span>
    </button>
  </div>
</div>

<div class="status-box">
  <h3>Status</h3>
  <div id="status-content"><span class="idle-msg">No action in progress</span></div>
  <div id="status-result"></div>
</div>

<footer>HELM · recovery.__USER_DOMAIN__</footer>

<input type="hidden" id="recovery-token" value="">
<script>
// Pre-fill token from URL query param ?token=... for bookmarked links
(function() {
  var p = new URLSearchParams(window.location.search);
  var t = p.get('token') || sessionStorage.getItem('helm_recovery_token') || '';
  if (t) {
    document.getElementById('recovery-token').value = t;
    sessionStorage.setItem('helm_recovery_token', t);
  }
})();
</script>
<script>
var pollInterval = null;
var currentToken = document.querySelector('meta[name=token]') ? document.querySelector('meta[name=token]').content : '';

function setButtons(disabled) {
  ['btn-fix','btn-restart','btn-rollback','btn-test'].forEach(function(id) {
    var el = document.getElementById(id);
    if (el) el.disabled = disabled;
  });
}

function doAction(action) {
  setButtons(true);
  document.getElementById('status-content').innerHTML = '<span class="spinner"></span> Sending command…';
  document.getElementById('status-result').textContent = '';

  var label = {'restart_bot': 'Restart Bot', 'rollback': 'Roll Back', 'test_ping': 'Test Connection', 'auto_recover': 'Fix HELM'}[action] || action;

  fetch('/api/recovery-action', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Recovery-Token': document.getElementById('recovery-token').value
    },
    body: JSON.stringify({action: action})
  })
  .then(function(r) { return r.json(); })
  .then(function(data) {
    if (data.error) {
      document.getElementById('status-content').textContent = '❌ Error: ' + data.error;
      setButtons(false);
      return;
    }
    document.getElementById('status-content').innerHTML = '<span class="spinner"></span> ' + label + ' in progress…';
    startPolling();
  })
  .catch(function(e) {
    document.getElementById('status-content').textContent = '❌ Network error — ' + e.message;
    setButtons(false);
  });
}

function startPolling() {
  if (pollInterval) clearInterval(pollInterval);
  pollInterval = setInterval(pollStatus, 2000);
}

function pollStatus() {
  fetch('/api/recovery-status', {
    headers: {'X-Recovery-Token': document.getElementById('recovery-token').value}
  })
  .then(function(r) { return r.json(); })
  .then(function(data) {
    if (data.status === 'done') {
      clearInterval(pollInterval);
      pollInterval = null;
      var ok = data.result && data.result.startsWith('ok');
      var escalate = data.result && data.result.startsWith('ESCALATE');
      var icon = ok ? '✅' : (escalate ? '🆘' : '⚠️');
      var label = {'restart_bot': 'Restart Bot', 'rollback': 'Roll Back', 'test_ping': 'Test Connection', 'auto_recover': 'Fix HELM'}[data.action] || data.action;
      document.getElementById('status-content').textContent = icon + ' ' + label + ' complete';
      var resultHtml = data.result || '';
      if (escalate && data.escalation_url) {
        resultHtml = data.result + '<br><br><a href="' + data.escalation_url + '" style="display:inline-block;background:#7c3aed;color:#fff;padding:10px 16px;border-radius:8px;text-decoration:none;font-weight:600;margin-top:8px;">Open Claude.ai escalation prompt →</a>';
        document.getElementById('status-result').innerHTML = resultHtml;
      } else {
        document.getElementById('status-result').textContent = resultHtml;
      }
      setButtons(false);
    } else if (data.status === 'running') {
      var label = {'restart_bot': 'Restart Bot', 'rollback': 'Roll Back', 'test_ping': 'Test Connection', 'auto_recover': 'Fix HELM'}[data.action] || data.action;
      var stepInfo = (data.step && data.total) ? ' Step ' + data.step + '/' + data.total + ': ' + (data.step_label || '...') : '';
      document.getElementById('status-content').innerHTML = '<span class="spinner"></span> ' + label + stepInfo;
    }
  })
  .catch(function() {});
}

// Auto-clear idle state on load
fetch('/api/recovery-status', {
  headers: {'X-Recovery-Token': document.getElementById('recovery-token').value}
})
.then(function(r) { return r.json(); })
.then(function(data) {
  if (data.status === 'running') {
    startPolling();
    setButtons(true);
  }
})
.catch(function() {});
</script>
</body>
</html>"""


PROMPT_HTML = r"""<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>HELM Escalation Prompt</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{background:#0f1117;color:#e8eaf0;font-family:-apple-system,BlinkMacSystemFont,sans-serif;padding:24px 16px;max-width:560px;margin:0 auto}
h1{font-size:22px;margin-bottom:12px}
.sub{font-size:13px;color:#7c8399;margin-bottom:20px}
.box{background:#1a1d27;border:1px solid #2e3347;border-radius:10px;padding:16px;margin-bottom:16px}
.box h3{font-size:13px;color:#7c8399;text-transform:uppercase;letter-spacing:.05em;margin-bottom:10px}
pre{font-family:'SF Mono',Menlo,monospace;font-size:12px;color:#cbd5e1;white-space:pre-wrap;word-break:break-word;background:#0a0c12;padding:12px;border-radius:8px;border:1px solid #2e3347}
.btn{display:block;width:100%;padding:14px;background:#4A7C59;color:#fff;border:none;border-radius:10px;font-size:16px;font-weight:600;cursor:pointer;margin-bottom:10px}
.btn:active{transform:scale(.97)}
.btn-link{background:#0ea5e9}
a{color:#60a5fa}
.steps{font-size:14px;line-height:1.6}
.steps li{margin-bottom:6px}
</style></head><body>
<h1>🆘 HELM Escalation Prompt</h1>
<div class="sub">All automatic recovery failed. Follow these steps to get guided help from Claude.</div>

<div class="box">
<h3>Step 1 — Copy this prompt</h3>
<pre id="prompt">My HELM (Personal Automation Platform) is fully unresponsive.
Status webpage: https://status.__USER_DOMAIN__/
Recovery webpage: https://status.__USER_DOMAIN__/recovery
Automatic recovery cascade ran and failed all steps (test_ping, restart, rollback).

Things I have already tried via the recovery webpage:
- Clicked "Fix HELM" (auto-recovery cascade) — failed
- Clicked Restart Bot individually — failed
- Clicked Roll Back — failed

My environment:
- Mac mini (running HELM bot.js via launchd)
- VPS (status.__USER_DOMAIN__, runs recovery server + lifeline-bot)
- Discord (HELM main bot + Lifeline backup bot)

What I need from you:
1. Walk me through diagnosing whether the Mac mini is online (Tailscale ping, SSH).
2. If Mac is offline, give me the exact steps to physically restart it.
3. If Mac is online but bot won't restart, tell me what logs to read and how.
4. Plain English, one step at a time. Wait for me to confirm each step before moving on.</pre>
<button class="btn" onclick="copyPrompt()">📋 Copy prompt to clipboard</button>
</div>

<div class="box">
<h3>Step 2 — Open Claude.ai</h3>
<a href="https://claude.ai/chats" target="_blank" class="btn btn-link" style="text-decoration:none;text-align:center">Open Claude.ai →</a>
</div>

<div class="box">
<h3>Step 3 — Paste and send</h3>
<div class="steps">
<ol>
  <li>In Claude.ai, start a new chat</li>
  <li>Paste the copied prompt</li>
  <li>Hit send — Claude will guide you through recovery</li>
</ol>
</div>
</div>

<div class="box" style="border-color:#7c3aed">
<h3>While you wait, try these manual recovery options:</h3>
<div class="steps">
<ol>
  <li><strong>Power-cycle the Mac:</strong> Hold power button 5s, release, then press to turn back on. HELM auto-starts on boot.</li>
  <li><strong>Check the status page:</strong> <a href="/">/</a> — shows whether the Mac is reachable</li>
  <li><strong>Try the recovery webpage again:</strong> <a href="/recovery">/recovery</a> — sometimes a second try works after Mac reboots</li>
</ol>
</div>
</div>

<script>
function copyPrompt(){
  var t=document.getElementById('prompt').textContent;
  navigator.clipboard.writeText(t).then(function(){
    var b=document.querySelector('.btn');
    b.textContent='✅ Copied!';setTimeout(function(){b.textContent='📋 Copy prompt to clipboard'},2000);
  });
}
</script>
</body></html>"""


TOKEN_PROMPT_HTML = r"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
<title>HELM Recovery — Auth</title>
<style>
* { box-sizing: border-box; margin: 0; padding: 0; }
body { background: #0f1117; color: #e8eaf0; font-family: -apple-system, BlinkMacSystemFont, sans-serif;
  display: flex; align-items: center; justify-content: center; min-height: 100vh; padding: 20px; }
.card { background: #1a1d27; border: 1px solid #2e3347; border-radius: 16px; padding: 32px;
  width: 100%; max-width: 360px; }
h2 { font-size: 20px; font-weight: 700; margin-bottom: 8px; }
.sub { font-size: 13px; color: #7c8399; margin-bottom: 24px; }
input[type=text], input[type=password] { width: 100%; padding: 13px 14px; background: #0f1117; border: 1px solid #2e3347;
  border-radius: 10px; color: #e8eaf0; font-size: 16px; outline: none; margin-bottom: 14px; }
input:focus { border-color: #4A7C59; }
button { width: 100%; padding: 13px; background: #4A7C59; color: #fff; border: none;
  border-radius: 10px; font-size: 16px; font-weight: 600; cursor: pointer; }
.err { color: #ef4444; font-size: 13px; margin-bottom: 12px; }
.hint { font-size: 12px; color: #7c8399; margin-top: 12px; text-align: center; }
</style>
</head>
<body>
<div class="card">
  <h2>🛡️ HELM Recovery</h2>
  <div class="sub">Enter your __USER_DOMAIN__ password to continue</div>
  REPLACE_ERROR
  <form onsubmit="go(event)" autocomplete="on">
    <input type="password" id="password" name="password" placeholder="Site password" autocomplete="current-password" autofocus>
    <button type="submit">Unlock</button>
  </form>
  <div class="hint">1Password: search "<strong>__USER_DOMAIN__ Site Auth</strong>"</div>
</div>
<script>
function go(e) {
  e.preventDefault();
  var t = document.getElementById('password').value.trim();
  if (!t) return;
  sessionStorage.setItem('helm_recovery_token', t);
  window.location.href = '/recovery?token=' + encodeURIComponent(t);
}
// Auto-try if token already in session
var existing = sessionStorage.getItem('helm_recovery_token');
if (existing) window.location.href = '/recovery?token=' + encodeURIComponent(existing);
</script>
</body>
</html>"""


class Handler(BaseHTTPRequestHandler):
    def get_token(self):
        """Extract token from header or query param."""
        tok = self.headers.get('X-Recovery-Token', '')
        if not tok:
            parsed = urlparse(self.path)
            qs = parse_qs(parsed.query)
            tok = qs.get('token', [''])[0]
        return tok

    def token_valid(self):
        expected = load_token()
        if not expected:
            return True  # no token configured = open (warn in logs)
        provided = self.get_token()
        return hmac.compare_digest(provided.encode(), expected.encode())

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path

        if path in ('/', '/recovery', '/recovery/'):
            if not self.token_valid():
                # Show auth prompt
                html = TOKEN_PROMPT_HTML.replace('REPLACE_ERROR', '')
                self._html(200, html)
                return
            self._html(200, RECOVERY_HTML)

        elif path == '/api/recovery-status':
            if not self.token_valid():
                self._json(403, {'error': 'forbidden'})
                return
            state = read_state()
            self._json(200, state)

        elif path == '/health':
            self._json(200, {'ok': True, 'ts': time.time(), 'service': 'helm-recovery'})

        elif path in ('/recovery/prompt', '/recovery/prompt/'):
            # No auth — must be reachable when HELM/Discord/auth-tier is broken
            self._html(200, PROMPT_HTML)

        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        parsed = urlparse(self.path)
        path = parsed.path

        if path == '/api/recovery-action':
            if not self.token_valid():
                self._json(403, {'error': 'forbidden'})
                return

            length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(length)
            try:
                data = json.loads(body)
                action = data.get('action', '')
            except Exception:
                action = ''

            if action not in ('restart_bot', 'rollback', 'test_ping', 'auto_recover'):
                self._json(400, {'error': f'invalid action: {action}'})
                return

            # Check if an action is already running
            state = read_state()
            if state.get('status') == 'running':
                elapsed = time.time() - state.get('started_at', 0)
                if elapsed < 180:  # within 3 min, block duplicate
                    self._json(409, {'error': 'action already in progress'})
                    return

            log(f'Action requested: {action}')
            threading.Thread(target=run_action, args=(action,), daemon=True).start()
            self._json(200, {'ok': True, 'action': action})

        else:
            self.send_response(404)
            self.end_headers()

    def _json(self, code, data):
        body = json.dumps(data).encode()
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(body)

    def _html(self, code, html):
        body = html.replace('__USER_DOMAIN__', USER_DOMAIN).encode()
        self.send_response(code)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        log(fmt % args)


if __name__ == '__main__':
    log(f'HELM Recovery Server starting on port {PORT}')
    token = load_token()
    if not token:
        log('WARNING: No HELM_RECOVERY_PASSWORD set — server is unprotected!')
    else:
        log(f'Auth token loaded ({USER_DOMAIN} Site Auth password)')
    server = HTTPServer(('127.0.0.1', PORT), Handler)
    log(f'Listening on 127.0.0.1:{PORT}')
    server.serve_forever()
