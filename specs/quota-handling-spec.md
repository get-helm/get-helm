# Quota Handling Spec

## Problem
When Claude subscription quota hits, users get generic "Something went wrong" errors with no context. Tasks get stuck. When quota resets, tasks stay stuck unless manually re-triggered.

## Solution
Three bot.js changes:

### Change 1: Quota Error Detection + User Messaging
Wrap all Claude API calls with error handler:
```javascript
try {
  const response = await client.messages.create({...});
} catch (error) {
  if (error.status === 429 || error.message.includes('quota')) {
    const quotaResetTime = extractResetTime(error.headers); // RFC 3339
    const resetIn = minutesUntil(quotaResetTime);
    discord.post(NOTIFY_CHANNEL, 
      `⚠️ Claude subscription quota reached. Resets in ${resetIn} min.\n` +
      `Options: [Buy Extra Use](https://claude.ai/account) | [Upgrade Plan](https://claude.ai/account)`
    );
    // Mark quota state
    updateActiveState({ quota_state: 'exhausted', quota_reset_time: quotaResetTime });
  }
  throw error; // Re-throw for agent to handle
}
```

### Change 2: Track Quota State in ACTIVE-STATE.md
Add quota tracking:
```json
{
  "quota_state": "active|exhausted|recovering",
  "quota_reset_time": "2026-05-10T15:30:00Z",
  "quota_last_error": "2026-05-09T14:22:15Z"
}
```
- Set to `exhausted` when API returns 429/quota error
- Set to `recovering` when first successful request after exhaustion
- Clear when reset completes

### Change 3: Auto-Retry on Quota Recovery
After first successful API call post-quota:
```javascript
if (ACTIVE_STATE.quota_state === 'recovering') {
  updateActiveState({ quota_state: 'active', quota_reset_time: null });
  // Re-fire any queued work
  const queued = readEngineerQueue();
  queued.forEach(job => launchAgent(job));
  
  // Resume any checkpointed workspace agents
  const workspaces = listWorkspaces();
  workspaces.forEach(ws => {
    const checkpoint = loadCheckpoint(ws.channelId);
    if (checkpoint && checkpoint.halted_by_quota) {
      relayToAgent(ws.channelId, `Quota recovered. Resuming from step ${checkpoint.currentStep}.`);
      launchAgent(ws);
    }
  });
}
```

Also set `halted_by_quota: true` in workspace checkpoints when quota error is caught.

## Testing
1. **Simulate quota error:** Mock API to return 429
2. **Verify message posts** to #notify with reset time
3. **Verify state updates** in ACTIVE-STATE.md
4. **Verify auto-retry:** Queue engineer job, hit quota, quota resets, job re-fires automatically

## Impact
- Users see why tasks stopped + when they'll resume
- No manual re-trigger needed
- Same checkpoint logic as restart handling — re-uses existing auto-resume pattern
