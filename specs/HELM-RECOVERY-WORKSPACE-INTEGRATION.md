# Recovery Integration — Mission Control Workspace

**For the mission-control workspace agent (channel 1505752160057561149).**

The mission-control dashboard at status.{{USER_DOMAIN}} is the user's primary dashboard. Recovery functionality should live INSIDE mission-control — not be a separate isolated `/recovery` URL the user has to remember.

This document is the handoff spec for mission-control to absorb recovery as a first-class dashboard feature.

---

## Why integrate

Today's split:
- `https://status.{{USER_DOMAIN}}` → mission-control dashboard (status, metrics, controls)
- `https://status.{{USER_DOMAIN}}/recovery` → separate isolated recovery page

Users have to remember the `/recovery` URL exists. When they're panicking because HELM is dead, they go to the main dashboard, see nothing useful, and don't know where to go next.

Goal: when HELM is dead, the mission-control dashboard itself shows the recovery controls front-and-center.

---

## What to integrate

### 1. Recovery card on main dashboard

Add a persistent card to the mission-control dashboard with this layout:

```
┌──────────────────────────────────────────────┐
│ 🛡️ Recovery                                  │
│                                              │
│  Status: 🟢 HELM healthy (last heartbeat 8s) │
│                                              │
│  [ 🛡️  Fix HELM (auto-tries everything) ]    │  <- big prominent button
│                                              │
│  Advanced: [Restart] [Rollback] [Test]       │  <- collapsed by default
└──────────────────────────────────────────────┘
```

**Visibility logic:**
- If HELM healthy → card collapsed, shows "🟢 HELM healthy" + small "Fix HELM" link
- If HELM silent >2 min → card EXPANDS automatically, big button visible
- If recovery action in-progress → card shows live progress bar

### 2. Recovery banner (full-width, when HELM is dead)

When the dashboard detects HELM has been silent for >2 min:
- Show a red banner at the top of the page: "⚠️ HELM not responding. Click Fix below to recover."
- Below it, the recovery card expands automatically
- Single button: "🛡️ Fix HELM"

### 3. Auth integration

Mission-control already has {{USER_DOMAIN}} password auth at the dashboard level. Recovery controls inherit this auth — no second login.

**Important:** Currently `/recovery` requires a separate token in the URL. Once integrated:
- Mission-control dashboard auth = single login for everything
- Recovery API calls (`/api/recovery-action`, `/api/recovery-status`) all use the mission-control session token
- NOTE (verified live 2026-06-15): recovery-server.py exposes ONLY these routes — GET `/recovery`, GET `/api/recovery-status`, GET `/health`, GET `/recovery/prompt`, POST `/api/recovery-action`. There is NO `/api/auto-recover`, `/api/health`, `/api/bot-heartbeat`, or `/api/recovery` endpoint. Do not build against those — they 404/405. The "Fix HELM" cascade is triggered by POST `/api/recovery-action` with body `{"action":"auto_recover"}`.
- The standalone `/recovery` URL stays live as a fallback for when the dashboard itself fails

---

## Implementation steps (for mission-control workspace agent)

### Step 1: Add recovery component to dashboard frontend

In mission-control's web UI (likely React or vanilla JS), create a `<RecoveryCard />` component that:
- Polls `/api/status` every 10 seconds when the page is open (returns JSON: `{"heartbeat":"<ISO>", ...}`). `/api/health` returns the status HTML page, not JSON — do not poll it.
- Shows status (green/yellow/red) based on `heartbeat` freshness
- On red status, expands to show the "🛡️ Fix HELM" button
- On button click, POSTs to `/api/recovery-action` with body `{"action":"auto_recover"}` and polls `/api/recovery-status` for live progress

### Step 2: Proxy recovery endpoints through mission-control

Currently the recovery-server runs on port 8080. Mission-control already proxies through nginx. Add these proxy rules to mission-control's nginx config:

```nginx
# Only these two recovery-server routes exist — proxy these, nothing else.
location /api/recovery-action {
    proxy_pass http://127.0.0.1:8080/api/recovery-action;
    proxy_set_header X-Recovery-Token "$MISSION_CONTROL_AUTH_TOKEN";
}

location /api/recovery-status {
    proxy_pass http://127.0.0.1:8080/api/recovery-status;
    proxy_set_header X-Recovery-Token "$MISSION_CONTROL_AUTH_TOKEN";
}
```

Note: the standalone `/recovery` page stays live as a fallback path. Don't remove it.

### Step 3: Health-detection logic in dashboard

The dashboard already polls bot status. Add a "HELM responding" check:
- Read the `heartbeat` field from `/api/status` (JSON). If <60s old → 🟢
- If 60s–2min old → 🟡 ("Maybe slow")
- If >2min old → 🔴 ("HELM silent — recovery available")

When status goes red, auto-expand the recovery card AND show the top banner.

### Step 4: Dashboard test

Add a test path: user clicks "Test Recovery" in dashboard settings → runs `test_ping` → confirms VPS→Mac round-trip works → green check or specific error.

This gives the user confidence the recovery system itself is healthy when nothing is broken.

---

## What does NOT change

- The standalone `https://status.{{USER_DOMAIN}}/recovery` URL stays live as a fallback. Some users may have bookmarked it.
- Lifeline-bot Discord commands (`!restart`, `!rollback`, `!status`, `!fix`) stay live in all Discord channels.
- RECOVERY-GUIDE.md stays the canonical reference.

---

## Auto-recovery design

The `🛡️ Fix HELM` button calls `/api/auto-recover` which runs a 7-step cascade:

1. Ping Mac /health (10s)
2. Lifeline-bot status (60s)
3. Restart bot.js (90s)
4. Rollback bot.js + restart (120s)
5. Force-kill zombies + re-launch (90s)
6. Network/Tailscale check + auto-cycle Wi-Fi (300s)
7. All failed → generate Claude.ai escalation prompt

Full spec: `~/helm-workspace/specs/HELM-AUTO-RECOVERY-DESIGN.md`

Mission-control just calls the endpoint and renders the live progress. The backend (recovery-server.py + lifeline-bot.js) does the work.

---

## Multi-user template variables

When mission-control workspace generalizes to other users, the recovery card uses these variables (no hardcoded "{{USER_DOMAIN}}" anywhere):

| Variable | Value | Where stored |
|---|---|---|
| `{{user_domain}}` | e.g., "{{USER_DOMAIN}}" | mission-control config |
| `{{recovery_url}}` | "status.{{user_domain}}/recovery" | derived |
| `{{site_auth_label}}` | e.g., "{{USER_DOMAIN}} password" | derived |
| `{{mission_control_url}}` | "status.{{user_domain}}" | derived |

The mission-control workspace agent should accept these as install-time inputs.

---

## Testing the integration

1. Open status.{{USER_DOMAIN}} → log in → see dashboard
2. Recovery card shows 🟢 HELM healthy
3. Run `pkill -9 -f bot.js` on the Mac (simulates HELM crash)
4. Wait 2 minutes (or trigger refresh)
5. Recovery card should auto-expand to red state
6. Click "🛡️ Fix HELM"
7. Watch live cascade progress
8. Bot returns by step 3 (launchd auto-restart already brought it back)

---

## Authority level

This is **Level 3** (user-visible behavior change but reversible). Mission-control workspace agent can implement and {{USER_JERRY}} approves visually when it's live. No bot.js changes required.

---

## Dependencies

- HELM-AUTO-RECOVERY-DESIGN.md auto-recover endpoint must exist (Level 4 — separate {{USER_JERRY}} approval, then engineer build)
- Mission-control already has auth and nginx proxying — building on existing patterns
- Lifeline-bot rename in Discord Developer Portal (cleanup task, separate from this)
