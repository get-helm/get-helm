# HELM Auto-Recovery — Single Button Design

**Goal:** One button. Tries every recovery path automatically. Either succeeds or hands user a Claude.ai prompt to escalate. User makes ZERO triage decisions.

## The button

**Recovery webpage + Discord both show one prominent button:**

```
[ 🛡️  Fix HELM (auto-tries everything) ]
```

Below it, a small "advanced options" link expands to show individual restart/rollback/test buttons (for power users).

## Cascade logic

The auto-recovery runs this cascade. Each step has a 60-second timeout. If a step succeeds (bot heartbeat resumes), the cascade STOPS and reports success. If all steps fail, it generates a personalized Claude.ai escalation prompt.

| Step | Action | Detects fix by | Timeout |
|------|--------|----------------|---------|
| 1 | Ping `/health` on Mac | Heartbeat fresh within 60s | 10s |
| 2 | `!status` via Lifeline-bot | test_ping returns "ok" within 60s | 60s |
| 3 | Restart bot.js via recovery-server | Bot processes new message within 90s | 90s |
| 4 | Rollback bot.js to last good commit + restart | Same as 3 | 120s |
| 5 | Force-kill any zombie processes, re-launch via SSH | Same as 3 | 90s |
| 6 | Check Mac network/Tailscale state (auto-cycle Wi-Fi if down) | Mac heartbeat resumes within 5min | 300s |
| 7 | All failed → generate Claude.ai prompt | N/A | N/A |

## What happens at each step (user view)

```
Step 1/7  Checking HELM connection...          (10s)
Step 2/7  Testing backup bot connection...     (60s)
Step 3/7  Restarting HELM...                   (90s)
Step 4/7  Trying rollback...                   (120s)
Step 5/7  Force-restart with cleanup...        (90s)
Step 6/7  Checking network...                  (300s)
Step 7/7  Generating help prompt for Claude... (5s)

Total worst case: ~12 minutes from button-tap to escalation
Best case (step 1 succeeds — false alarm): 10 seconds
Median case (step 3 succeeds — bot crash): ~2 minutes
```

User sees a single live progress bar. No decisions to make. No buttons to click. No triage.

## What gets built

### 1. New endpoint: `POST /api/auto-recover` (recovery-server.py)
Runs the cascade in a background thread. State machine updates `/tmp/helm-recovery-state.json`:
```json
{
  "status": "running",
  "action": "auto_recover",
  "step": 3,
  "step_label": "Restarting HELM",
  "step_started_at": 1781387392,
  "elapsed_seconds": 45,
  "result": ""
}
```

### 2. New webpage UI element (recovery-server.py — RECOVERY_HTML)
- Big prominent button at top: "🛡️ Fix HELM (auto-tries everything)"
- Live progress: "Step 3/7: Restarting HELM... (45s elapsed)"
- On success: green checkmark + "Fixed at step 3 (restart). HELM is back."
- On full failure (step 7): "All automatic fixes failed. Open Claude.ai with this prompt → [BUTTON: Copy prompt]"

### 3. New Lifeline-bot command: `!fix`
Mirrors the webpage button via Discord. Same cascade, same updates posted as bot replies.

### 4. Health-check detection (recovery-server.py)
Each step verifies success by:
- `curl http://mac-tailscale-ip:HEALTH_PORT/health` returns 200 with fresh timestamp (<60s)
- OR: looks at `/tmp/helm-last-processed.txt` modified time

### 5. Escalation prompt generator (recovery-server.py)
On full failure, generates `/recovery/prompt?session=XYZ` URL with full context:
- What steps were tried
- What each step's output/error was
- Current system state (Mac online? VPS online? Tailscale up?)
- Personalized: includes the user's machine type, VPS IP, etc.

User opens that URL → it shows the Claude prompt → user clicks "Copy" → pastes into claude.ai → gets guided fix.

## Why this beats triage

| Triage approach (today) | Auto-recovery (proposed) |
|--|--|
| User must know which button to click | Zero decisions — click "Fix" |
| User must know !restart vs !rollback | Cascade tries both |
| If step 1 fails, user retries | Auto-advances to step 2 |
| If everything fails, user gets stuck | Auto-generates Claude prompt |
| User must wait between attempts | Built-in timing + verification |
| Discord buttons may be dead | Webpage version always works |

## Multi-user considerations

- Replace hardcoded `{{USER_DOMAIN}}` references with template variables: `{{user_domain}}`, `{{recovery_url}}`, `{{site_auth_password}}`
- Cascade logic is identical for all users
- Webpage template uses {{user_domain}} branding instead of "{{USER_DOMAIN}}"
- Each user's prompt includes their own context (hardware, VPS provider, etc.)

## Failure modes the cascade can't fix

These ALWAYS escalate to step 7 (Claude prompt):
- Mac mini physically dead
- VPS provider outage (recovery-server itself unreachable)
- Discord token revoked
- Network ISP outage

The Claude prompt is generated with this context so Claude can guide the user through the OS-level/hardware-level fix.

## Build estimate

- recovery-server.py auto-recover endpoint + cascade: ~3 hours
- recovery-server.py UI + progress streaming: ~1.5 hours
- Lifeline-bot `!fix` command: ~30 min
- Health-check verification: ~1 hour
- Escalation prompt generator: ~1 hour
- Testing under each failure mode: ~2 hours

**Total: ~9 hours of engineer time.**

## Authority level

This is **Level 4** — requires {{USER_JERRY}} approval before engineer builds.

Reasons:
- Changes the primary recovery user-flow
- Affects multi-user template (constitutional for HELM-as-product)
- Adds a new public-facing button on status.{{USER_DOMAIN}} that does powerful things

## Next step

{{USER_JERRY}} approves with `[CONFIRM]` → engineer queues spec → build over next 1-2 nights.
