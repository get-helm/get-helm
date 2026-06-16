# HELM Recovery Architecture — Discord Channels Setup

## Overview
Three Discord channels support the 4-layer recovery architecture:
1. **#recovery** — Pinned explanation (read-only reference)
2. **#troubleshooting** — Emergency buttons + diagnostics
3. **#helm-status** — Recovery state in heartbeat messages

## Channel Creation Commands

```bash
# These would normally be run via Discord.js in bot.js
# For now, created manually or via Discord web UI

# #recovery — informational channel
# Create in server, name: "recovery"
# Category: (any)
# Permissions: @everyone can view and read, no send

# #troubleshooting — emergency buttons
# Create in server, name: "troubleshooting"
# Category: (same as recovery)
# Permissions: @everyone can view, send, and use buttons
```

## #recovery Pinned Message (Layer Explanation)

**Title:** HELM Recovery Architecture (4 Layers)

**Content:**
```
🛡️ **HELM Recovery Architecture**

HELM is built with 4 nested recovery layers. If something breaks, HELM recovers automatically.

**Layer 1: Watchdog** ✅ (ACTIVE)
- Detects agents that crash or timeout
- Posts recovery messages to channels
- Spawns replacement agents to resume work
- Prevents silent failures

**Layer 2: Failover** ✅ (ACTIVE)
- If Mac Mini is down, VPS automatically takes over
- Shared state synced via Tailscale
- Single Discord token = one active instance at a time
- Zero data loss on failover

**Layer 3: Auto-Revert** ✅ (DEPLOYED)
- Before pulling updates, snapshots critical files
- After git pull, validates code (syntax, imports, JSON)
- If validation fails: reverts to snapshot, restarts, posts failure notice
- Prevents broken code from deploying

**Layer 4: Agent Resumption** ✅ (DEPLOYED)
- After restart, scans for stalled agents
- Spawns pm-agent-trigger for agents with no UPDATE for >30s
- Agents auto-resume from checkpoint with context intact
- Work continues after restart without user intervention

**What Does This Mean?**
- 🟢 Normal operation: PAP works, updates deploy, agents run
- 🟡 Validation fails: Changes reverted, old code stays live, you see a notice
- 🔴 Bot.js crashes: Watchdog respawns it, agents resume, you see "recovering" message
- ⚠️ Something else breaks: Failover activates, work continues on VPS

**Questions?** See #troubleshooting for emergency commands.
```

## #troubleshooting Emergency Buttons

**Pinned message with interactive buttons:**

```
🚨 **Emergency Recovery Options**

Use these buttons if you suspect something is stuck or need to force recovery:

[Button] recover_status — Show current system state (layers active, last restart, etc.)
[Button] recover_force — Force immediate Layer 4 resumption of all stalled agents
[Button] recover_manual — Show manual recovery instructions
```

### Button Handlers (Bot.js Integration Needed)

Each button needs a handler in `bot.js`:

#### recover_status Button
- **Action:** Post current recovery state to the user
- **Response format:**
  ```
  ✅ **Recovery Status**
  
  Layer 1 (Watchdog): ACTIVE — last event: [last watchdog event timestamp]
  Layer 2 (Failover): ACTIVE — Primary: Mac Mini, Failover: VPS
  Layer 3 (Auto-Revert): ACTIVE — last validation: [timestamp], passed/failed
  Layer 4 (Resumption): ACTIVE — agents resumed in last restart: [N]
  
  Bot last restarted: [timestamp], [elapsed time] ago
  
  Nothing needs attention right now.
  ```

#### recover_force Button
- **Action:** Immediately trigger Layer 4 resumption
- **Steps:**
  1. Read all channel-state/*.json files
  2. For each agent with agentPid set + lastAgentMsgPhase not in [deliver, block]:
     - Write pm-agent-trigger.json
     - Post "Force-resuming stalled agents..."
  3. Wait 10s for pm triggers to fire
  4. Post summary: "X agent(s) forced to resume"

#### recover_manual Button
- **Action:** Post manual recovery instructions
- **Response:**
  ```
  📋 **Manual Recovery Checklist**
  
  If PAP is stuck and automatic recovery isn't working:
  
  1. Check bot status:
     ssh jerry@{{USER_VPS_TAILSCALE_IP}}
     pgrep -f "node bot.js" || echo "Bot is down"
  
  2. Restart bot manually:
     launchctl start com.pap.marvin  (Mac Mini)
     OR systemctl restart pap-bot    (VPS, if primary)
  
  3. Check recent logs:
     tail -50 ~/marvin-bot/marvin.log
  
  4. Force recovery:
     Use "recover_force" button above
  
  5. If still stuck, check #helm-audit for error patterns
  ```

## #helm-status Heartbeat Integration

Current heartbeat message includes system health. Recovery state should be added:

**New field in heartbeat:**

```
Recovery State: 🟢 Healthy [Layer 1-4 all active] / 🟡 Failover active [primary down, VPS running] / 🔴 Degraded [one layer failed]

Last restart: [timestamp], [X] agent(s) resumed
Last validation: [timestamp], [passed/failed]
```

## Implementation Checklist

- [x] Layer 3 auto-revert script created and integrated
- [x] Layer 4 agent resumption script created and integrated  
- [ ] #recovery channel created (manual in Discord or via bot setup)
- [ ] #troubleshooting channel created (manual in Discord or via bot setup)
- [ ] recover_status button handler added to bot.js
- [ ] recover_force button handler added to bot.js
- [ ] recover_manual button handler added to bot.js
- [ ] Heartbeat updated to include recovery state
- [ ] Pinned messages posted and locked
- [ ] Smoke test: Validate auto-revert with intentional syntax error

## Smoke Test Commands

```bash
# 1. Trigger auto-revert with intentional failure
cd ~/marvin-bot
echo "syntax error }" >> bot.js
git add bot.js
git commit -m "TEST: Intentional syntax error for auto-revert validation"

# 2. Queue a restart via queue-restart.sh
~/marvin-bot/queue-restart.sh "HELM smoke test: auto-revert validation"

# 3. Wait for 2am nightly restart (or force via safe-restart.sh --force)
# 4. Verify in logs: auto-revert detects syntax error, reverts, posts 🔴 to helm-improvements
# 5. Confirm bot is still running with original bot.js

# 6. Clean up
git reset --hard HEAD~1
```
