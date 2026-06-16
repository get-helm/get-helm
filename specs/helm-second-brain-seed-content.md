# HELM — Second Brain Seed Content
## What HELM knows from day one

This document is the initial content for the help agent's knowledge base.
It covers: what HELM can do, how to use it, common questions, workspace examples, and preferences.

Status: DRAFT — for {{USER_JERRY}}'s review before treating as canonical.

---

## PART 1: What HELM Can Do (Capabilities by Category)

### Automations and Workspaces

HELM builds automations for you through workspaces — dedicated channels where it manages a project end-to-end.

**What a workspace can do:**
- Monitor a data source (prices, inboxes, calendars, APIs) and alert you when something changes
- Generate scheduled reports (daily, weekly, on a schedule)
- Track and summarize data across multiple sources
- Build a custom tool you can interact with through Discord
- Automate a repetitive task so you never have to do it again

**How to start one:** Post in #new-workspace. Describe what you want to happen — the problem, not the solution. HELM will clarify what it needs and propose a plan before building anything.

**Examples of workspaces people build:**
- "Alert me when any of my options positions are within 10% of margin"
- "Every morning, show me what needs attention across my three brokerages"
- "Track the ETFs I'm watching and flag when they cross my entry prices"
- "Summarize my unread emails into a daily digest at 7am"
- "When my calendar has a gap, send me a suggested focus block"
- "Monitor a list of job postings and alert me to new matches"
- "Weekly report of my net worth across all accounts"
- "Capture anything I send to #capture and surface connections each Monday"

---

### Research and Analysis

HELM can research any topic, synthesize information from multiple sources, and produce summaries, comparisons, or recommendations.

**Ask HELM to:**
- Research a topic and summarize what matters
- Compare two options and give a recommendation
- Find the best tools for a job (with pros/cons)
- Analyze a document or file you share
- Pull data from a website or public source and organize it

**HELM will always show its sources.** If it can't verify something, it says so.

---

### Second Brain

Everything you save to #capture goes into your second brain. HELM can search it and surface connections.

**How to save something:**
- Drop a URL in #capture → HELM reads the page and saves a summary
- Paste text in #capture → HELM saves it and tags it
- Share an image or file → HELM extracts the key content

**How to search it:**
- "What did I save about [topic]?"
- "Find everything I've captured about [person/company/idea]"
- "What connections do you see between [topic A] and [topic B]?"

**Second brain surfaces automatically in:**
- Morning briefings (relevant context for today's calendar)
- When starting a new workspace (prior thinking on similar topics)
- Weekly "connections" summary (patterns HELM noticed)

---

### Connected Tools (when set up during onboarding or in #preferences)

**Google Calendar:**
- Read: Show today's schedule, find open time, detect conflicts
- Write: Create events, update events, set reminders

**Gmail:**
- Read: Summarize unread, find a specific email, search by sender/topic
- Draft: Compose a reply or new email for your review

**Google Drive:**
- Read: Find files, summarize documents, extract data from sheets
- Write: Create documents, update spreadsheets, organize files into folders

**Web research:**
- Search the web and summarize results
- Read any public URL and extract key content
- Monitor a URL for changes (with a workspace)

**Computer Use (clean machine only):**
- Log into sites that don't have APIs
- Extract data from apps that can't be integrated directly
- Fill out forms on your behalf

---

### Daily Briefing

HELM posts a briefing every morning at your configured time. Default includes:
- Today's executive summary (what matters today)
- Outstanding decisions waiting for you
- Calendar: today's events, prep needed
- System status: anything wrong or worth knowing

Optional additions (configure in #preferences or at any time):
- Unread email summary (top N by priority)
- Slack messages
- Tasks due today
- News on topics you follow
- Weather
- RSS feeds

**Customizing your briefing:** Just post in #preferences or #general. "Shorten my briefing," "add weather," "stop sending news" — HELM handles the change.

---

## PART 2: How HELM Works (Architecture for Users)

### Channel structure

Every channel has a purpose. You don't need to memorize them — they're labeled. But here's the logic:

**Where you work:**
- **#general** — ask anything, start anything. Main interface.
- **#new-workspace** — describe an automation you want built. HELM takes it from there.
- **#capture** — save anything. URLs, text, images, ideas. Goes into your second brain.

**Where outputs land:**
- Each automation gets its own channel. Results, status, and conversation live there.
- Workspace channels appear under "Active Workspaces" as they're created.

**System channels:**
- **#daily-briefing** — your morning summary, posted automatically
- **#pap-status** — ask "is everything working?" to get a health check
- **#notify** — time-sensitive alerts that can't wait for your briefing
- **#help** — questions about how anything works
- **#feedback** — tell HELM what's working or not
- **#preferences** — change any setting, anytime, in plain language

---

### How HELM makes decisions

HELM operates on an authority scale:

- **Level 0-2:** Acts silently or with a brief note. Reading calendar, running a search, formatting a report.
- **Level 3:** Acts and notifies you. Creating a workspace, changing a system-wide setting.
- **Level 4:** Stops and proposes. Hard-to-reverse actions, anything with external visibility.
- **Level 5:** Stops and waits for explicit approval + confirmation. Constitutional changes.

You set where each category falls in #preferences (or during onboarding in the Trust Levels step).

---

### What HELM won't do without your explicit approval

- Move money or make financial transactions
- Send emails on your behalf (it drafts, you send)
- Delete workspaces or files
- Access any account not in PAP Vault
- Retry a failed login (one attempt, then it blocks and tells you)

These rules are permanent and cannot be overridden — even if you ask.

---

### How HELM handles mistakes

HELM flags its own uncertainty before acting, not after. If it's not confident:
- It says so with 🔬 (unverified — needs checking)
- It proposes and waits rather than acting
- It explains what it knows and what it doesn't

If HELM makes a mistake: post in #feedback or tell it directly. It logs the pattern and the PM agent surfaces fixes. You never need to debug it yourself.

---

## PART 3: Using HELM Effectively

### How to ask for things

**Better:** "I keep forgetting to check my options positions before market open. Can you make that happen automatically?"
**Worse:** "Build me an options tracker."

The first version tells HELM the real problem. The second tells it the solution you've already decided on. HELM will often find a better solution if you describe the problem.

---

### When to use which channel

**#general** — When you're not sure which channel. HELM routes it. Also good for: quick questions, one-off research, conversational back-and-forth.

**#new-workspace** — When you want something built that will run on its own. A monitor, a report, a tool. If you're thinking "I want HELM to do X automatically," that's #new-workspace.

**#capture** — When you find something worth remembering. Drop it and forget it. HELM handles the rest.

**Workspace channels** — When you want to interact with or update a specific automation. "Change the alert threshold," "add a new ticker," "stop the weekly report."

---

### Giving feedback

👍 and 👎 on messages are the fastest way to improve HELM over time. It tracks patterns, not individual incidents. Three 👎 on the same type of output = the PM agent queues an engineer fix.

Text feedback in #feedback is also good, especially for nuance: "The briefing is too long" or "That proposal missed what I actually wanted."

You never need to explain the underlying cause. Just describe what felt wrong.

---

## PART 4: Preferences Reference

### What's configurable (complete list)

Everything in this list can be changed at any time by posting in #preferences in plain language.

**Communication:**
- Tone: Brief and direct / Conversational / Detailed
- Response length: Short / Medium / Long
- Pushback frequency: Often / When I see a real problem / Rarely

**Information style:**
- Data tables / Visual charts / Reading / Interactive / Mix

**Visual:**
- Display mode: Light / Dark / Match device
- Color palette: Ocean / Warm / Forest / Midnight / Neutral / Custom

**Time and date:**
- Date format: MM/DD, DD/MM, or ISO
- Time format: 12h or 24h
- Week starts: Monday or Sunday
- Timezone

**Working style:**
- When you're most active (affects proactive outreach timing)
- How often HELM reaches out proactively: Often / Daily summary / Rarely
- Quiet hours (no notifications during these times)

**Trust levels (per action category):**
- Reading calendar: Just do it / Tell me after / Ask first
- Changing calendar: Just do it / Tell me after / Ask first
- Reading email: Just do it / Tell me after / Ask first
- Drafting email: Just do it / Tell me after / Ask first
- Reading Drive: Just do it / Tell me after / Ask first
- Writing Drive: Just do it / Tell me after / Ask first
- Web research: Just do it / Tell me after / Ask first

**Usage:**
- Usage warning threshold: 70% / 85% / 95%
- Usage report frequency: Weekly / Monthly / Only if needed
- Cost optimization approach: Show each / Auto-apply small ones / Significant only

**Improvements:**
- Frequency: As they come / Weekly batch / Significant only / Never
- How many at a time: 1 / 3 / 5 / All

**Output:**
- Default file destination: Google Drive (separate) / Google Drive (personal) / Microsoft / Per workspace
- Drive folder: defaults to "HELM" folder

**Briefing:**
- Delivery time
- Sections on/off: calendar, email, Slack, tasks, news, weather, RSS
- Read-time target: 2 / 5 / unlimited minutes

**Standing preferences:**
- Your always-rules: "always include an export option," "always show source data," etc.
- These apply to everything HELM builds

---

### How to change a preference

Just post in #preferences in plain language. Examples:
- "Shorter responses please"
- "Stop sending me the news section in my briefing"
- "Change my quiet hours to 11pm to 6am"
- "Add weather to my briefing, Seattle"
- "I want you to ask me before reading my calendar"
- "Switch to dark mode"

HELM makes the change and confirms. No commands, no syntax.

---

## PART 5: Common Questions

**Q: How do I know if HELM is working?**
Post "is everything working?" in #pap-status. You get a health check in ~30 seconds.

**Q: Something went wrong in a workspace. What do I do?**
Post in #feedback describing what happened. HELM logs it and fixes the class of problem — you don't need to debug anything.

**Q: Can I pause a workspace?**
Yes. Post in the workspace channel: "Pause this until I tell you to resume." HELM stops all scheduled tasks for that workspace and holds them.

**Q: Can I delete a workspace?**
Yes. Post in the workspace channel: "Archive this workspace." HELM stops all tasks, saves a summary of what was built, and archives the channel.

**Q: What happens if HELM makes a mistake?**
It logs it internally. The PM agent tracks patterns and queues engineer fixes. You can also post in #feedback for anything that feels off.

**Q: Can HELM read my personal files?**
Only if you've authorized it. By default, HELM reads from a dedicated HELM folder in Google Drive. You set the scope during onboarding and can change it in #preferences.

**Q: What's the difference between #general and workspace channels?**
#general is conversational. Workspace channels are task-focused — they have context, memory, and files specific to one automation. When you ask about an automation, go to its channel for the best context.

**Q: How do I add a new connection (e.g., Notion, Todoist)?**
Post in #preferences: "Connect Notion" or "Add Todoist." HELM walks you through the OAuth flow.

**Q: What happens if HELM goes offline?**
The watchdog restarts it within 60 seconds. If it's offline for >2 minutes, it posts a notification when it's back online. For longer outages, HELM posts a status update in #pap-status when it recovers.

**Q: Can multiple people use HELM on the same server?**
Today: HELM is built for a single user. Multi-user support is on the roadmap. If you add someone to your server, HELM will interact with them but will use your preferences and credentials.

**Q: How do I know what HELM did while I was away?**
Your morning briefing includes outstanding decisions and any actions taken overnight. #pap-status always has the current state. For a specific workspace, check its channel — HELM posts updates there.

---

## PART 6: Workspace Examples (What Good Looks Like)

### Example 1: Options position monitor

**User said in #new-workspace:**
"I check my options positions every morning before market open. It takes 20 minutes and I always worry I'm missing something."

**What HELM built:**
A workspace that runs at 8:55am ET Monday-Friday. It pulls current positions from two brokerages, checks margin usage, calculates P&L vs. targets, and posts a one-page summary in #options-monitor. If any position is within 15% of margin, it also pings #notify immediately.

**What the user does now:**
Nothing. They see the summary in #options-monitor every morning. If the ping comes to #notify, they know to act.

---

### Example 2: ETF price tracker

**User said in #new-workspace:**
"I have a list of ETFs I'm thinking of buying. I want to know when they cross my target entry price."

**What HELM built:**
A workspace with a simple dashboard at etf.{{USER_DOMAIN}}. It checks prices every 15 minutes during market hours. When a price crosses a threshold, it posts to #notify. The dashboard shows current prices, targets, and % distance for each ETF.

---

### Example 3: Weekly net worth report

**User said in #new-workspace:**
"I want to see my net worth every Sunday evening — across all accounts."

**What HELM built:**
A workspace that runs at 6pm PT every Sunday. It reads balances from connected financial accounts, calculates totals by category (investments, cash, real estate, etc.), and posts a formatted summary in #weekly-snapshot. Includes week-over-week delta.

---

### Example 4: Email digest

**User said in #new-workspace:**
"I get 200 emails a day. I only care about maybe 20 of them. Can you filter and summarize?"

**What HELM built:**
A workspace that reads Gmail every morning before the briefing. It categorizes emails by priority (urgent/follow-up/FYI), generates a 10-line digest, and adds it to the daily briefing. Urgent items also go to #notify.

---

*End of seed content*

**Review notes for {{USER_JERRY}}:**
- Part 1 (Capabilities) and Part 3 (Using HELM Effectively) will need updating as new capabilities ship
- Part 5 (Common Questions) should expand as real user questions emerge
- Part 6 (Workspace Examples) should be updated with real examples from actual users
- This entire document should be versioned — when HELM ships v2 capabilities, which sections change?
