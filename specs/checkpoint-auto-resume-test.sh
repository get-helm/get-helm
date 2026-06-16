#!/bin/bash
# Checkpoint Auto-Resume Verification Test
# Purpose: Before Tasks 4-5 deploy, verify that the checkpoint system actually works
# Estimated time: 10 minutes to write test + 2-3 minutes to run it when bot can be killed

# This test verifies:
# 1. Checkpoints are written correctly during task execution
# 2. Bot.js reads and restores checkpoints on startup
# 3. Tasks resume from saved step, not restarted from beginning

set -e

CHECKPOINT_DIR="~/pap-workspace/channel-state"
TEST_CHANNEL="1501656066340032776"  # #pap-improvements for testing
TEST_FILE="$CHECKPOINT_DIR/${TEST_CHANNEL}.json"

echo "=== Checkpoint Auto-Resume Test ==="
echo ""

# Step 1: Create a fake checkpoint as if a task was mid-execution
echo "[1/5] Writing fake checkpoint (Task A, Step 1 of 3 complete)..."
python3 -c "
import json, time, os
os.makedirs('$CHECKPOINT_DIR', exist_ok=True)
checkpoint = {
    'channelId': '$TEST_CHANNEL',
    'checkpoint': {
        'requestText': 'Test checkpoint recovery',
        'taskPlan': ['1. initial setup', '2. main work', '3. cleanup'],
        'currentStep': 1,  # Step 0 done, Step 1 in progress
        'totalSteps': 3,
        'notes': 'Checkpoint test: agent was interrupted here',
        'savedAt': int(time.time())
    }
}
with open('$TEST_FILE', 'w') as f:
    json.dump(checkpoint, f, indent=2)
print('✓ Checkpoint written')
print(f'  File: $TEST_FILE')
print(f'  Current step: 1 of 3')
"

# Step 2: Queue a live test task (optional — can also manually spawn an agent)
echo ""
echo "[2/5] Checkpoint written. Next steps:"
echo ""
echo "  OPTION A: Let a task execute and checkpoint naturally"
echo "    1. Queue a task in engineer-queue.md that will take 30+ seconds"
echo "    2. Wait for it to post its first ⏳ UPDATE"
echo "    3. Check the checkpoint file to confirm currentStep changed"
echo ""
echo "  OPTION B: Kill bot mid-task (more direct test)"
echo "    1. Start any workspace agent (e.g., 'run engineer' in #pap-status)"
echo "    2. Wait for first ⏳ UPDATE"
echo "    3. Manually kill the bot: 'killall node' in terminal"
echo "    4. Restart the bot"
echo "    5. Check if task resumed or restarted"
echo ""

# Step 3: Verification steps
echo "[3/5] VERIFICATION CHECKLIST:"
echo ""
echo "  After bot restart, check these:"
echo "  [ ] Checkpoint file still exists: $TEST_FILE"
echo "  [ ] Checkpoint currentStep is updated (not frozen at 1)"
echo "  [ ] Task resumed from saved step (not restarted from 0)"
echo "  [ ] Agent posted ⏳ UPDATE mentioning checkpoint load or resume"
echo ""

# Step 4: Expected behavior
echo "[4/5] EXPECTED BEHAVIOR ON SUCCESS:"
echo ""
echo "  Bot.js startup log should show:"
echo "    '[bot-startup] Loading checkpoints for resumed tasks...'"
echo "    '[checkpoint-restore] Restored [channel]: step 1 of 3'"
echo ""
echo "  Agent should post UPDATE like:"
echo "    '⏳ Resuming from checkpoint — Step 1 of 3 already complete. Continuing...'"
echo ""
echo "  If test FAILS:"
echo "    - Checkpoint file not loaded → bot.js not reading it"
echo "    - Task restarted from 0 → checkpoint load succeeded but not applied"
echo "    - Silent restart → checkpoint code has a bug (check marvin.log)"
echo ""

# Step 5: Log the test
echo "[5/5] Logging test intent..."
echo "
## 2026-05-09 — Checkpoint Auto-Resume Test
Status: PENDING EXECUTION
Test date: $(date)
Checkpoint file: $TEST_FILE
Test method: Kill-and-restart (if possible) OR natural task interruption
Success criteria: Task resumes from saved step, not restarted
Expected: checkpoint loaded and applied within 10s of startup
Log reference: marvin.log (search for 'checkpoint-restore')

This test must PASS before Tasks 4-5 deploy.
" >> ~/pap-workspace/friction-analysis.md

echo ""
echo "=== Test Checklist Ready ==="
echo ""
echo "Next steps:"
echo "  1. Run either Option A or Option B above"
echo "  2. Check the verification checklist"
echo "  3. Log results in friction-analysis.md under 'Test Results'"
echo "  4. If PASS: clear Tasks 4-5 to engineer-queue"
echo "  5. If FAIL: block Tasks 4-5, debug checkpoint loading in bot.js"
echo ""
echo "Time to execute: ~2-3 minutes once a task is running"
