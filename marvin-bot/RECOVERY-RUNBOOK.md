# HELM Recovery Runbook

When things break, run `bash ~/marvin-bot/grab-logs.sh` first, drag the file into Claude.ai, and paste this runbook. It gives Claude everything needed to diagnose without back-and-forth.

---

## Scenario 1 — (retired) Orchestrator routing loop

The orchestrator was fully removed on 2026-06-10 (code archived at `~/marvin-bot/archive/orchestrator-removed-20260610/`). This failure mode can no longer occur. If you see `Step N ✗ — Command failed` patterns, treat as Scenario 2 or 3.

---

## Scenario 2 — Startup-recovery crash loop

**Symptoms:** bot restarts every ~10 minutes, `[startup-recovery] resuming` appears in log repeatedly.

**Recovery:**
```bash
python3 -c "
import json, os, glob
for f in glob.glob(os.path.expanduser('~/pap-workspace/channel-state/*.json')):
    try:
        d = json.load(open(f))
        d['lastAgentMsgPhase'] = 'deliver'
        d['agentPid'] = None
        d['checkpoint'] = None
        open(f, 'w').write(json.dumps(d, indent=2))
    except: pass
print('All channel states cleared')
"
~/marvin-bot/safe-restart.sh
```

---

## Scenario 3 — Bot not responding but process running

**Symptoms:** ⏳ and ✅ reactions fire but no message appears in Discord.

**Recovery:** Check `lastAgentMsgPhase` in channel state files — if `deliver`, the skip-post bug is active. Clear channel states as in Scenario 2, then restart.

---

## Scenario 4 — Restart guard blocking recovery

**Symptoms:** `safe-restart.sh` outputs "Restart blocked: N unverified changes".

**Recovery:**
```bash
~/marvin-bot/safe-restart.sh --skip-guard
```

If that fails:
```bash
pkill -f "node.*bot.js"; sleep 5; launchctl kickstart -k gui/$(id -u)/com.pap.marvin
```

---

## Scenario 5 — Bot completely down, launchd not recovering

**Symptoms:** `pgrep -f "node.*bot.js"` returns nothing, launchd not restarting.

**Recovery:**
```bash
~/marvin-bot/safe-restart.sh
```

If still nothing:
```bash
launchctl load ~/Library/LaunchAgents/com.pap.marvin.plist
```

---

## Orchestrator (removed 2026-06-10)

The orchestrator was deleted with {{USER_JERRY}}'s approval. Code is archived at `~/marvin-bot/archive/orchestrator-removed-20260610/`. The `ORCHESTRATOR_ENABLED` flag no longer exists in `.env` or bot.js. Agent `[ORCHESTRATE:]` sentinels are stripped harmlessly by bot.js. Task tracking lives in the agent ledger + checkpoint system.
