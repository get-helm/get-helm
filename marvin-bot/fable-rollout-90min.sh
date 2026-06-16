#!/bin/bash
# fable-rollout-90min.sh — one-shot. After the 90-min channel-scoped Fable test,
# roll the trial to all channels and deploy the model-mismatch alert (immediate restart).
# Cancel anytime: touch ~/marvin-bot/.fable-rollout-hold

sleep 5400

HOLD="$HOME/marvin-bot/.fable-rollout-hold"
POST="$HOME/marvin-bot/discord-post.sh"
CH=1514005756339421344

if [ -f "$HOLD" ]; then
  "$POST" "$CH" "⏸ Fable rollout held — hold flag was set. Trial stays scoped to this channel."
  rm -f "$HOLD"
  exit 0
fi

if ! pgrep -f "node.*bot.js" > /dev/null; then
  "$POST" "$CH" "⚠️ Fable rollout aborted — bot wasn't running at the 90-min mark. Re-run fable-rollout-90min.sh manually after recovery."
  exit 1
fi

if tail -c 200000 "$HOME/marvin-bot/marvin.log" 2>/dev/null | grep -q "\[model-config\] failed"; then
  "$POST" "$CH" "⚠️ Fable rollout held — model-config load errors in recent logs. Trial stays channel-scoped until checked."
  exit 1
fi

python3 - <<'EOF'
import json
p = '/Users/{{USER_HOME}}/marvin-bot/model-config.json'
cfg = json.load(open(p))
if cfg.get('trial'):
    cfg['trial'].pop('test_channels', None)
json.dump(cfg, open(p, 'w'), indent=2)
EOF

cd "$HOME/marvin-bot" && git add model-config.json && git commit -m "Fable trial: roll out to all channels after 90-min test" --quiet

"$POST" "$CH" "✅ 90-min test passed — Fable 5 is now live in ALL channels (Sonnet slot) through June 22. Restarting briefly to turn on the model-mismatch alert."

"$HOME/marvin-bot/safe-restart.sh" --force
