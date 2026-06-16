# DES-ONBOARD-FLOW — PAP Onboarding Design
# Working version — started from {{USER_JERRY}}'s original script, modified based on Session decisions
# Last updated: 2026-05-30

---

## Confirmed Design Decisions (locked)

- No terminal use for users — Claude Code/Desktop handles GitHub pull
- Pre-bootstrap = AI prompt user pastes into Claude (machine-specific guidance)
- Recovery service is invisible during setup, introduced in Discord tour
- Workspace naming: free-form, reserved channel names blocked at creation
- Validation tests: lightweight at end of onboarding + full suite post-update (Option C)
- Recovery button: Discord-as-bridge (recovery service holds own Discord connection)
- Workspace agent resumption after revert: fully automatic, user does nothing
- One user per machine (multi-user deferred to Phase 2)
- GitHub backup set up before any workspace is created
- **Daily briefing = first workspace** — goes through full curiosity → scaffolding → HMW → BML cycle. Users design their briefing; PAP doesn't impose a default.
- **Email/calendar: comfort gate first** — Ask "comfortable sharing?" + explain value before asking which providers. If no, skip entirely (set up later in #preferences).
- **Best-practices research gate** — Every curiosity session researches domain best practices (outcomes, not solutions) before scaffolding. User sees options, decides what they want. This applies to ALL workspaces, not just briefing.

---

## PHASE 0: Pre-Install (Machine Setup via AI Prompt)

User does NOT touch a terminal. Instead, they paste a prompt into Claude Desktop.

### The Prompt (user copy-pastes this)

```
I'm setting up PAP, a personal automation platform. I need help getting my machine ready.

My machine is: [daily laptop / Mac Mini / Windows laptop model XXX / VPS]

Please walk me through:
1. How to wipe and reset this machine (if needed)
2. How to install Claude Desktop
3. How to run the PAP install command from GitHub

I'm not very technical, so please explain each step clearly and let me ask questions.
```

### What Claude Does

- Detects machine type from user's input
- Provides step-by-step instructions for that exact machine
- Walks through wipe → Claude Desktop install → GitHub install command
- User can ask questions, Claude answers in plain English
- Final step: "Run this command in Claude Desktop: [GitHub install command]"
  - Claude Code handles the GitHub clone/bootstrap automatically
  - No terminal knowledge required from user

---

---

## PHASE 0.5: Infrastructure Choice

Before bootstrap begins, HELM asks where it will run. The answer determines what gets installed.

```
Where will HELM run?

→ [On my computer only]
→ [On a cloud server]
→ [Both — cloud server + this computer] ← recommended
```

**Tradeoff explanations (shown to user before they choose):**

**On your computer only**
- No cost. Simple setup. Data stays local.
- Downside: HELM stops when the machine sleeps or shuts down.
  A morning briefing set for 8am won't run if you powered off at midnight.
  Best for: testing, light use, or if you always leave your computer on.

**Cloud server (VPS)**
- HELM runs 24/7. Reliable automations. Accessible from anywhere.
- Downside: ~$5-10/month (DigitalOcean, Hetzner). 20 min setup.
  Best for: daily automations, briefings, anything time-sensitive.

**Both — cloud server + this computer** ← recommended
- Cloud server handles your daily automations reliably.
  Your computer adds desktop-control (Playwright, screen reading, local apps)
  and acts as fallback if the cloud server goes down.
- Same VPS cost. Slightly more setup (~30 min total).
  Best for: full feature set + maximum reliability.

---

### If user chooses VPS or Both: VPS Setup Step

```
To set up your cloud server, you'll need:

1. A DigitalOcean or Hetzner account
   → Choose the cheapest Ubuntu 22.04 droplet/server (~$6/mo)
   → Takes about 5 minutes to create

2. An SSH key (to log in securely)
   → If you've never set one up, we'll walk you through it — takes 3 minutes

Once your server is ready, paste the IP address here and we'll take it from there.
```

**What HELM does from there:**
- Connects to the server
- Installs all dependencies (Node.js, Python, bot.js)
- Configures watchdog and recovery service
- Runs automated tests
- Confirms it's running

User never touches the command line. All setup is guided.

**Reference pattern for VPS setup:** Ubuntu 22.04 on DigitalOcean or Hetzner (~$6/mo).
DNS A-record + SSH key is all that's needed before HELM takes over.
(Pattern established in options-helper SETUP.md — same VPS model works here.)

---

## PHASE A: Bootstrap (runs automatically, ~20 min)

*This section mirrors {{USER_JERRY}}'s original script structure — user sees progress messages,
not technical steps.*

**What runs silently:**
- Clone repo from GitHub
- Install dependencies
- Configure MCP servers
- Install and test recovery service (watchdog)
- Set machine to never sleep
- Run automated tests
- Confirm recovery service is running and monitoring
- Commit test results to GitHub

**What user sees during this time:**
```
PAP is setting up your system. This takes about 20 minutes.
I'll let you know when it's ready. You can close this window.
```

---

## PHASE B: Discord Setup + Credentials

*Mirrors {{USER_JERRY}}'s original script B1-B16 with these modifications:*

### B1 — Discord Server Setup
Discord server is created manually by user (bot walks them through creating a server
and inviting the bot via OAuth link). Bot cannot create Discord servers programmatically.

Bot sends:
```
Welcome! Let's set up your Discord server.
[Link: Create a new Discord server] → step-by-step walkthrough
```

### B2-B16 — Credentials + Preferences
*(Unchanged from {{USER_JERRY}}'s original script — every step has a reason, don't modify.)*

Key: GitHub OAuth happens here, before any workspace is created.
First commit to backup repo is the baseline — nothing can be lost.

---

## PHASE C: Discord Tour (5 stops)

Runs after credentials are set up and first briefing is configured.
Order: general → daily-brief (or user's chosen name) → preferences → recovery → help.

### Stop 1 — #general
```
This is your main workspace. Ask questions, start automations, get status updates.
Think of it as texting your assistant.
```

### Stop 2 — #[user's workspace name]
*(Bot uses the workspace name the user chose during setup, not hardcoded "daily-brief")*
```
Your first workspace. Every morning, it checks your calendar, emails,
and whatever you told it to watch.
You can customize what it covers anytime in #preferences.
```

### Stop 3 — #preferences
```
Change any setting here — notification level, daily brief time, what your
workspace monitors. Just describe what you want.
```

### Stop 4 — #recovery
```
Your safety net.
If something breaks, PAP tries to fix it automatically — you usually won't
know it happened. If it can't fix it, you'll see a message here with a button.
Just tap Yes or No. That's all you ever need to do.

Also: before any PAP update, your work is saved automatically.
If an update ever goes sideways, PAP can roll back to the previous version.
You don't have to do anything — it's handled.
```

### Stop 5 — #help
```
Questions about how anything works? Post here.
Something not right? Post here. I'll respond directly.
```

---

## PHASE D: Daily Briefing Workspace — First Workspace Setup

Daily briefing is NOT configured during onboarding. It's treated as a full workspace — the very first one — and goes through the same curiosity → scaffolding → HMW → BML cycle as every other workspace.

### D1: Data Sharing Comfort Gate

Before anything else, PAP asks ONE question:

```
Before we set up your first workspace, I want to ask about your data.

If you approve, PAP can read your calendar and email to include them in your briefing —
so you'd see what's coming today, who you need to reply to, and what's time-sensitive.
PAP will never send emails or calendar invites on your behalf. Read-only.

Are you comfortable connecting your calendar and email?
→ [Yes, let's connect them] [Not yet — skip for now]
```

**If no:** Skip to D3. User can connect later via #preferences. Briefing runs with whatever data sources they enable later.
**If yes:** Continue to D2.

*(No provider questions here — those happen inside the daily-briefing workspace curiosity phase, where the workspace agent asks the right questions in the right order.)*

### D2: Kick Off Daily Briefing Workspace

```
Let's build your morning briefing.

I'll ask you a few questions to understand what would actually be useful for you —
then we'll set it up together. This usually takes 10-15 minutes.
Before you have a working briefing, you'll design what goes in it — then we build it.
```

The daily-briefing workspace agent takes over from here. Full curiosity → scaffolding → HMW → BML loop. Includes:
- Best-practices research (what makes a morning briefing actually useful — patterns and outcomes, not defaults)
- Provider selection (email, calendar, news, tasks — user chooses what connects)
- Design (what shows, in what order, how long it should be)
- First run validation

### D3: Validate First Run

At the end of the daily-briefing workspace BML loop:

```
Here's what your [workspace name] found this morning:

[First briefing — real data if connected, demo if skipped]

Does this look right?
→ [Yes, it's working] [Something's off]
```

If user taps [Yes]: onboarding complete.
If user taps [Something's off]: help agent asks what's wrong and troubleshoots.
If user skipped all sources (D1 = no): shows demo briefing with note: "Connect calendar and email in #preferences to see real data here."

---

## PHASE E: Quick Settings (Optional)

```
Two quick settings before we're done (you can change these anytime):

Auto-update PAP?
[Yes, apply automatically] [No, ask me first]

Notifications?
[Minimal — errors only] [Normal] [Everything]

→ [Done] [Skip for now]
```

---

## PHASE F: Done

```
You're all set.

Your [workspace name] runs every morning at [time they chose].
Your data backs up to GitHub automatically every night.
If anything breaks, your safety net handles it.

→ #help for questions
→ #preferences to change settings
→ #recovery if you ever see an alert there
```

---

## DAILY BRIEFING CONTENT DESIGN (Reference for Curiosity Phase)

This section is input for the curiosity agent, NOT a user-facing configuration flow.
When the daily-briefing workspace curiosity session runs, it researches best practices and presents options — this is the reference for what those options might include.

### What PAP can include in a daily briefing

**Core (high value, fast to set up):**
- Today's calendar events + prep notes for meetings
- Important emails (unread, flagged, from VIPs)
- Today's tasks (from Todoist, Things, Notion, etc.)
- Weather for your location

**Informational (pick any):**
- News (user picks up to 3 topics — tech, business, sports, health, etc.)
- Stock watchlist movers / portfolio summary
- Upcoming birthdays and anniversaries
- Bill due dates approaching

**Optional / power user:**
- Health metrics (Oura, Fitbit, Apple Health — if connected)
- Sports scores for your teams
- Habit streak check
- Learning: language practice reminders, reading progress

### Best practices for effective daily briefings (curiosity-phase research input)

1. **Lead with time-sensitive** — meetings in the next 2 hours, deadlines today, urgent emails
2. **New info only** — don't repeat yesterday's events or last week's news
3. **Scannable** — bullets, bold names/dates/amounts, no paragraphs
4. **2-3 minute read** — if it takes longer, it won't get read
5. **Graceful degradation** — show something even if sources are offline, never a blank screen
6. **Adapts to day type** — weekends skip work tasks; Mondays include a weekly overview
7. **Actionable** — every section has at least one "here's what to do" item
8. **Progressive** — start with what's connected; add sources over time without rebuilding

### Design principle: "Always show something"

Demo/mock briefing if user skipped all source connections. Note to connect in #preferences.
Blank screen at first run = user thinks it's broken.

---

## BEST-PRACTICES RESEARCH GATE (All Workspaces)

### What it is

Before any workspace scaffolding begins, the curiosity agent researches domain best practices
and presents them to the user — framed as outcomes and patterns, not solutions or defaults.

The question isn't "what should your briefing have?" (that's forcing a solution).
The question is "what makes a morning briefing actually useful?" — then let the user react.

### How it works

1. **Curiosity agent researches** — looks up what works in this domain (outcomes, patterns)
2. **Presents options with context** — "People who get the most from daily briefings tend to..."
3. **Asks the user what resonates** — "Which of these sounds like you?"
4. **Designs to their answer** — spec is built from their choices, not from defaults

### Scope question (not yet locked)

⚠️ OPEN: Is best-practices research mandatory for ALL curiosity sessions, or conditional
(only when strong domain best practices exist)?

- Daily briefing, dashboard, tracker → strong best practices exist ✅
- Custom automation → best practices may be domain-specific to the user ❓
- Simple notification rule → best practices research might be overkill ❓

Decision needed: mandatory everywhere, or conditional on domain type?
This is being discussed in #pap-improvements (thread: "Curiosity Protocol: Best-Practices Research Gate").

---

## Open Questions (not yet locked)

*(none — all open questions resolved this session)*

## Resolved Decisions (locked this session)

- **Claude Code as installer PoC** — PASSED. Claude Code executes `git clone` and bash scripts natively. No terminal fallback needed. No-terminal install design is confirmed go.
- **Infrastructure gate added** — Phase 0.5 added between pre-install and bootstrap. Three paths: local only, VPS only, Both (cloud-primary + local-backup). "Both" is the recommended default.
- **Hybrid model: cloud-primary, local-backup** — Primary on VPS (always-on); local machine adds computer-control features + failover. Not the reverse.

- **Workspace name in tour** — Tour uses user's chosen name dynamically.
  Bot reads workspace name from config at tour time.
- **GitHub backup timing** — GitHub OAuth + repo creation in B-phase before workspace creation.
  First backup commit is the baseline.
- **Pre-install prompt location** — GitHub pages. One page per OS/machine type.
- **Pre-update snapshot** — Mentioned in Stop 4 (#recovery tour). Plain English: "before any
  update, your work is saved automatically."
- **A4.5 settings step** — Keep it. User chooses auto-update + notification level.
- **Multi-provider email/calendar** — Asked inside daily-briefing workspace curiosity phase, not during onboarding. Support: Gmail, Outlook, Apple Mail, IMAP, CalDAV.
- **Non-email/calendar briefing** — News, weather, tasks, finance, health, sports (all optional, user decides during workspace curiosity phase).
- **"Always show something"** — If user skips all sources, show mock briefing with note to connect sources in #preferences.
- **Daily briefing = first workspace** — Full curiosity → scaffolding → HMW → BML. Not a default setup step.
- **Email/calendar comfort gate** — One question during onboarding. Yes = enter daily-briefing workspace. No = skip, connect later.
- **Best-practices research gate** — Part of every curiosity session before scaffolding. Scope (mandatory vs. conditional) being decided in #pap-improvements thread.

---

## Recovery Service Integration Points

Changes from {{USER_JERRY}}'s original script:

1. **Bootstrap** — Add to install list: "Install and test recovery service (watchdog)"
   and after tests: "Confirm recovery service is running and monitoring"

2. **Tour (Stop 4)** — Plain English recovery explanation (see Phase C above)

3. **Recovery button mechanism** — Discord-as-bridge:
   - Recovery service maintains its own Discord connection, independent of bot.js
   - If bot.js goes down, recovery service can still post to Discord and receive button taps
   - User taps "Fix it" in #recovery → recovery service receives it directly → restarts bot.js
   - No SSH, no tokens, no external URLs — just Discord (user is already authenticated)

---

## What We're Not Changing from {{USER_JERRY}}'s Original

- Credential security flow (PAP Vault → local encrypted fallback)
- Resumption at every step (ONBOARDING_STEP checkpoint)
- Error recovery pathways at each step
- The warmth and non-technical tone of the messaging
- The ordering of steps (GitHub before workspace, workspace before tour, tour before settings)
- The final sample briefing as end-to-end validation

