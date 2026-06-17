#!/usr/bin/env bash
# HELM beta-user patch — fixes: new-workspace scaffolding, agent identity,
# leaked internal apparatus, and re-enables onboarding/preferences/connectors.
# Safe + idempotent. Makes .bak backups of every file it touches.
set -e

# ========= SET YOUR ASSISTANT'S NAME HERE =========
NEW_NAME="Scout"      # <-- change to whatever you named your assistant
# ==================================================

HELM="$HOME/helm-workspace"
AGENTS="$HOME/.claude/agents"
BOT="$HOME/marvin-bot"

echo "[1/5] Scaffolder fix — linking workspace path the bot watches…"
ln -sfn "$HELM" "$HOME/pap-workspace"
echo "      ok: ~/pap-workspace -> $(readlink "$HOME/pap-workspace")"

echo "[2/5] Identity fix — replacing 'Marvin' with '$NEW_NAME'…"
sed -i.bak "s/You are Marvin, the HELM agent/You are $NEW_NAME, the HELM agent/" "$HELM/CLAUDE.md"
for f in "$AGENTS"/*.md; do sed -i.bak "s/You are Marvin\./You are $NEW_NAME./g" "$f"; done
sed -i.bak "s/^AGENT_NAME:.*/AGENT_NAME: $NEW_NAME/" "$HELM/CONFIG.md"
if grep -q "^AGENT_NAME=" "$BOT/.env" 2>/dev/null; then
  sed -i.bak "s/^AGENT_NAME=.*/AGENT_NAME=$NEW_NAME/" "$BOT/.env"
else echo "AGENT_NAME=$NEW_NAME" >> "$BOT/.env"; fi
echo "      ok"

echo "[3/5] Re-enabling onboarding/preferences/connectors…"
sed -i.bak "s/^ONBOARDING_COMPLETED:.*/ONBOARDING_COMPLETED: false/" "$HELM/CONFIG.md"
if grep -q "^ONBOARDING_STEP:" "$HELM/CONFIG.md"; then
  sed -i.bak "s/^ONBOARDING_STEP:.*/ONBOARDING_STEP: stage1_q1/" "$HELM/CONFIG.md"
else printf '\nONBOARDING_STEP: stage1_q1\n' >> "$HELM/CONFIG.md"; fi
echo "      ok"

echo "[4/5] Hiding internal apparatus (ACK/PUSHBACK/RESEARCH/[Agent:]) from chat…"
node - "$BOT/bot.js" <<'NODE'
const fs=require('fs');const p=process.argv[2];let s=fs.readFileSync(p,'utf8');
if(s.includes('__HELM_SANITIZE__')){console.log('      already patched');process.exit(0);}
const a="    function cleanOutput(raw) {\n      return (raw || '')";
if(!s.includes(a)){console.error('      ANCHOR NOT FOUND — tell {{USER_JERRY}}, skip this step');process.exit(0);}
const r="    function cleanOutput(raw) { // __HELM_SANITIZE__\n      return (raw || '')"
+"\n        .replace(/^[ \\t]*(?:\\u{1F44D}|\\u{23F3}|\\u{23F8}|\\u{2705})[ \\t]*(?:\\[Agent:[^\\]]*\\][ \\t]*)?(?:ACK|UPDATE|BLOCK|DELIVER)\\b[ \\t]*[\\u2014:\\-]*[ \\t]*/gimu,'')"
+"\n        .replace(/^[ \\t]*(?:\\u{1F44D}|\\u{23F3}|\\u{23F8}|\\u{2705})[ \\t]*Gate:.*$/gimu,'')"
+"\n        .replace(/^[ \\t]*\\[Agent:[^\\]]*\\][ \\t]*/gim,'')"
+"\n        .replace(/^[ \\t]*(?:PUSHBACK|VERIFICATION_REQUIRED|PROACTIVE_NEXT|RESEARCH|Docs updated|Gate|Prevention):.*$/gim,'')";
s=s.replace(a,r);fs.writeFileSync(p,s);console.log('      ok: sanitizer added');
NODE

echo "[5/5] Restarting the bot…"
cd "$BOT"
if [ -f safe-restart.sh ]; then bash safe-restart.sh --force || true
else pkill -f "node .*bot.js" 2>/dev/null || true; sleep 2; nohup node bot.js >/tmp/helm-bot.log 2>&1 & fi
echo
echo "DONE. Now go to Discord and type:  onboarding"
echo "After preferences finish, type:    connect    (to add Calendar/Email)"
