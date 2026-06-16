# CAPABILITIES.MD
## HELM System Capabilities Registry
## Updated: May 5, 2026

This file is the authoritative record of what HELM can and cannot do.
Agents read this before proposing solutions.
Agents update this after every Phase A or Phase B loop that proves or disproves a capability.

---

## HOW TO WRITE AN ENTRY

**Before writing, apply the generalizable test:**
Ask: "Would a workspace that knows nothing about [current workspace] benefit from this proof?"
- YES → write to this file (platform capability, API behavior, tool limitation)
- NO → workspace-specific config fact, keep it in the workspace's LEARNINGS.md

Examples:
- "Flask deploys on VPS" → YES (generalizable)
- "subdomain.yourdomain.com DNS points to 1.2.3.4" → NO (domain-specific config)
- "Firecrawl bypasses MarketWatch but not Morningstar" → YES (tool behavior)
- "ETF tracker cron runs at 6 AM" → NO (workspace schedule)

**PROVEN entry format:**
  Method: [exact command or script path]
  Tested: [date] (workspace: [slug] if workspace-specific proof)
  Re-verify by: [6 months from test date — flag to user if past this date]
  Notes: [constraints, gotchas, failure modes to watch for]

**FAILED entry format:**
  Tried: [methods attempted]
  Failed: [date] (workspace: [slug])
  Reason: [specific technical reason — never vague]
  Retryable: [Yes / No / Only if X]

When you add or update an entry, also check whether pap-architecture-guide skill
"Known working" / "Known failed" sections are stale — they defer to this file but may lag.

---

## CONNECTORS (always available — platform-injected)

Instance-specific accounts for all connectors → see HELM-FACTS.md (user partition)

Gmail
  Operations: search_threads, get_thread, list_drafts, create_draft,
              list_labels, create_label, apply_label
  Limitation: Can DRAFT emails. Cannot SEND. Always set user expectations accordingly.

Google Calendar
  Operations: list_events, get_event, create_event, update_event, delete_event,
              respond_to_event, suggest_time
  Yahoo Mail rate limit: When sending >3 Google Calendar invites in a batch to Yahoo addresses,
    Yahoo's spam/rate filter silently drops the extras. Fix: remove and re-add guest one at a time
    with a 60s delay between each. Confirmed 2026-05-14 — batching 11 invites at once resulted in
    only 3–4 arriving; one-per-minute spacing delivered all 11 successfully.

Google Drive
  Operations: list_files, search_files, read_file, download_file, create_file,
              copy_file, get_metadata, get_permissions
  Limitation: Drive ≠ Sheets. Use scripts/pap-sheets.sh for spreadsheet data.

Google Sheets
  Method: ~/pap-workspace/scripts/pap-sheets.sh
  Operations: add_tab, write_rows, add_tab_and_write, read_tab, list_tabs,
              clear_tab, delete_tab, find_sheet
  Config: SHEETS_API_URL and SHEETS_API_SECRET in CONFIG.md

Discord
  Method: curl to REST API using $DISCORD_BOT_TOKEN
  Operations: post message, add reaction, remove reaction, pin message,
              create channel, edit message
  Limitation: Buttons/select menus not yet tested (Loop 7 backlog)

---

## PROVEN CAPABILITIES

Format: capability | method | tested | workspace | notes

Graphify (codebase knowledge graph for engineer tasks)
  Method: ~/.local/bin/graphify explain "functionName" --graph ~/marvin-bot/graphify-out/graph.json
          ~/.local/bin/graphify path "A" "B" --graph [graph]
          ~/.local/bin/graphify query "description" --graph [graph] --budget 1500
          ~/.local/bin/graphify affected "functionName" --graph [graph]
  Graphs: bot.js+scripts → ~/marvin-bot/graphify-out/graph.json
          agent .md files → ~/.claude/agents/graphify-out/graph.json
  Tested: 2026-06-12 (explain hasProactiveWork → returns node + connections + L128 line number)
  Re-verify by: 2026-12-12
  Notes: v0.8.18 installed. Graphs rebuilt Sundays 3am PT via graphify-reindex.sh. Use before any grep for function lookups — returns line numbers for targeted reads. If graph >7 days old: run ~/marvin-bot/graphify-reindex.sh. Stale by 126h as of 2026-06-12 but still accurate (no major bot.js rewrite since last index). Always try graphify first; fallback to grep only if "No matching nodes found". Engineer.md CODE INVESTIGATION section documents full usage pattern.
  Telemetry wrapper (added 2026-06-12): bash ~/marvin-bot/graphify-query.sh "symbol" — wraps graphify explain + logs usage to ~/helm-workspace/system/tool-usage.log. Prefer the wrapper so PM T2-C adoption metrics capture the call.

QMD second-brain query (decision history + prior context lookup)
  Method: bash ~/marvin-bot/qmd-query.sh "specific multi-word topic phrase" 3 --min-relevance 0.7
  Tested: 2026-06-12 (query "agent behavior enforcement" → returned 2026-06-03 trustworthy-agents analysis, score 0.93)
  Re-verify by: 2026-12-12
  Notes: Use BEFORE any decision that touches prior work (reversing a choice, building on prior design, anything where the user says "we discussed/decided X"). Query quality matters: specific noun phrases, not meta-descriptions; try 3 variants before concluding "not found". Logs usage to ~/helm-workspace/system/tool-usage.log (telemetry added 2026-06-12). Cite in RESEARCH field as: QMD: query="..." → top result: [title] (score=X) — bot.js B-12 rejects bare "searched QMD" claims.

Fireflies.ai GraphQL API (meeting transcripts)
  Method: POST https://api.fireflies.ai/graphql, Authorization: Bearer {key from "Fireflies.ai API" in HELM Vault}. Query: transcripts(limit: N) { id title date duration transcript_url summary { overview action_items keywords } sentences { text speaker_name } }
  Tested: 2026-06-09 (user query returned {{USER_JERRY}}'s account; transcripts query schema-valid, 0 transcripts at test time)
  Re-verify by: 2026-12-09
  Notes: API works on FREE tier (key auth confirmed live). date = epoch ms. summary fields may be null when free-tier AI-note cap (10/mo) exhausted — fireflies-pull.py falls back to claude haiku summarization. Hourly ingest: step 4 of second-brain-continuous-ingest.sh.

Plain HTTP/JSON fetch
  Method: curl -s [url] | jq [filter]
  Tested: May 3, 2026
  Notes: Works for any endpoint that returns JSON without JS rendering

Tiingo API (price, dividend, total-return data)
  Method: GET https://api.tiingo.com/tiingo/daily/{ticker}/prices?token={TOKEN}&startDate={}&endDate={}&resampleFreq=daily
  Tested: 2026-05-05 (workspace: etf-tracker)
  Re-verify by: 2026-11-05
  Notes: Returns adjusted close + dividends. Total return computed as compounded adjusted_close with dividends reinvested. JEPQ 2024 total return matched spreadsheet exactly (24.89%). Free tier: 500 calls/day — sufficient for 288-ticker monthly batch with 1s delays. Better than Yahoo Finance at scale for dividend-adjusted history. CLM off ~1pt (CEF return-of-capital treatment vs. Morningstar — not a data error).

CEF NAV scraping via Firecrawl (cefconnect.com)
  Method: Firecrawl.scrapeUrl("https://www.cefconnect.com/fund/{ticker}"); regex on markdown for NAV, prem/disc, expense ratio
  Tested: 2026-05-06 (workspace: etf-tracker, Loop 18)
  Re-verify by: 2026-11-06
  Notes: Firecrawl returns 15,000+ char markdown from cefconnect.com with full table data. NAV regex: r'Current\s*\|[^|]+\|\s*\\?[$]?([\d]+\.[\d]+)\s*\|'. Prem/disc regex: r'Current\s*\|[^|]+\|[^|]+\|\s*(-?[\d.]+)%'. Expense regex: r'Total:\s*\|\s*([\d.]+)%'. Not on cefconnect: MAIN (BDC), MPLX (MLP), OHI (REIT) — those return "Page Not Found". Playwright (domcontentloaded + 5s sleep) also works but Firecrawl is simpler and doesn't require a VPS browser install. Fields: NAV, price, premium/discount %, 52-week high/low, distribution rate, expense ratio, sector breakdown, top holdings, historical performance.

Morningstar stock /quote pages via Firecrawl (stocks, REITs, BDCs, MLPs)
  Method: Firecrawl scrape of https://www.morningstar.com/stocks/{exchange}/{ticker.lower()}/quote
  Tested: 2026-05-07 (workspace: etf-tracker)
  Re-verify by: 2026-11-07
  Notes: Returns 6,000-8,000 char markdown with market cap, P/E (normalized), P/B, P/S, P/CF,
    dividend yield (trailing + forward), shares outstanding, sector, industry, ROA, ROE, ROIC,
    quick ratio, current ratio, interest coverage. No login required. Confirmed for:
    OHI (xnys), MPLX (xnys), MAIN (xnys). Exchange codes same as stocks generally: xnys (NYSE),
    xnas (NASDAQ). /risk and /performance sub-pages do NOT exist for stocks (404) — only /quote
    and /chart are available for stock tickers. Use Tiingo for stock historical returns.

yfinance P/E ratio (equity ETFs and CEFs)
  Method: import yfinance as yf; yf.Ticker(ticker).info.get('trailingPE')
  Tested: 2026-05-05 (workspace: etf-tracker)
  Re-verify by: 2026-11-05
  Notes: Returns trailingPE for equity ETFs and CEFs. Bond ETFs return None/NaN — correct (P/E not meaningful for bond funds; treat as N/A). Direct curl to Yahoo Finance v10 quoteSummary fails (invalid crumb); yfinance handles auth internally. Must pip-install on each host. ETF.com and ETFdb.com are Cloudflare-blocked.

Alpha Vantage ETF_PROFILE (AUM, expense ratio, sector weights)
  Method: GET https://www.alphavantage.co/query?function=ETF_PROFILE&symbol={ticker}&apikey={KEY}
  Tested: 2026-05-08 (workspace: etf-tracker, Loop 23)
  Re-verify by: 2026-11-08
  Notes: Returns net_assets (AUM), net_expense_ratio (decimal format: 0.006 = 0.6% — multiply by 100 to get %), portfolio_turnover, dividend_yield, sector weights, top holdings. Free tier: 25 calls/day AND 5 calls/minute — add 12s delay between calls to avoid mid-run rate limits. For 288 tickers monthly, batch 25/day over 12 days. Does NOT cover REITs/stocks/MLPs (returns n/a). Does NOT cover CEFs (use CEFConnect instead). P/E not available from this source; use yfinance for that. FMP free tier does NOT cover ETF fundamentals (see FAILED).

Morningstar Portfolio Risk Score via Firecrawl
  Method: Firecrawl.scrapeUrl("https://www.morningstar.com/etfs/{exchange}/{ticker.lower()}/risk"); parse markdown for "### Portfolio Risk Score\n\n{N}"
  Tested: 2026-05-05 (workspace: etf-tracker, Loop 12)
  Re-verify by: 2026-11-05
  Notes: Firecrawl bypasses Cloudflare on morningstar.com. No login required. Numeric score appears as clean heading + number in markdown — no regex needed. Score scale: 0-23 Conservative | 24-47 Moderate | 48-78 Aggressive | 79-99 Very Aggressive | 100+ Extreme. Exchange codes: arcx (NYSE Arca, most ETFs), xnas (NASDAQ), xnys (NYSE). Free tier: 500 pages/month — covers 288 tickers. Plain Playwright (headless, no stealth) fails — returns Cloudflare challenge page at HTTP 200 with no data. Key in PAP Vault as "Firecrawl API".

Flask on Hostinger VPS (Ubuntu 24.04)
  Method: SSH to VPS; python3 -m venv /opt/{project}/venv; venv/bin/pip install flask; run with nohup or systemd unit
  Tested: 2026-05-05 (workspace: etf-tracker, Loop 6)
  Re-verify by: 2026-11-05
  Notes: VPS IP: see HELM-FACTS.md. Root SSH. Credentials in PAP Vault → "Hostinger Root" (op --reveal required). Ubuntu 24.04 uses externally-managed Python (PEP 668) — must use venv, not pip3 system-wide. Flask binds 0.0.0.0:5000, external access confirmed. Note: nohup processes die when SSH session drops — use systemd unit or cron @reboot for production persistence.

Playwright/Chromium on Hostinger VPS (Ubuntu 24.04)
  Method: pip install playwright && playwright install chromium && playwright install-deps chromium
  Tested: 2026-05-05 (workspace: etf-tracker, Loop 6)
  Re-verify by: 2026-11-05
  Notes: CRITICAL: `playwright install chromium` alone is NOT sufficient. Must also run `playwright install-deps chromium` to install system libraries (libatk-1.0.so.0 and others) missing by default on Ubuntu 24.04 VPS. Without this step, Chromium exits immediately with shared library error. Install inside venv for path isolation.

nginx + Let's Encrypt (Certbot) on VPS with Tailscale port conflict
  Method: apt install nginx; snap install certbot --classic; certbot --nginx -d {domain}
  Tested: 2026-05-05 (workspace: etf-tracker, Loop 9)
  Re-verify by: 2026-11-05
  Notes: CRITICAL: If Tailscale is running, tailscaled may bind a specific Tailscale IP on port 443. Linux refuses to let nginx bind 0.0.0.0:443 (wildcard) when any process holds a specific-IP binding on that port. Fix: change nginx listen directive from `listen 443 ssl` to `listen {public_ip}:443 ssl`. Auto-renewal via snap. Cert requires domain to resolve to VPS first (HTTP-01 challenge).

Dreamhost DNS API (programmatic A record management)
  Method: curl "https://api.dreamhost.com/?key={KEY}&cmd=dns-add_record&type=A&record={subdomain}&value={ip}&unique_id=$(uuidgen)"
  Tested: 2026-05-05 (workspace: etf-tracker, Loop 8)
  Re-verify by: 2026-11-05
  Notes: API key page is ?tree=home.api in panel (NOT /account/keys — 404s in current panel UI). "Account" moved to "Billing & Account" dropdown in top-nav. Propagation up to 30 min — verify with: dig {subdomain} A +short. Key in PAP Vault as "Dreamhost API".

Gmail 2FA interception pattern
  Method: Playwright triggers login → 2FA email arrives → Gmail MCP search_threads(from:{sender}) → extract first 6-digit number from plaintextBody → Playwright submits code
  Tested: 2026-05-05 (workspace: etf-tracker, M1 Finance)
  Re-verify by: 2026-11-05
  Notes: Requires email forwarding from service account to {{HELM_GMAIL_ACCOUNT}} (instance owner's Gmail, accessible via Gmail MCP). M1: sender is no-reply@login.m1.com, subject contains "one-time passcode". Code arrives within seconds. Extract: first whitespace-surrounded 6-digit number in plaintextBody. 1Password op --reveal flag required to read credentials — without it, returns masked placeholder silently.

M1 Finance margin maintenance requirement via GraphQL
  Method: Login via Playwright (credentials: PAP Vault {{M1_VAULT_ENTRY}}) → intercept JWT from request headers → POST to https://lens.m1.com/graphql with DiscoverSearch operation
  Tested: 2026-05-07 (workspace: etf-tracker, Loop 21)
  Re-verify by: 2026-11-07
  Notes: DiscoverSearch query returns maintenanceMargin (decimal, e.g. 0.25 = 25%) and isMarginable (bool) for any ticker symbol. JWT valid ~24 hours — capture once, batch all tickers. No page navigation per ticker needed. 2FA not triggered on known device sessions; Gmail 2FA pattern available as fallback. GraphQL variables: {query: TICKER, first: 3, filterTypes: ["EQUITY_SECURITY","FUND_SECURITY","SYSTEM_PIE","USER_PIE"], filterStatuses: ["ACTIVE"]}. When isMarginable=false, maintenanceMargin=1.0 (100%) — treat as "not eligible", show as N/A. Confirmed for all 15 ETF tracker tickers: 14 at 25%, ECAT not marginable.
  SCHEDULER NOTE (Loop 21 PUSHBACK): JWT expires ~24 hours. Monthly production pull must re-login at run start — do not cache JWT across runs. M1 is the only source requiring a live login session.
  OPEN: Cold-session 2FA not yet end-to-end tested. Known device skipped 2FA in Loop 21. Gmail 2FA fallback is proven but production cold-session recovery untested.

Morningstar CEF /performance pages via Firecrawl (total return rows)
  Method: Firecrawl.scrapeUrl("https://www.morningstar.com/cefs/{exchange}/{ticker.lower()}/performance")
  Tested: 2026-05-07 (workspace: etf-tracker, Loop 19)
  Re-verify by: 2026-11-07
  Notes: Returns "Investment (Price)" annual rows (up to 5 years) and "Total Return % (Price)" trailing rows
    for all CEF tickers. Exchange codes: xnys (NYSE), xase (AMEX), arcx (NYSE Arca). WARNING: same ticker
    may have different exchange codes on /performance vs /quote — e.g., NBXG uses arcx on /performance but
    xnys on /quote. Parse defensively: limit to first len(years)+1 columns to avoid garbage from complex
    markdown tables with embedded multiple tables. Values match Tiingo adjClose within 0-2% (expected:
    different as-of dates). ETF performance pages use morningstar.com/etfs/{exchange}/{ticker}/performance.
    Confirmed for: FSCO, ACV, CLM, CRF, NBXG, ECAT, GOF (7 CEFs). No login required via Firecrawl.

Morningstar /risk page risk statistics via Firecrawl (std dev, alpha, beta, R2, Sharpe)
  Method: Firecrawl.scrapeUrl("https://www.morningstar.com/etfs/{exchange}/{ticker.lower()}/risk")
         or /cefs/{exchange}/{ticker.lower()}/risk for CEFs
  Tested: 2026-05-07 (workspace: etf-tracker, Loop 20)
  Re-verify by: 2026-11-07
  Notes: Returns Standard Deviation, Alpha, Beta, R2, Sharpe Ratio in the "Risk & Volatility" section.
    Markdown format: `| Standard Deviation | 13.12 | 13.47 | 13.40 |` (3-year, 5-year, 10-year columns).
    Confirmed for SPY (SD=13.12) and CLM CEF (SD=13.17). ETF exchange codes: arcx (NYSE Arca), xnas (NASDAQ).
    CEF exchange codes: xnys (NYSE), xase (AMEX). Stock /risk pages do NOT exist (404) — only ETF/CEF.
    These statistics REPLACE Tiingo's computed volatility — use this source for all ETFs and CEFs.
    No login required via Firecrawl.

Monarch Money login via Mac Mini Playwright (non-headless + email OTP)
  Method: python3 monarch_e2e_login.py (non-headless Playwright on Mac Mini) → login with PAP Vault {{MONARCH_VAULT_ENTRY}} credentials → detect mfaStage=email_otp in URL → write /tmp/monarch_otp_wait.txt signal → poll /tmp/monarch_otp_code.txt → submit code → confirm redirect to /dashboard
  Tested: 2026-05-14 (workspace: financial-review, Phase A)
  Re-verify by: 2026-11-14
  Notes: CRITICAL: Must run on Mac Mini (residential IP), not VPS (data center IP blocked by Monarch). Non-headless mode required — headless Playwright on any host triggers fingerprinting. OTP email sender: account@email.monarch.com; delivered to {{MONARCH_EMAIL}} which is accessible via Gmail MCP ({{HELM_GMAIL_ACCOUNT}}). OTP code appears in email subject "Your code is NNNNNN" — extract 6-digit code directly from subject snippet. File handoff pattern: script writes /tmp/monarch_otp_wait.txt when on OTP page; external process writes 6-digit code to /tmp/monarch_otp_code.txt; script polls every 2s up to 90s. Full e2e confirmed: login → OTP interception → dashboard redirect. Credentials: PAP Vault {{MONARCH_VAULT_ENTRY}} (username={{MONARCH_EMAIL}}). VPS attempts fail at API login endpoint with 429 regardless of rate-limit spacing — data center IP is the root cause.

ScheduleWakeup for long-wait scenarios (>10 min) 🔬 UNVERIFIED IN SUBPROCESS CONTEXT
  Method: ScheduleWakeup tool with delaySeconds set to actual wait duration; pass same prompt via `prompt` parameter
  Tested: 2026-05-14 — pattern VALIDATED (financial-review Monarch rate limit confirmed polling is wrong); subprocess EXECUTION NOT TESTED
  Re-verify by: N/A — move to PROVEN only after a workspace agent (claude -p) actually calls ScheduleWakeup and resumes correctly
  ⚠️ WARNING: ScheduleWakeup appears as a deferred tool in the system-reminder. Whether it is accessible to workspace subprocess invocations is unconfirmed. Do not treat as PROVEN until a workspace agent executes it and wakes up correctly.
  Notes: Use when a workspace agent needs to wait >10 min before continuing (rate limits, API cooldowns, external delays). NEVER use checkpoint-exit-polling for long waits — post_exit_resume fires every 5 min, so a 60-min wait triggers 12 resumes and always hits the 2-attempt guard. ScheduleWakeup sleeps for the actual duration and wakes once. Do NOT confuse with CronCreate (recurring schedules) — ScheduleWakeup is for one-time deferred wake-ups. For autonomous /loop sessions, use sentinel `<<autonomous-loop-dynamic>>` as the prompt value.

Mac Mini filesystem R/W
  Method: standard bash (cat, echo, cp, mv, mkdir, rm)
  Tested: May 3, 2026
  Notes: Agents have full read/write. ~/.claude/agents/ write access unconfirmed — TEST THIS.

Agent chaining via handoff.json
  Method: agent writes ~/pap-workspace/handoff.json, bot.js polls every 5s
  Tested: May 3, 2026 (built, needs clean end-to-end retest)
  Notes: Race condition risk — atomic write not yet implemented

Briefing outbox delivery
  Method: write ~/pap-workspace/briefing-outbox.txt, bot.js polls every 10s → posts to #general
  Tested: May 3, 2026
  Notes: Working

Conversation memory
  Method: ~/pap-workspace/history/history-[channelId].json, last 10 exchanges prepended
  Tested: May 3, 2026
  Notes: Survives bot restarts. Confirmed working.

Local desktop app (Windows + Mac) via Python Flask + self-signed cert
  Method: Python venv + Flask + pinned self-signed cert (cryptography lib); cert generated once at ~/.options-helper/server.crt
  Tested: 2026-05-21 (workspace: options-helper, live user testing)
  Re-verify by: 2026-11-21
  Notes: Windows data dir: %APPDATA%\options-helper\. Mac data dir: ~/.options-helper/.
    CRITICAL: ssl_context='adhoc' (pyopenssl) fails — generates new cert every startup → ERR_TIMED_OUT in browser.
    Use cryptography lib to generate cert ONCE and pin it.
    Windows Python 3.14: PYTHONUTF8=1 env var required for subprocess encoding; ASCII-only log strings mandatory (cp1252 crash otherwise).
    Browser caching: serve index.html with Cache-Control: no-store to prevent stale UI after reinstall.
    macOS: Security > Privacy > Open Anyway required (quarantine xattr); execute bits may not survive zip/unzip.
    Windows installer: use VBScript wrapper (Run cmd /c bat, hwnd=0) to hide terminal window. Bundled pip wheels avoid network install.
    Zip builds: delete old zip before rebuilding (zip on macOS appends, not replaces).

Schwab Individual Trader API (OAuth2 + positions + option chains)
  Method: OAuth2 at https://api.schwabapi.com/v1/oauth/; positions at BASE_TRADER/accounts/{hash}/positions; option chains at BASE_MKT/chains
  Tested: 2026-05-21 (workspace: options-helper)
  Re-verify by: 2026-11-21
  Notes: CRITICAL: Refresh tokens expire after 7 days. Cannot be automated — requires real browser OAuth flow.
    App must be registered at developer.schwab.com; approval takes minutes to hours.
    Callback URL must be pre-registered in the developer portal exactly as used in code.
    Local callback: https://127.0.0.1:5000/callback (requires pinned self-signed cert — see above).
    VPS callback: https://yourdomain.com/callback (standard Let's Encrypt cert works).
    Re-auth before 7-day window expires immediately revokes old token (expected behavior, looks like early expiry).
    Token warning cron: set up at 9am UTC to alert when <5 days remain.
    Rate limits: not hit in normal use (single user, <300 tickers/scan).
    Greek data: delta, theta, IV available in option chain response. Reliable.

---

## FAILED CAPABILITIES

Format: capability | method tried | date | reason | retryable?

Morningstar Risk rating scraping (plain Playwright / curl methods)
  Tried: yfinance .info, Yahoo Finance quoteSummary (6 modules), StockAnalysis.com curl, Morningstar.com curl, Playwright headless on VPS, ETFdb.com curl
  Failed: 2026-05-05 (etf-tracker Loop 10)
  Reason: Morningstar is Cloudflare-protected; headless Playwright returns Cloudflare challenge page (HTTP 200, 1.1MB, no data). Yahoo Finance API does not expose Morningstar risk in any documented module. No free aggregator surfaces this field.
  Retryable: No for these methods. CORRECTION: Firecrawl DOES bypass Cloudflare on Morningstar — see PROVEN section (Morningstar Portfolio Risk Score via Firecrawl).

Morningstar stock/REIT pages via authenticated Playwright
  Tried: Playwright headless login (PAP Vault credentials) → navigate to stock pages in same session;
         Playwright login → extract cookies → pass to Firecrawl
  Failed: 2026-05-07 (workspace: etf-tracker)
  Reason: Two blockers: (1) Morningstar's login page itself now serves hCaptcha to headless browsers
    on subsequent requests (first cold session sometimes works but not reliably); (2) passing
    Playwright session cookies to Firecrawl triggers AWS WAF security check — token is
    browser-fingerprint-bound so it rejects requests from a different IP/TLS fingerprint.
    ETF/CEF pages work via Firecrawl without auth. Stock/REIT pages require login AND
    headless browsers are blocked at login by bot detection.
  Retryable: Only with non-headless browser (GUI session) or Morningstar API key (paid).
  Impact: OHI/MPLX/MAIN risk and performance pages unavailable without auth. But /quote pages
    for stock tickers ARE accessible via Firecrawl — see PROVEN section below.

Morningstar stock /risk and /performance pages (URL pattern)
  Tried: Firecrawl on morningstar.com/stocks/{exchange}/{ticker}/risk and /performance
  Failed: 2026-05-07 (workspace: etf-tracker)
  Reason: These URL paths return 404 for stock tickers. The /risk, /performance, /portfolio page
    sub-paths only exist for ETFs (morningstar.com/etfs/) and CEFs (morningstar.com/cefs/).
    Stocks only have /quote and /chart sub-pages publicly accessible.
  Retryable: No — URL pattern does not exist for stocks on Morningstar.

FMP free tier for ETF fundamentals (P/E, equity%, holdings count)
  Tried: FMP v3 etf-info, etf-holdings, key-metrics endpoints; FMP stable tier quote endpoint
  Failed: 2026-05-05 (workspace: etf-tracker)
  Reason: FMP v3 endpoints deprecated (403). Stable tier returns quote/price data only — ETF-specific endpoints require paid plan. marketCap available but P/E, equity%, bond%, holdings count not accessible on free tier.
  Retryable: Yes if paid plan. Free alternatives: Alpha Vantage ETF_PROFILE (AUM, expense ratio, sectors) + yfinance (P/E).

Discord rich components (buttons, select menus)
  Tried: discord.js component API
  Failed: Not yet attempted — flagged as 🔴 assumption in Loop 7
  Retryable: Yes — needs Phase A test before Loop 7

Direct Sheets via Drive MCP
  Tried: Google Drive MCP file read on .xlsx/.gsheet
  Failed: Returns file metadata, not cell data
  Reason: Drive API ≠ Sheets API
  Retryable: No. Use pap-sheets.sh.

discordmcp
  Tried: v-3/discordmcp MCP server
  Failed: Messages never arrive in Claude Code v2.1.123
  Retryable: Only if Claude Code version changes

Anthropic API direct calls
  Tried: /v1/messages with API key
  Failed: Separate billing from Pro subscription
  Retryable: No

Anthropic API usage reporting (/v1/usage)
  Tried: GET /v1/usage with valid API key ("Claude API" in PAP Vault)
  Failed: 404 — endpoint does not exist. Anthropic has no public usage API.
  Tested: 2026-05-31 — key IS valid (models endpoint returns 10 models)
  Retryable: No — usage data only available via Anthropic console or claude-usage skill (scraping)
  Notes: Vault entry is "Claude API" (field: password). Key works for SDK calls (/v1/messages, /v1/models).

settings.json / mcp.json Composio
  Tried: Adding Composio to settings.json and mcp.json
  Failed: Not read by claude -p subprocesses
  Retryable: No

--add-dir routing
  Tried: claude -p --add-dir [agents/] for multi-agent routing
  Failed: All agents respond simultaneously → duplicate messages
  Retryable: No. Routing belongs in bot.js only.

---

## UNTESTED — HIGH PRIORITY

These are assumed to work but have NOT been tested in PAP.
Any workspace that needs these must run Phase A first.

Web scraping (JS-rendered pages)
  Assumption: Will require headless browser or scraping service
  Risk: 🟡 — proven methods exist for some sites; new sites still need Phase A
  Proven: Firecrawl bypasses Cloudflare on Morningstar (see PROVEN). Playwright headless works on cefconnect.com with domcontentloaded+5s (see PROVEN).
  Test: curl the target URL first; if blocked or empty, try Firecrawl before Playwright
  Candidates to evaluate for new sites: Firecrawl (PROVEN on Cloudflare sites), Playwright (PROVEN on non-Cloudflare JS sites), Browserless.io, Computer Use

Web scraping (static HTML pages)
  Assumption: curl + parser will work
  Risk: 🟡
  Test: curl -s [url] | grep [data point]

Video/audio transcription
  Assumption: Requires local Whisper install or API
  Risk: 🔴
  Test: which ffmpeg && which whisper
  Candidates to evaluate: whisper.cpp, faster-whisper, OpenAI Whisper (API — paid), AssemblyAI free tier

YouTube transcript extraction via yt-dlp (Phase 2 — PROVEN)
  Method: pip3 install yt-dlp --break-system-packages on VPS; then:
    yt-dlp --write-auto-subs --sub-lang en --skip-download --output '/tmp/yt_%(id)s' '[URL]'
    Parse .en.vtt file: strip timestamps, XML tags, deduplicate overlapping lines
  Tested: 2026-05-07 (second-brain YouTube intake)
  Re-verify by: 2026-11-07
  Notes: Auto-generated captions available on most YouTube videos (not live streams). Returns .en.vtt
    format — needs post-processing to strip <00:00:00.000> tags and deduplicate overlapping caption lines.
    No Whisper, no audio download, no ffmpeg required. VPS Python 3.12 — use --break-system-packages for
    pip install (PEP 668 restriction). JavaScript runtime warning appears but does not prevent transcript 
    download. No caption fallback: if no auto-captions, yt-dlp exits with no .vtt file.

PDF reading
  Assumption: May work via Drive MCP or needs local tool
  Risk: 🟡
  Test: Read a PDF via Drive MCP, check if text is extracted

Attachment handling end-to-end
  Assumption: Bot receives attachments, passes URL to agent
  Risk: 🟡 — coded in bot.js but untested
  Test: Send a file to Discord, verify agent receives content

Self-editing agent files (Marvin edits ~/.claude/agents/)
  Assumption: claude -p subprocesses have write access to ~/.claude/
  Risk: 🟡
  Test: touch ~/.claude/agents/test-write.md from within a claude -p call

Scheduled task execution
  Assumption: launchd or Cowork-based scheduler — NOT YET BUILT
  Risk: 🔴 — no scheduler currently implemented
  Required: Architecture decision + build before any workspace goes live

---

## CONNECTOR EXPANSION PATTERN

Any new authenticated service follows this pattern:
1. Deploy a serverless function (Google Apps Script preferred — free, no Cloud Console)
   OR identify a public API endpoint that doesn't require auth
2. Function accepts simple JSON input, handles auth internally
3. Create bash wrapper at ~/pap-workspace/scripts/[service].sh
4. Store URL and secret in CONFIG.md (not hardcoded in wrapper)
5. Add to helm-config GitHub repo for rebuild resilience
6. Test via Phase A before any workspace uses it

Reference implementation: pap-sheets.sh

---

## SELF-IMPROVING SKILLS LOOP — LIMITATIONS

When using evals (evals.json) to test skills, binary assertions verify that a skill
follows rules — they do NOT guarantee output quality if the rules themselves are wrong
or too generic.

**Limitation:** Passing all assertions does not mean the skill is effective.
Assertions test compliance with declared expectations, not tone, relevance, or judgment.
Human review is required for quality, especially for subjective outputs (writing, advice, design).

Use evals for regression testing (did a change break known behavior?) not for
certifying that outputs are actually good. A 100% pass rate with badly-written
assertions = false confidence.

**The distinction:**
- Assertions PASS: "output contains PUSHBACK field" — structural compliance
- Assertions CANNOT check: "PUSHBACK is actually useful and specific" — quality judgment

This limitation applies to any automated eval loop, including PAP skill iteration.

---

## NOTES FOR AGENTS

- Read this file at the start of every Phase A involving an unfamiliar capability
- If a capability you need isn't listed: use solution-researcher skill
- If a capability is PROVEN: still run a quick sanity test before building
- If a capability is FAILED: read the reason carefully before deciding to retest
- After every Phase A: update this file. It is only useful if it is current.
