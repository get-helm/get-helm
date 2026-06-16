#!/bin/bash
# grab-logs.sh — bundles PAP diagnostic info into a single file for Claude.ai
# Usage: bash ~/marvin-bot/grab-logs.sh
# Then drag the output file into a Claude.ai chat

OUT="/tmp/pap-diagnostic-$(date +%Y%m%d-%H%M%S).txt"

echo "=== PAP DIAGNOSTIC BUNDLE ===" > "$OUT"
echo "Generated: $(date)" >> "$OUT"
echo "" >> "$OUT"

echo "=== BOT PROCESS ===" >> "$OUT"
pgrep -af "node.*bot" 2>/dev/null >> "$OUT" || echo "(no node process found)" >> "$OUT"
ps aux | grep node | grep -v grep >> "$OUT"
echo "" >> "$OUT"

echo "=== RECENT LOG (last 200 lines) ===" >> "$OUT"
tail -200 /Users/{{USER_HOME}}/marvin-bot/marvin.log 2>/dev/null >> "$OUT"
echo "" >> "$OUT"

echo "=== ACTIVE STATE ===" >> "$OUT"
cat /Users/{{USER_HOME}}/helm-workspace/ACTIVE-STATE.md 2>/dev/null >> "$OUT"
echo "" >> "$OUT"

echo "=== CHANNEL STATE FILES ===" >> "$OUT"
for f in /Users/{{USER_HOME}}/helm-workspace/channel-state/*.json; do
  echo "--- $f ---" >> "$OUT"
  cat "$f" >> "$OUT"
  echo "" >> "$OUT"
done

echo "=== DECISIONS LOG (last 50 lines) ===" >> "$OUT"
tail -50 /Users/{{USER_HOME}}/helm-workspace/decisions-log.md 2>/dev/null || echo "(empty)" >> "$OUT"
echo "" >> "$OUT"

echo "=== GIT LOG (last 10 commits) ===" >> "$OUT"
cd /Users/{{USER_HOME}}/marvin-bot && git log --oneline -10 2>/dev/null || echo "(no git history)" >> "$OUT"
echo "" >> "$OUT"

echo "=== FRICTION LOG (last 30 lines) ===" >> "$OUT"
tail -30 /Users/{{USER_HOME}}/helm-workspace/friction-log.md 2>/dev/null || echo "(empty)" >> "$OUT"
echo "" >> "$OUT"

echo "=== RECOVERY RUNBOOK ===" >> "$OUT"
cat /Users/{{USER_HOME}}/marvin-bot/RECOVERY-RUNBOOK.md 2>/dev/null || echo "(recovery runbook not found — see ~/marvin-bot/RECOVERY-RUNBOOK.md)" >> "$OUT"
echo "" >> "$OUT"

echo "Bundle saved to: $OUT"
echo "Drag this file into a Claude.ai chat to get help."
open -R "$OUT" 2>/dev/null || true
