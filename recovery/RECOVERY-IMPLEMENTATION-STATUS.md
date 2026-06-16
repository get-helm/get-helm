# PAP Recovery Architecture — Implementation Status
*Last updated: 2026-05-31T[TIME]Z*

## Recovery Stack (4 Layers)

### ✅ Layer 1: Bot.js Crash Recovery
**Status: IMPLEMENTED (pre-existing launchd watchdog)**
- launchd monitors bot.js process
- Auto-restart on crash within 30 sec
- User action: None (automatic)

### ✅ Layer 2: VPS ↔ Mac Mini Failover
**Status: IMPLEMENTED 2026-05-31**
- VPS health check: Tailscale API endpoint every 30 sec
- VPS heartbeat: `/tmp/pap-failover-state.json` written every 5 sec
- Split-brain protection: Mac Mini checks state file age before starting bot
- Failover trigger: State file >60 sec old → Mac Mini auto-starts as primary
- Failback trigger: State file <10 sec old → Mac Mini auto-stops
- Workspace resumption: Triggers agent wake-up on failover
- User action: None (automatic)

**Files deployed:**
- `~/marvin-bot/pap-failover.sh` — Mac Mini monitoring loop
- `~/marvin-bot/pap-vps-heartbeat.sh` — VPS heartbeat writer
- `/Users/{{USER_HOME}}/Library/LaunchAgents/com.pap.failover.plist` — Mac Mini service (launchd)
- `/Users/{{USER_HOME}}/Library/LaunchAgents/com.pap.vps-heartbeat.plist` — VPS service (ready to deploy to VPS)

### 🔄 Layer 3: Update + Revert Mechanism
**Status: IMPLEMENTED (nightly automation, validation logic)**
- Pre-update snapshot: Git tag created before pulling updates
- Update pull: Fetches latest from pap-platform repo (or specific version if pinned)
- Post-update validation: 3-point check (syntax, file integrity, Discord connectivity)
- Auto-revert: If validation fails, rolls back to pre-update snapshot
- Restart: Bot restarts after update/revert complete
- Discord notification: Posts results to pap-audit (success) or troubleshooting (failure)
- User action: None unless revert fails (then see #troubleshooting channel)

**Files deployed:**
- `~/pap-update-safety.sh` — Complete update + validation + revert logic
- `/Users/{{USER_HOME}}/Library/LaunchAgents/com.pap.update-nightly.plist` — Nightly cron (2 AM daily)

**Configuration for users:**
- Can pin version via `PIN_UPDATE: "v2.1"` in `~/.pap-user/config.json` to freeze updates
- Default: Auto-update enabled (pulls every night)

### ✅ Layer 4: Workspace Agent Resumption
**Status: IMPLEMENTED (auto-trigger on failover/restart)**
- Agent receives system recovery notification
- Checks checkpoint file for last known work state
- Re-reads recent Discord messages
- Resumes from checkpoint (not from beginning)
- Posts UPDATE to workspace: "Resumed work on [task]"
- Trigger script: `~/pap-workspace-resume-trigger.sh` (called by failover system)
- User action: None (agents auto-resume)

---

## What's NOT Yet Built (Queue to Engineer)

### 🔸 Recovery Channel Infrastructure
- Create #recovery Discord channel (read-only system announcements)
- Create #troubleshooting Discord channel (user actions via buttons)
- Update onboarding to mention these channels
- Design & implement button handlers for recovery actions

### 🔸 Emergency Recovery Button (for multi-machine setups)
- Token-based endpoint on clean machine (for recovery from daily machine)
- Button URL generation during install
- Discord integration (user taps link → triggers recovery)
- Not critical for single-machine setup, but design exists

### 🔸 Detailed Revert Instructions for Manual Recovery
- #troubleshooting channel procedures
- Step-by-step markdown guides
- Git rollback commands (if user wants to manually revert)
- Contact escalation path (if both auto-recovery attempts fail)

### 🔸 Multi-User Recovery Isolation
- Each user's PAP instance should have independent recovery
- User A's update failure shouldn't affect User B
- Recovery channels should be per-user (or bot-isolated, TBD)

### 🔸 Recovery Service + Endpoint (for emergency scenarios)
- Clean machine runs a separate HTTP service on a high port
- Handles recovery requests from daily machine
- Restarts bot if it's dead
- Doesn't use SSH or user credentials

---

## Testing Checklist

### Layer 2 (Failover) — TEST YOURSELF
- [ ] Manually stop VPS bot: `launchctl stop com.marvin.bot` on VPS
- [ ] Verify state file becomes stale
- [ ] Verify Mac Mini auto-starts within 60 sec
- [ ] Verify system recovers (Discord reconnects, agents resume)
- [ ] Verify failback: restart VPS bot, Mac Mini auto-stops
- [ ] Check logs: `/var/log/pap-failover.log` and `/var/log/pap-vps-heartbeat.log`

### Layer 3 (Update + Revert) — TEST WITH STAGED UPDATE
- [ ] Create a test branch with a breaking change (syntax error in bot.js)
- [ ] Update git to point to test branch
- [ ] Run `~/pap-update-safety.sh` manually
- [ ] Verify validation catches the error
- [ ] Verify auto-revert to pre-update snapshot succeeds
- [ ] Verify bot restarts correctly
- [ ] Verify Discord notification posted

### Layer 4 (Workspace Resumption) — TEST WITH FAILOVER
- [ ] Start a workspace agent (e.g., etf-tracker) with active checkpoint
- [ ] Trigger failover: stop VPS bot
- [ ] Verify Mac Mini takes over
- [ ] Verify workspace agent posts resume message
- [ ] Verify agent reads checkpoint and continues work

---

## Known Limitations

1. **Split-brain window (extreme case):**
   - If VPS loses network access but keeps running (isolated), both VPS and Mac Mini might be online
   - Mitigation: State file check + timestamp makes this unlikely, but not impossible
   - Real fix: VPS must actively heartbeat (which it does via pap-vps-heartbeat.sh)

2. **Manual intervention required if:**
   - VPS AND Mac Mini both fail (both machines down)
   - Update pulls a breaking config change (not caught by syntax check)
   - Git corruption (rare, but possible)

3. **Not yet built:**
   - Emergency button for recovery from another device
   - Multi-user isolation (each user runs own bot instance per DES-005)
   - Detailed #troubleshooting channel procedures

---

## Deployment Checklist for Multi-User

When deploying this to other users' machines:

1. Deploy pap-update-safety.sh (nightly update automation)
2. Deploy pap-failover.sh + pap-workspace-resume-trigger.sh (Mac Mini only)
3. Deploy pap-vps-heartbeat.sh + its plist (VPS only)
4. Load launchd services: `launchctl load /Users/USER/Library/LaunchAgents/com.pap.*.plist`
5. Verify state file is being written: `cat /tmp/pap-failover-state.json`
6. Verify bot is running: `pgrep -f "node.*bot.js"`
7. Test failover manually before declaring operational

---

## Recovery in Practice

**Scenario 1: Bot.js crashes**
- Launchd detects crash
- Restarts bot within 30 sec
- User sees no interruption (agents auto-resume on restart)

**Scenario 2: VPS becomes unreachable**
- Mac Mini detects stale state file
- After 60 sec, auto-starts bot
- Workspace agents wake up and resume
- Discord reconnects
- User may notice 1-2 min hiccup, system recovers automatically

**Scenario 3: Update breaks PAP**
- Nightly update runs at 2 AM
- Validation fails
- Auto-revert to pre-update snapshot
- Bot restarts with old code
- Discord notification posted
- User wakes up to message: "Update failed, reverted successfully"
- No action needed

**Scenario 4: Both auto-recovery attempts fail**
- Post to #troubleshooting: "Need help - [Manual Recovery Instructions] [Contact Support]"
- User can tap button for step-by-step guide
- If still stuck: human intervention path

