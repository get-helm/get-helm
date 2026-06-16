# HELM Recovery Implementation Status

## Architecture Discovery (Session 133, 2026-06-08)

✅ **Found complete recovery architecture on disk:**
- `~/pap-workspace/helm-specs/helm-recovery-ux-design.md` — 4-layer recovery design
- `~/pap-workspace/helm-specs/recovery-failure-chatai-feedback-2026-06-07.txt` — Post-mortem analysis
- `~/marvin-bot/helm-recovery-channels.md` — Discord channels + buttons

> ⚠️ **STALE — partially superseded (2026-06-10 audit).** Verified against bot.js source: the Discord emergency commands ARE built and live — !force-restart, !emergency-rollback, pause/resume (bot.js ~5106-5232), and recovery channel auto-create with buttons (~3185). The "NOT STARTED" entries below for those items are wrong as of Jun 10. RECOVERY-GUIDE.md is the accurate user-facing reference. Re-audit Layers 3-4 before trusting the rest of this file.

## Current Implementation Status

### Layer 1: Watchdog ✅
- Agents with no UPDATE for >30s trigger pm-agent-trigger

### Layer 2: Failover (PARTIAL ⚠️)
- ✅ VPS heartbeat detection (launchd service running)
- ✅ Mac Mini → VPS auto-failover detection (pap-failover.sh)
- ⚠️ Split-brain protection incomplete (shared state file locking not robust)
- ⚠️ Tailscale routing not fully verified

### Layer 3: Auto-Revert (NOT STARTED 🔴)
- Requires: file snapshots before git pull, validation after, revert on failure
- Design exists but not implemented

### Layer 4: Agent Resumption (NOT STARTED 🔴)
- Requires: agent resumption from checkpoint after restart
- Design exists but not implemented

### TASK-069: Process-Level Dead-Man's Switch (CRITICAL 🔴)
**Highest priority since Session 8 — every terminal-required incident traces to this gap.**

What needs to happen:
1. bot.js writes timestamp to `/tmp/helm-last-processed.txt` on every successful message
2. VPS cron every 5 min: check if timestamp >5 min old AND HC.io shows machine UP
3. If stale: `ssh mac-mini "pkill -f bot.js && npm start"` (no terminal needed)
4. Cross-check: HC.io must show machine UP (prevents false alarms on hardware failure)

Status: NOT BUILT. Blocks all terminal-free recovery until completed.

### Discord Emergency Commands (NOT STARTED 🔴)
Required:
- `!emergency-rollback` — reverts HEAD + force-restarts
- `!force-restart` — kills + restarts bot.js only
- Owner-only (checks OWNER_DISCORD_ID env var)
- Catches at lowest message handler level (even if routing is garbage)

Status: Design exists (lines 487-503 in helm-recovery-ux-design.md). Not implemented in bot.js.

### Discord Recovery Channels (NOT STARTED 🔴)
Required:
- #recovery — pinned explanation (read-only)
- #troubleshooting — emergency buttons + diagnostics
- Buttons: recover_status, recover_force, recover_manual

Status: Channels and button handlers defined (helm-recovery-channels.md). Not created.

### Pinned Rollback Command (NOT STARTED 🔴)
Required pinned message in #helm-status:
```
git -C ~/marvin-bot revert HEAD --no-edit && ~/marvin-bot/safe-restart.sh --force
```

Status: Not pinned. Should also be in 1Password as "HELM Emergency Rollback" for non-techie users.

## Build Priority Order

1. **TASK-069 — Process-level dead-man's switch** (VPS SSHes in to restart unresponsive bot.js)
   - Unblocks terminal-free recovery
   - 30 min implementation

2. **Layer 3: Auto-Revert** (validate code after git pull)
   - Prevents broken deployments
   - 45 min implementation

3. **Discord emergency commands** (!emergency-rollback, !force-restart)
   - Adds button-based rollback path
   - 20 min bot.js edit

4. **Discord recovery channels + buttons**
   - Visual recovery options for users
   - 30 min setup + testing

5. **Pinned rollback command**
   - Fallback when everything else fails
   - 5 min pin + 1Password entry

6. **Layer 4: Agent Resumption** (checkpoint-based recovery after restart)
   - Requires checkpoint persistence
   - Blocks until Layer 1-3 are solid

7. **Split-brain protection hardening** (robust locking)
   - Lower priority than terminal-free recovery
   - 20 min file-lock fix

## Next Steps

Implementing in priority order, starting with TASK-069 now.

Last updated: 2026-06-08 (session 133)
