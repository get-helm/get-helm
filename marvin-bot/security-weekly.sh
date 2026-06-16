#!/bin/bash
# Weekly security scan — runs every Monday, posts to #pap-improvements
# Checks: VPS SSH status, fail2ban activity, auth log anomalies, nginx headers
# Also surfaces recent agentic AI security news for review

CHANNEL="{{USER_CHANNEL_HELM_IMPROVEMENTS}}"  # pap-improvements
VPS_HOST="{{USER_VPS_TAILSCALE_IP}}"  # Tailscale IP — stable regardless of ISP reassignment
SSH_KEY="$HOME/.ssh/id_ed25519"
SSH_OPTS="-i $SSH_KEY -o ConnectTimeout=8 -o StrictHostKeyChecking=no -o BatchMode=yes"

post() {
  ~/marvin-bot/discord-post.sh "$CHANNEL" "$1"
}

post "⏳ Weekly security scan starting — checking VPS, auth, and agentic AI news."

# 1. Check VPS SSH accessibility (key-only, no password)
SSH_OK="✅"
if ! ssh $SSH_OPTS root@"$VPS_HOST" "echo ok" > /dev/null 2>&1; then
  SSH_OK="🔴 SSH DOWN"
fi

# 2. Check web endpoints
OPTIONS_STATUS=$(curl -s -o /dev/null -w '%{http_code}' https://options.{{USER_DOMAIN}}/login 2>/dev/null)
ETF_STATUS=$(curl -s -o /dev/null -w '%{http_code}' https://etf.{{USER_DOMAIN}}/ 2>/dev/null)

# 3. VPS checks (if SSH up)
FAIL2BAN_STATUS="unknown"
BANNED_IPS="none"
UFW_STATUS="unknown"
RECENT_FAILS="0"

CRED_LEAK="✅"
PORT_9876="✅"

if [ "$SSH_OK" = "✅" ]; then
  VPS_INFO=$(ssh $SSH_OPTS root@"$VPS_HOST" "
    echo FAIL2BAN:\$(systemctl is-active fail2ban 2>/dev/null)
    echo UFW:\$(ufw status 2>/dev/null | head -1 | awk '{print \$2}')
    echo BANNED:\$(fail2ban-client status sshd 2>/dev/null | grep 'Banned IP' | sed 's/.*Banned IP list://;s/^[ \t]*//')
    echo FAILS:\$(grep 'Failed password' /var/log/auth.log 2>/dev/null | grep \"\$(date +%Y-%m-%d)\" | wc -l | tr -d ' ')
    # Check for credentials in world-readable files
    grep -q 'PAP_AUTH_PASS\|PAP_AUTH_SECRET' /etc/environment 2>/dev/null && echo CRED_LEAK:yes || echo CRED_LEAK:no
    # Check for credentials hardcoded in systemd service files
    grep -rq 'PAP_AUTH_PASS\|PAP_AUTH_SECRET' /etc/systemd/system/ 2>/dev/null && echo SVC_CRED_LEAK:yes || echo SVC_CRED_LEAK:no
    # Check heartbeat port binding
    ss -tlnp | grep 9876 | grep -q '0.0.0.0' && echo PORT9876:exposed || echo PORT9876:ok
  " 2>/dev/null)
  FAIL2BAN_STATUS=$(echo "$VPS_INFO" | grep FAIL2BAN | cut -d: -f2)
  UFW_STATUS=$(echo "$VPS_INFO" | grep UFW | cut -d: -f2)
  BANNED_IPS=$(echo "$VPS_INFO" | grep BANNED | cut -d: -f2-)
  RECENT_FAILS=$(echo "$VPS_INFO" | grep FAILS | cut -d: -f2)
  [ -z "$BANNED_IPS" ] && BANNED_IPS="none"
  [ "$(echo "$VPS_INFO" | grep CRED_LEAK | cut -d: -f2)" = "yes" ] && CRED_LEAK="🔴 Credentials in /etc/environment (world-readable!)"
  [ "$(echo "$VPS_INFO" | grep SVC_CRED_LEAK | cut -d: -f2)" = "yes" ] && CRED_LEAK="🔴 Credentials hardcoded in systemd service file!"
  [ "$(echo "$VPS_INFO" | grep PORT9876 | cut -d: -f2)" = "exposed" ] && PORT_9876="🔴 Port 9876 binding to 0.0.0.0 (should be localhost only)"
fi

# 4. Check for agentic AI security news (multiple feeds + CVE database)
AI_NEWS=""
FEED_RESULTS=""

# Hacker News RSS
HN=$(curl -s "https://feeds.feedburner.com/TheHackersNews" 2>/dev/null | grep -o '<title>[^<]*</title>' | grep -i "AI\|agent\|LLM\|claude\|openai\|anthropic\|prompt inject\|jailbreak" | head -2 | sed 's/<[^>]*>//g')
[ -n "$HN" ] && FEED_RESULTS="$FEED_RESULTS\n$HN"

# Anthropic security/news RSS
ANTHROPIC=$(curl -s "https://www.anthropic.com/rss.xml" 2>/dev/null | grep -o '<title>[^<]*</title>' | grep -iv "^<title>Anthropic</title>" | grep -i "security\|vulnerab\|safety\|advisory" | head -2 | sed 's/<[^>]*>//g')
[ -n "$ANTHROPIC" ] && FEED_RESULTS="$FEED_RESULTS\n[Anthropic] $ANTHROPIC"

# OpenAI blog RSS
OPENAI=$(curl -s "https://openai.com/blog/rss.xml" 2>/dev/null | grep -o '<title>[^<]*</title>' | grep -i "security\|safety\|vulnerab\|advisory" | head -2 | sed 's/<[^>]*>//g')
[ -n "$OPENAI" ] && FEED_RESULTS="$FEED_RESULTS\n[OpenAI] $OPENAI"

# NVD CVE recent (AI/LLM related)
NVD=$(curl -s "https://services.nvd.nist.gov/rest/json/cves/2.0?keywordSearch=LLM+agent+AI&resultsPerPage=3" 2>/dev/null | python3 -c "
import json,sys
try:
  data=json.load(sys.stdin)
  for v in data.get('vulnerabilities',[])[:2]:
    cve=v.get('cve',{})
    cid=cve.get('id','')
    desc=cve.get('descriptions',[{}])[0].get('value','')[:80]
    print(f'[CVE] {cid}: {desc}')
except: pass
" 2>/dev/null)
[ -n "$NVD" ] && FEED_RESULTS="$FEED_RESULTS\n$NVD"

if [ -n "$FEED_RESULTS" ]; then
  AI_NEWS=$(printf "$FEED_RESULTS" | head -6 | while read line; do [ -n "$line" ] && echo "• $line"; done)
else
  AI_NEWS="• No recent agentic AI security headlines this week"
fi

# 5. Compose report
REPORT="✅ Weekly Security Scan — $(date '+%Y-%m-%d')

**VPS Status**
• SSH: $SSH_OK
• Firewall (UFW): $UFW_STATUS
• Fail2ban: $FAIL2BAN_STATUS
• Banned IPs today: $BANNED_IPS
• Failed SSH attempts today: $RECENT_FAILS

**Credential Hygiene**
• Env vars world-readable: $CRED_LEAK
• Port 9876 binding: $PORT_9876

**Web Endpoints**
• options.{{USER_DOMAIN}}/login: HTTP $OPTIONS_STATUS
• etf.{{USER_DOMAIN}}: HTTP $ETF_STATUS

**Agentic AI Security News**
$AI_NEWS

PUSHBACK: none
VERIFICATION_REQUIRED: AI news pulls from Hacker News, Anthropic RSS, OpenAI blog, and NVD CVE — coverage is broad but not exhaustive."

post "$REPORT"
