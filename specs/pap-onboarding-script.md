# HELM Onboarding Script
## Complete User Experience Document
## Every question, every button, every background action

This document shows the complete onboarding experience from the
user's perspective, with background actions noted in [brackets].
Use this to implement, test, and validate the onboarding flow.

---

## UX DESIGN PRINCIPLES (Research-Backed — Applied Throughout)

These principles are derived from top onboarding flows (Duolingo, Superhuman, Monzo, Notion, Revolut).
Every change in this spec applies at least one of these. Do not deviate without noting which principle
is being intentionally overridden.

**P1 — One question per screen.** Never combine two decisions on the same screen. Cognitive load is
the #1 drop-off driver. B2 is now a single question. B7 is now a single question (moved to Stage 1 as B3b).

**P2 — Defer credentials until after first value.** User should feel something good before we ask
for anything hard. Aha moment at A6 (first Discord message) — not at B21.

**P3 — Five-minute rule.** Map the fastest path to aha moment and protect it. Everything before first
Discord message must be under 15 minutes for the motivated user.

**P4 — Anxiety-first microcopy.** For every security/credential step: lead with what you are NOT doing,
not what you are doing. "We never see your password" before "paste your token."

**P5 — "We'll handle this" frame.** Shift agency to HELM at technical steps. Never "you need to do X."
Always "I'll open this page for you — you just click Allow." Reframe the user's role as approver, not executor.

**P6 — Progress starts at 20%, not 0%.** A progress bar that starts empty communicates "you have a lot
of work ahead." Start at 20% from the first completed step. Frame as "X done" not "X remaining."
Zeigarnik effect: people complete tasks they've already started.

**P7 — Drop-off cliff is steps 3-5.** Front-load the most emotionally engaging steps (naming, personalization)
and back-load the technical ones (Discord Developer Portal, GitHub PAT). Celebrate after each technical step.

**P8 — Celebrate micro-milestones.** Every time a user does something that "worked," name it. "That was the
hardest part" after A5. "First backup done" after B12. These reset motivation before the next friction point.

**P9 — Never show an empty state.** Pre-populate what we can. Real sample briefing at B17 (not a
template). Starting progress at 20% before user does anything.

**P10 — Friction-reducing language patterns.** "Just one more thing" / "We'll handle the rest" /
"Most people finish this in under 2 minutes" / "You can add this later." Avoid: "Required field,"
"Please complete all fields," "You must authorize."

**P11 — Personalization at step 1.** Asking their name + agent name first creates reciprocity and
investment. They're more likely to complete onboarding because abandoning wastes what they've put in.

**P12 — Show before asking.** When a step involves an unfamiliar interface (Discord Developer Portal),
show a screenshot of what they'll see BEFORE asking them to navigate there. Preview = de-terrify.

**P13 — "Why we ask" micro-copy.** Every question that collects personal data includes one italicized
"Why:" line before the input. This eliminates the "why do they need this?" anxiety that causes abandonment.
Format: *Why: [one sentence, plain English, benefit-framed not feature-framed].*

**P14 — 3-stage progressive disclosure.** Phase B questions are split into three stages:
- Stage 1 (right after aha): 3 taps needed to start using HELM. Nothing else.
- Stage 2 (after first value, ~48 hours): Colors, working hours, notification style.
- Stage 3 (optional, any time): Advanced settings via #preferences.
This prevents survey fatigue immediately post-aha — the moment of highest enthusiasm and lowest patience.

**P15 — Email after first value.** Personal contact information (email) is collected AFTER the user
has seen HELM respond — not before. Asking for email before demonstrating value is a trust and conversion killer.

---

## HOW TO READ THIS DOCUMENT

**Regular text** = what the user sees and reads
**[BACKGROUND]** = what HELM does silently, user never sees
**[BUTTON]** = a tappable button
**[SELECT]** = a select menu (dropdown)
**[TEXT]** = a free text input field
**[SAVE]** = what gets written to CONFIG.md or VOICE-AND-STYLE.md
**[VERIFY]** = a check HELM runs before proceeding

---

## BEFORE YOU START

**What you'll have when setup is done (~45 minutes):**
→ An AI assistant running 24/7 in a private Discord server, accessible from your phone
→ A morning briefing customized to your calendar and inbox, arriving every day before you check your phone
→ A place to capture anything (links, notes, ideas) and have it searchable forever
→ A platform for building any automation you can describe in plain English

**Time breakdown (honest):**
→ Getting tools ready: ~10 minutes (automated — you watch)
→ Creating accounts: ~15 minutes (Discord + GitHub — HELM walks through every click)
→ Connecting your assistant: ~5 minutes (the only genuinely technical step — 10 guided clicks)
→ A few quick questions: ~5 minutes, then you're running
→ Total: about 35-45 minutes at a comfortable pace. You can stop and come back anytime.

**What you need before starting:**
→ A Claude Pro or Max subscription ($20/month) — if you don't have one, HELM will help you get it
→ A computer (Mac, Windows, or Linux) that can stay on and connected
→ That's it. Everything else — Discord, GitHub, password manager — HELM sets up with you.

**Setting up a dedicated machine?**
If you're setting up a clean or new machine for HELM (recommended), HELM can walk you through preparing it first.
[BUTTON: Help me set up a clean machine →]

> **Clean machine setup (step-by-step):**
> If this is a fresh machine or you want to start clean, HELM walks you through:
> 1. Erase and reinstall your OS (Mac: Erase All Content, Windows: Reset this PC → Remove everything)
> 2. Basic security: FileVault/BitLocker encryption, screen lock after 2 minutes, firewall on
> 3. Create a single user account just for HELM — no personal files, no other apps needed
>
> You can do this before starting setup, or skip it and use your daily machine.
> [BUTTON: My machine is ready — continue]
> [BUTTON: Skip — I'll use my daily machine]

---

## PRE-ONBOARDING: GETTING HELM

### Step 0 — How the user arrives here (the "my friend told me about this" path)

A potential user hears about HELM from a friend. The friend shares a link — a simple landing page
(hosted at the HELM GitHub Pages site or a future helm.sh domain).

**What the landing page shows (before any install commitment):**

> **HELM — your always-on AI assistant, running in Discord**
>
> HELM runs in the background and handles the things that shouldn't need your attention.
> Every morning it tells you what's on your calendar and what needs a reply.
> When something urgent hits your email, it lets you know.
> Describe anything you wish just happened automatically — and it builds it for you.
>
> **What people use it for:**
> → A daily briefing that replaces 20 minutes of inbox-checking
> → Alerts when something time-sensitive lands
> → Automations for anything repetitive
>
> **What it costs:** ~$20/month (Claude Pro or Max subscription). No other required fees.
> Optional add-ons: VPS hosting (~$6/month), custom domain, mobile alerts — all optional.
>
> **What you need:** A Mac, Windows, or Linux machine. About 25-30 minutes for setup.
> Everything after that runs from your phone via Discord.
>
> [BUTTON: Get started → (copies install command + shows instructions)]

**On clicking "Get started":** The landing page shows four steps in order:

---

**Step 1 — Claude subscription** *(~2 minutes if you don't have one)*

> HELM runs on Claude, Anthropic's AI. You'll need a subscription to use it.
>
> Already have Claude Pro or Max? [BUTTON: I'm ready — skip to step 2]
>
> Don't have one yet?
> → Open Claude.ai → click your profile icon → Upgrade plan → Claude Pro ($20/month)
> → Once you've subscribed, come back here.
>
> [BUTTON: Help me subscribe →]
> *Opens Claude.ai in a new tab. Return here after subscribing.*

---

**Step 2 — Claude Desktop** *(the app HELM runs inside — ~3 minutes)*

> HELM runs inside Claude Desktop. It's a free app from Anthropic.
>
> → [BUTTON: Download Claude Desktop] *(opens anthropic.com/download)*
> → Install it like any other app (drag to Applications on Mac, run the installer on Windows)
>
> [BUTTON: I have Claude Desktop installed ✓]

---

**Step 3 — Enter Cowork mode** *(30 seconds)*

> → Open Claude Desktop
> → Look for the code/tools icon in the bottom-left corner (⌨️)
> → Click it — you'll see a chat interface. That's Cowork mode — where HELM will be installed.
>
> [BUTTON: I see the Cowork interface ✓]

---

**Step 4 — Your install command** *(copy and paste — that's the last step)*

> Paste this command into the Cowork chat and press Enter.
> HELM will handle the rest from here.
>
> ```
> Set up HELM — github.com/[helm-org]/helm
> ```
> [BUTTON: Copy command]
>
> *Once you paste and press Enter, you'll see HELM start working. Come back here if anything goes wrong.*

---

**This solves the GitHub URL problem.** The install command includes the repo URL so Claude
Desktop knows where to find HELM. The user never needs to know what GitHub is — they just
copy and paste the command the page gives them.

The landing page also shows: "You'll create a free Discord account during setup if you don't have one.
Setup walks you through everything — no technical knowledge required."

---

## PRE-ONBOARDING: COWORK SETUP

No terminal required. Everything happens in Claude Desktop.

**Zero-terminal design:** The user never opens Terminal. HELM is set up entirely through
Claude Desktop (Cowork mode), where Claude Code runs bash commands on their behalf
invisibly. The user only interacts with a chat interface.

---

### What the user does (3 steps):

1. Download Claude Desktop from anthropic.com (standard app install — no terminal)
2. Open Claude Desktop → click the code/tools icon to enter Claude Code (Cowork) mode
3. Paste the command from the Get HELM page and press Enter (includes the GitHub repo URL)

That's the only instruction. HELM does the rest.

---

### What HELM does (background — user sees progress in Cowork chat):

```
[BACKGROUND] Detect platform (Mac/Windows/Linux)
[BACKGROUND] Install package manager if missing (Homebrew/winget/apt)
[BACKGROUND] Install Node.js, Bun, git
[BACKGROUND] Clone HELM repo from GitHub
[BACKGROUND] Create directory structure:
             ~/.helm/system/ (HELM code — updated on releases)
             ~/.helm/user/   (user data — never touched by updates)
             ~/.claude/agents/
             ~/.claude/skills/
[BACKGROUND] Write all agent files to ~/.claude/agents/
[BACKGROUND] Write all skill files to ~/.claude/skills/
[BACKGROUND] Write core HELM config templates to ~/.helm/user/
[BACKGROUND] Clone and build v-3/discordmcp
[BACKGROUND] Configure MCP servers
[BACKGROUND] Set ANTHROPIC_MODEL to current latest Sonnet model
             (referenced from HELM repo's model-config.json — updates with HELM)
[BACKGROUND] Set machine to never sleep
```

---

### How HELM collects setup info (through Cowork chat, not terminal prompts):

Questions are asked one at a time through the chat interface, interspersed with background work.
No terminal prompts. No invisible-text password fields. Everything is conversational.

Example flow:
```
HELM: Detecting your system...
HELM: ✓ Mac detected. Installing tools — about 2 minutes.
      While that runs: what should I call you?

User: {{USER_JERRY}}

HELM: Got it, {{USER_JERRY}}. What should I call your HELM assistant?
      (You can change this any time.)

User: Marvin

HELM: ✓ Tools installed. Let's connect to Discord.
      I'll open Discord's developer tools — you'll need to click through a few steps.
      Takes about 5 minutes and I'll guide every click.
```

Credentials are pasted into the chat (tokens are never stored in chat history — HELM
reads them and immediately writes to the secure vault, then clears them from memory).

---

### What the user must do manually (human-in-the-loop steps):

These cannot be fully automated — they require human clicks by design (OAuth security, Discord bot detection).
HELM opens the right pages, explains each click, and waits.

1. **Discord bot creation — HELM creates TWO bots** (~10 min total)
   Every HELM install requires two bots:
   - **Main Bot** — the primary HELM agent that handles all conversations
   - **Lifeline Bot** — a backup bot that runs on the VPS independently; responds even when Main Bot is completely dead (network loss, Mac offline, etc.)

   HELM opens discord.com/developers/applications
   User creates two applications: "HELM Bot" and "HELM Lifeline"
   For each: Bot → Reset Token → Copy → paste into Cowork chat
   Both tokens are saved to 1Password (HELM Bot Token + HELM Lifeline Bot Token)

2. **Discord bot authorization — both bots** (~2 min)
   HELM generates authorization URLs for both bots
   User opens each in their browser, selects their server, taps Authorize
   (Discord's bot safety check — requires a human click, can't be bypassed)

3. **GitHub Personal Access Token** (~3 min)
   HELM opens github.com/settings/tokens
   User clicks through guided steps
   User pastes the token into Cowork chat

4. **OAuth flows for connectors** (~1 min each, done during Phase B)
   HELM opens each OAuth authorization page
   User taps Allow in browser
   HELM confirms and saves the connection

---

### What user never needs:
- Terminal / command line
- curl, brew, npm, node, or any CLI tool knowledge
- Config file editing
- Understanding of what's being installed

---

### Verification (automatic — runs in background, user just watches progress):

```
[BACKGROUND] Verify all dependencies installed correctly
[BACKGROUND] Verify Claude Code authenticated
[BACKGROUND] Verify agents and skills written correctly
[BACKGROUND] Configure launchd/systemd/Task Scheduler watchdog (auto-restart on crash)
[BACKGROUND] Generate personalized recovery guide
             (fills ~/.helm/user/RECOVERY-AI-PROMPT.md with agent name, Discord server ID,
              machine info, GitHub backup location)
[BACKGROUND] Start bot process
[BACKGROUND] Send test message to Discord → verify it appears in #general
[BACKGROUND] Run automated tests in background (~10 min) — user doesn't wait for these
```

---

### What the user sees when setup is complete (in Cowork chat):

```
✓ [AGENT_NAME] is live in your Discord server.
✓ The hardest part of setup is done — everything from here happens in Discord.

Head to Discord now — [AGENT_NAME] is waiting for you in #general.
Just say hello.

(If you don't see a message from [AGENT_NAME] within about a minute, come back here.)
```

No test result URLs. No file paths. No technical output.
HELM monitors the test results internally and will surface anything that needs attention.

---

### What the user needs before starting:

HELM walks users through everything they need during setup — they don't need to pre-create accounts
before starting. The only genuine prerequisite is Claude Desktop installed on their machine.

Accounts HELM walks through creating (inline, one at a time, only when needed):
- **Claude account** — Claude Pro or Max subscription recommended ($20/month, API key fallback available)
- **Discord account** — free; HELM guides server creation inline
- **GitHub account** — free; HELM guides repo creation inline

HELM cannot create accounts on the user's behalf — that's a human-only step (account security by design).
But HELM opens every page, explains every field, and waits at each step.

**Cost transparency (surfaced at the very start, before any setup begins):**

```
HELM: Before we start — what does this cost?

You'll need a Claude subscription to use HELM.
Claude Pro is $20/month. Claude Max is $100/month.
(Claude Pro is fine for most people starting out.)

HELM itself is free and open source.
Optional extras — mobile alerts, VPS hosting — are clearly labeled as optional throughout setup.
There are no surprise costs.

[BUTTON] I have Claude Pro or Max — let's go
[BUTTON] I don't have a subscription — help me get one
[BUTTON] Tell me more about what I'm signing up for
```

---

### Exceptions (honestly surfaced at start of setup):

> "Two things in this setup require a human click — Discord and Google are designed so
> that only you can authorize an app to connect to your account. I'll open both pages
> and tell you exactly what to click. Everything else I handle for you."

---

### D-R2-07 — Friction priority (answered by {{USER_JERRY}} 2026-06-06):
A (terminal) → B (password manager) → C (Discord Developer Portal)
Cowork-first design eliminates A. B is addressed by platform-native keychain fallback.
C is addressed by guided step-by-step with every click explained.

### Headless VPS install path (edge case):

Cowork-first assumes the user has Claude Desktop available. This covers Mac and Windows.
For Linux VPS users (no GUI, no Claude Desktop):
- Use original terminal bootstrap path: `curl -fsSL https://helm.sh/install | bash`
- All setup questions answered via terminal prompts (fallback, not the primary UX)
- After install, all subsequent interaction happens through Discord (not terminal)
- This is the "advanced" path — documented separately, not shown to new users by default

Detection: if the user indicates they're installing on a headless Linux server, route to VPS path automatically.

---

## PHASE A: COWORK SESSION

Onboarding fires automatically in the Cowork HELM project
after bootstrap completes.

---

### A1 — Welcome and machine check

**User sees:**

> HELM is installed. Quick question first —
> which machine are you setting this up on?

[BUTTON] A dedicated clean machine — recommended
[BUTTON] My daily computer — what are the tradeoffs?

---

**If user taps "daily computer — tradeoffs":**

> On your daily machine:
> → HELM can see your personal files and accounts when
>   using Computer Use
> → Scheduled tasks stop if the machine sleeps or you
>   close Claude Desktop
> → Security is weaker than an isolated machine
>
> If you later move to a dedicated machine, migration
> is automatic from your backup.

[BUTTON] I understand — proceed with my daily machine
[BUTTON] I'll get a dedicated machine first — pause for now

---

[SAVE] PAP_MODE = 1 (clean) or 2 (daily)

---

### A2 — Getting set up together (inline prerequisite handling)

**[UX: Don't open with a checklist of things they haven't done. Lead with what we're doing together.]**

**User sees:**

> Before we connect to Discord, I need to create a few accounts with you.
> None of this is hard — I'll walk through each one.
> Takes about 10-15 minutes. Ready?

[BUTTON] Let's do it
[BUTTON] Wait — what accounts?

---

**If "what accounts?":**

> Three things:
>
> → A Discord account (it's free) — Discord is where we'll talk after this
> → A Discord server just for HELM — like your private workspace
> → A GitHub account (also free) — for backing up your settings nightly
>
> I'll open every page and tell you exactly what to do at each step.

[BUTTON] Got it — let's go
[BUTTON] I already have some of these →

**If "I already have some of these":** Show each as "Already done? ✓ or Not yet?" — tap to confirm.
Skip setup for confirmed items. This way completing prerequisites feels like progress, not failure.

---

**HELM handles in sequence (one at a time, never as a wall):**

**Step: Discord account**
```
HELM: First — do you have a Discord account?

Discord is a free messaging app — think of it like a private chat room
that HELM will live in. Most people use it on their phone.
```
[BUTTON] Yes, I have Discord ✓
[BUTTON] No — help me create one

**If creating:**
> 1. Open discord.com on your phone or computer
> 2. Click 'Register'
> 3. Enter your email, a username, and a password
> 4. Verify your email

[BUTTON] Done — I have a Discord account ✓
[BUTTON] I'm stuck

**Celebration:**
> Discord account — done ✓
> Next: let's create a private server for HELM.

---

**Step: Discord server**
```
HELM: Now let's create a private server — this is where I'll live.
Think of it as your personal workspace. No one else can join unless you invite them.
Takes about 60 seconds.
```

> 1. Open Discord → click the + button on the left sidebar
> 2. Select 'Create My Own'
> 3. Select 'For me and my friends'
> 4. Name it whatever you like (e.g. "HELM" or your name)
> 5. Click 'Create'

[BUTTON] Done — I have a server ✓
[BUTTON] I'm stuck

**After:**
> Perfect. Now I need the ID for that server — it's just a number Discord uses internally.

> 1. Open Discord
> 2. Go into Settings → App Settings → Advanced
> 3. Turn on 'Developer Mode'
> 4. Go back to your server → right-click the server name → 'Copy Server ID'

[TEXT] Paste your Server ID here

[SAVE] DISCORD_SERVER_ID

**Celebration:**
> Server ID saved — ✓
> Two down. One more: GitHub backup.

---

**Step: GitHub account**
```
HELM: Last one: GitHub.

GitHub is where I'll back up your preferences every night.
If anything ever breaks, everything comes right back from there.
It's free — takes about 2 minutes to sign up.
```

> 1. Go to github.com → click 'Sign up'
> 2. Enter your email → Create a username → Set a password
> 3. Verify your account

[BUTTON] I have a GitHub account ✓
[BUTTON] I'm stuck

**After GitHub account confirmed:**

> Now let's create a private backup repo — think of it like a folder just for HELM.
>
> 1. In GitHub: click the + button (top right) → New repository
> 2. Name it exactly: **platform-config**
> 3. Set it to **Private**
> 4. Click Create repository

[BUTTON] Created ✓
[BUTTON] I'm stuck

**Celebration:**
> Everything's ready.
>
> ✓ Discord account
> ✓ Private server
> ✓ GitHub backup repo
>
> That was all the accounts. Now for the fun part — let's connect everything.

---

[SAVE] DISCORD_SERVER_ID, GITHUB_USERNAME, GITHUB_BACKUP_REPO

---

**Discord Server ID walkthrough (if needed):**

> Let's find your Discord Server ID.
>
> 1. Open Discord on your phone or computer
> 2. Tap your server name at the top
> 3. Tap Settings (gear icon)
> 4. Scroll to the bottom — you'll see Server ID
> 5. Tap it to copy

[BUTTON] I have it ✓
[BUTTON] I can't find it — help me

---

**GitHub repo walkthrough (if needed):**

> Let's create your backup repo.
>
> 1. Go to github.com and sign in
> 2. Click the + button (top right) → New repository
> 3. Name it exactly: platform-config
> 4. Set it to Private
> 5. Click Create repository

[BUTTON] Done ✓
[BUTTON] I'm stuck

---

**GitHub Personal Access Token (if needed):**

> You'll need a token so HELM can save backups to GitHub.
>
> 1. In GitHub: click your profile photo → Settings
> 2. Scroll to Developer settings (bottom of left sidebar)
> 3. Personal access tokens → Tokens (classic)
> 4. Click Generate new token (classic)
> 5. Note: type 'HELM backup'
> 6. Check the box next to 'repo'
> 7. Click Generate token at the bottom
>
> ⚠️ Copy the token now — it's only shown once.
> Save it to 1Password HELM Vault:
> New Login → Name: 'GitHub PAT' → Password: [paste token]

[BUTTON] Saved to HELM Vault ✓
[BUTTON] I'm stuck

---

### A3 — Agent naming

**User sees:**

> Now — most important question before we continue.
>
> What would you like to call me?
>
> I'll answer to almost anything. Some people name their AI after a person they trust.
> Others go abstract, nautical, or silly. There's no wrong answer.
>
> A few options to get you started — or type your own:

[BUTTON] Atlas
[BUTTON] Scout
[BUTTON] Remi
[BUTTON] Flynn
[BUTTON] Sage
[BUTTON] Something else →

**If "Something else":**

> Go for it. Your dog's name, a city you love, your first crush — anything works.
> (This is the most important setting in the whole setup. Choose wisely. Just kidding. Sort of.)

[TEXT] What name? [free text field]

---

[SAVE] AGENT_NAME = [chosen name]

---

**Follow-up:**

> And what should I call you?
> *(Just a first name or nickname — this is how I'll address you when we're talking.)*

[TEXT] [free text field, no suggestions]

[SAVE] USER_PREFERRED_NAME = [entered name]

---

### A3b — Mini-preview (wow moment before the technical work begins)

**[UX: Apply P2, P7, P9. User has named their agent. Now show them the destination before asking them to do the hard stuff. Makes A5 feel worth it.]**

**User sees:**

> [USER_PREFERRED_NAME] and [AGENT_NAME]. Perfect.
>
> Here's where we're going:
>
> [Screenshot: Discord #general channel, showing [AGENT_NAME] as bot name,
>  message bubble: "Good morning [USER_PREFERRED_NAME] — here's what's on today:
>  📅 3 calendar events. 📧 2 emails need replies. Everything else is clear."]
>
> That's what your Discord will look like in about 20 minutes.
>
> Next: one technical step — creating [AGENT_NAME]'s account in Discord.
> It's 10 guided clicks and takes about 5 minutes.
> After that, we're done with anything technical.

[BUTTON] Let's do it

---

### A4 — HELM Vault setup

**User sees:**

> Before we connect to Discord, I need a secure place
> to store your credentials.
>
> *Why: Discord, GitHub, and your connected tools each need a password or token.
> I store these in your password manager so only you — and I, with your permission —
> can access them. Your personal passwords stay completely separate.*
>
> Here's how this works:
> → I never see your personal passwords
> → Credentials live in your password manager in a
>   section called 'HELM Vault' — you control what's there
> → Only what you put in HELM Vault is accessible to me
> → Your personal passwords stay completely separate
>
> Do you use a password manager?

[BUTTON] 1Password
[BUTTON] Bitwarden
[BUTTON] KeePassXC
[BUTTON] Something else →
[BUTTON] No — I'd like to set one up
[BUTTON] No — I'd rather not

---

**1Password — HELM Vault creation:**

> Let's create your HELM Vault.
>
> 1. Open 1Password
> 2. In the left sidebar, click the + next to Vaults
> 3. Name it 'HELM Vault' exactly
> 4. Don't share it with anyone
> 5. Click Create

[BUTTON] Done ✓
[BUTTON] I'm stuck

---

**Bitwarden HELM Vault creation:**

> Let's create your HELM Vault.
>
> 1. In Bitwarden, click the + button → New Folder
> 2. Name it 'HELM Vault'
> 3. Save

[BUTTON] Done ✓
[BUTTON] I'm stuck

---

**KeePassXC HELM Vault creation:**

> Let's create your HELM Vault.
>
> 1. Right-click your database name
> 2. Select 'New Group'
> 3. Name it 'HELM Vault'
> 4. Click OK

[BUTTON] Done ✓
[BUTTON] I'm stuck

---

**If no password manager, wants to set one up:**

> I'd recommend 1Password — it has the best integration
> with HELM and works on all your devices.
> It costs $3/month after a free trial.
>
> [BUTTON] Set up 1Password
> [BUTTON] I'll use something else →
> [BUTTON] Skip for now — use basic security

---

**If declines password manager:**

> No problem. We'll use your Mac's built-in keychain
> for required credentials. This works fine for getting
> started — you can always add a password manager later.
>
> Note: some automated logins may need you to be
> available to approve them. I'll let you know when
> that comes up.

[BUTTON] OK, let's continue

[SAVE] CREDENTIAL_ACCESS_LEVEL = keychain

---

### A5 — Discord bot creation

**[UX: Apply P4, P5, P7, P8, P12. This is the scariest step. Lead with empathy, show a preview, celebrate at the end.]**

**User sees:**

> Heads up — the next few screens are going to look more technical than anything else we'll do.
>
> You're going to visit Discord's developer portal. It's a page Discord made for software
> engineers, and it looks like it. Most people have never been there.
>
> Here's what it looks like:
> [Screenshot: Discord developer portal main page, arrows pointing to 'New Application' button]
>
> We're only going to do one thing: create a special account for me in your server.
> I'll open every page and tell you exactly what to click.
> Most people finish this in under 5 minutes — and it's the hardest step in all of setup.
> Everything after this is just telling me about yourself.

[BUTTON] Let's do it — I'm ready
[BUTTON] Wait — what exactly is a "bot"?

---

**If "what is a bot":**

> A bot is just a special account that can post messages and respond in your Discord server.
> Right now [AGENT_NAME] doesn't have an account in your server — so we're going to create one.
>
> You go to Discord's developer page, give it a name, and save a long password (called a token).
> That's it. I'll open the page and walk through every click.
>
> The one thing to know ahead of time: when you see the token, copy it immediately.
> It disappears after you leave the page — I'll remind you when we get there.

[BUTTON] Got it — let's go

---

**Step by step (each step has [Done ✓] and [I'm stuck]):**

---

> **Step 1 of 10**
> Open discord.com/developers/applications in your browser

[BUTTON] Opened it ✓
[BUTTON] I'm stuck

---

> **Step 2 of 10**
> Click the blue 'New Application' button in the top right

[BUTTON] Done ✓
[BUTTON] I don't see it

---

> **Step 3 of 10**
> Name your application — I'd suggest using the name you
> gave me: [AGENT_NAME]
> This is what appears in your Discord server.

[BUTTON] Named it ✓

---

> **Step 4 of 10** (optional)
> You can add a profile picture on the Bot tab if you'd like.
> This represents [AGENT_NAME] in your server.
> Totally optional — you can always add one later.

[BUTTON] Added one ✓
[BUTTON] Skip this

---

> **Step 5 of 10**
> Click 'Bot' in the left sidebar

[BUTTON] Done ✓

---

> **Step 6 of 10**
> Click 'Reset Token', then click 'Yes, do it' to confirm

[BUTTON] Done ✓

---

> **Step 7 of 10 — ⚠️ Important one**
>
> You'll see a long string of random characters — that's your bot token.
> It's like [AGENT_NAME]'s password for your Discord server.
>
> **Copy it right now, before you do anything else.**
> This is the only time Discord will show it to you.
>
> Then save it:
> → Open your password manager → HELM Vault
> → New Login → Name: '[AGENT_NAME] Bot Token' → Password: [paste token]
>
> Or if you're not using a password manager: paste it back into this chat.
> I'll save it to your device's secure keychain immediately.

[BUTTON] Saved it ✓ — I have the token
[BUTTON] I accidentally left the page — help

**If left the page:**
> No problem. Go back to the Bot tab in Discord's developer portal and click
> "Reset Token." Confirm, and you'll get a new one. Copy it this time before leaving.

[BACKGROUND] Read token from HELM Vault to verify it was saved
[VERIFY] Token is accessible in HELM Vault

---

> **Step 8 of 10**
> Scroll down on the Bot page.
> Under 'Privileged Gateway Intents', turn ON all three:
>
> → Presence Intent
> → Server Members Intent
> → Message Content Intent
>
> Then click Save Changes.

[BUTTON] All three on and saved ✓
[BUTTON] I can't find them

---

> **Step 9 of 10**
> Click 'OAuth2' in the left sidebar
> Then click 'URL Generator'
>
> Under Scopes: check 'bot'
> Under Bot Permissions: check 'Administrator'
>
> Copy the long URL that appears at the bottom

[BUTTON] I have the URL ✓
[BUTTON] I'm stuck

---

> **Step 10 of 10**
> Paste that URL into your browser.
> Select your Discord server from the dropdown.
> Click Authorize.

[BUTTON] Done — I can see [AGENT_NAME] in my server ✓
[BUTTON] I don't see [AGENT_NAME] in my server

**After step 10 success — celebration:**
> That was it. The hardest part of setup is done.
>
> Seriously — most people think this is going to break something. It didn't.
> [AGENT_NAME] is now in your Discord server.
>
> Everything from here is just telling me about yourself — how you like to
> communicate, what tools you use, what you want help with.
> No more technical steps.

---

**If can't see bot in server:**

> Let's troubleshoot. Does your Discord server appear
> in the dropdown when you paste the URL?
>
> [BUTTON] Yes it did, I selected it, but no bot
> [BUTTON] No, my server didn't appear
> [BUTTON] I didn't see a dropdown

[Each option leads to a specific fix]

---

### A6 — Connect and hand off to Discord

**User sees:**

> Connecting [AGENT_NAME] to your server now...

[BACKGROUND] Read bot token from HELM Vault
[BACKGROUND] Start Claude Code with Discord channels plugin
[BACKGROUND] Configure never-sleep settings on Mac Mini
[BACKGROUND] Verify bot appears online in Discord server
[BACKGROUND] Send first message to #general

---

**On success:**

> [AGENT_NAME] is in your Discord server and ready.
>
> Before you head over — one more thing:
> → This machine needs to stay powered on and connected to the internet.
>   That's how [AGENT_NAME] is always available on your phone.
>   [AGENT_NAME] will start automatically if the machine ever restarts.
>
> Head to Discord on your phone or computer.
> When you get there, just say hello to me.
>
> I'll be waiting.

[BUTTON] Opening Discord now

---

**The aha moment — [AGENT_NAME]'s first response in Discord:**

When the user sends their very first message in Discord (any message), [AGENT_NAME] responds:

> Hi [USER_PREFERRED_NAME]. [AGENT_NAME] here — I'm set up and listening.
>
> You just did the part that most people think is going to break something.
> It didn't. You're in good shape.
>
> Two quick answers and I'll be ready to actually help you.
> Takes about 1 minute.

[BUTTON] Let's do it
[BUTTON] I'll come back later

**This is the aha moment (P2). It happens here — not at B21.**
The user sent a message, HELM responded warmly. The product works. Everything after is bonus polish.

[BACKGROUND] Save ONBOARDING_STEP = B1 to CONFIG.md

---

### A6b — Email (just-in-time, after first value)

**[UX: Apply P2. User has just experienced HELM responding. They feel the value. NOW is the right time to ask for email — not before they've seen anything work. P2: defer personal data asks until after first value.]**

**[AGENT_NAME] asks immediately after aha response, as a second message:**

> One quick thing:
> If Discord ever goes offline, where should I reach you?
>
> *Why: This is only used if Discord becomes unreachable — like a power outage or internet outage.
> We won't email you for normal updates. Discord handles those.*
>
> Totally optional — you can skip it and I'll alert you in Discord only.

[TEXT] Your email (optional)
[BUTTON] Skip — Discord alerts are fine

[SAVE] GOOGLE_EMAIL (only if provided)

---

**[If user doesn't see message in Discord — troubleshooting:]**
[BUTTON] I don't see [AGENT_NAME] in Discord — help me

---

**If no message visible:**

> Let's check a few things:
>
> 1. Is [AGENT_NAME] showing as online (green dot)
>    in your server's member list?
>
> [BUTTON] Yes, green dot
> [BUTTON] No, it's grey or offline

[Troubleshoot based on response]

---

## PHASE B: DISCORD SESSION

All of Phase B happens in Discord.
User can use their phone, tablet, or daily computer.
They never need to return to the Mac Mini.

---

### B1 — Transition into Discord preferences

**[AGENT_NAME] continues in #general (after user taps "Let's do it"):**

> Progress: ████████░░ 80% done
>
> Last bit — 3 quick taps and you're fully running.
> Everything else I'll ask as it becomes relevant. Takes about 1 minute.
>
> [UX: Progress shows 80% — HELM is live, this is just polish. P6: start high, not at zero.
>  "3 quick taps" is honest: Stage 1 below is exactly 3 button taps.]

[UX: No "Ready?" — proceed immediately. The user just said "Let's do it" — don't ask again.]

[SAVE] ONBOARDING_STEP = B2

---

---
## STAGE 1 — Minimum setup (3 taps, ~1 minute)
**[UX: Stage 1 captures ONLY what's needed to make the first interaction feel right.
Everything else is deferred to Stage 2. Goal: get the user into HELM working, not out of setup questions.]**

---

### B2 — Communication style (Stage 1 — tap 1 of 3)

> When I give you results, how much do you want?
>
> *Why: This is the single biggest thing that affects how every message feels.*

[BUTTON] Just the answer — keep it brief
[BUTTON] Answer + brief reason — one line why
[BUTTON] Think it through with me — I like understanding the why

*After tap:* "Got it."

[SAVE] PREFERRED_TONE

---

### B3 — Display mode (Stage 1 — tap 2 of 3)

> Light or dark?

[BUTTON] ☀️ Light
[BUTTON] 🌙 Dark
[BUTTON] 🖥 Match my device

*After tap:* "Got it."

[SAVE] DISPLAY_MODE

---

### B3b — Trust level (Stage 1 — tap 3 of 3)

> When I connect to your calendar, email, and files:
> how hands-on do you want to be?
>
> *Why: This is the one setting I need before connecting your tools.
> Think of it as how you'd onboard a new assistant their first week.*

[BUTTON] Conservative — always ask me first
[BUTTON] Balanced — read quietly, ask before writing or sending anything
[BUTTON] Proactive — act and tell me what you did. I trust your judgment.

*After tap (any option):*
> Got it. A few things I always check with you regardless — these are hardcoded:
>
> → **Sending emails** — I draft it, you send
> → **Creating or changing calendar events** — I propose, you approve
> → **Deleting anything** — always asks first
> → **Money and transactions** — requires your explicit OK, every time
>
> These exist because mistakes in those areas are hard to undo.
> Everything else follows your preference. You can change this anytime in #preferences.

[BUTTON] Makes sense — let's connect my tools ✓

[SAVE] TRUST_LEVEL_DEFAULT to CONFIG.md

---

**[BACKGROUND] Stage 1 complete. Save ONBOARDING_STAGE = 1.**
**[BACKGROUND] Stage 2 preferences are deferred. See B3c below for deferred prompt schedule.**

---

### B3c — Stage 2 deferred preferences (fires 48 hours after first workspace, or on request)

**[UX: Research-backed. Don't interrogate new users with 15 questions. Let them experience value first.
Stage 2 fires after their first real HELM output — when they have context for why each question matters.]**

**[BACKGROUND] Schedule Stage 2 prompt in #helm-improvements after first workspace completes:**

> Hey [USER_PREFERRED_NAME] — you've had a few days with [AGENT_NAME].
> Want to spend 5 minutes customizing how it works?
>
> A few settings that make a real difference:
> → Color palette for everything HELM builds you
> → Your preferred hours (for when to schedule background work)
> → How often to surface improvement ideas
>
> [BUTTON] Set these up now (5 min)
> [BUTTON] Remind me later

**Stage 2 covers (in order, one per screen):**
1. Color palette (currently B4)
2. Information style — tables vs prose vs visual (was B3)
3. AI transparency preference (was B2 screen 3)
4. Technical language preference (was B2 screen 2)
5. Time and date format (was B5)
6. Working hours (was B6)
7. Notification preferences (was B9, B14)
8. Usage alerts (was B8)

**Stage 3 (optional, whenever — accessible via #preferences anytime):**
- Output destination (was B10)
- Computer Use authorization (was B13)
- Standing preferences (was B15)
- Daily briefing full config (was B16)

---

### B4 — Color palette (Stage 2 — see B3c above for when this fires)

**[UX: Display mode is already collected in Stage 1 (B3). This step is color palette only.]**

> Now let's set how your outputs look.
>
> **Color palette:**
> These appear on status cards, reports, and everything I build for you.
>
> Here are 20 nautical palettes — each card shows your colors on dark
> background (left) and light background (right).

[BACKGROUND] Bot sends palette grid image (helm-palettes.png) as Discord attachment.

[SELECT] Choose a palette:
  1 — Ocean Breeze (#0EA5E9, #06B6D4, #F0F9FF)
  2 — Deep Navy (#1E3A5F, #3B82F6, #93C5FD)
  3 — Tide Pool (#0F766E, #14B8A6, #CCFBF1)
  4 — Northern Star (#1E40AF, #60A5FA, #FCD34D)
  5 — Coral Reef (#EA580C, #FB923C, #0EA5E9)
  6 — Lighthouse (#DC2626, #F97316, #1E3A5F)
  7 — Horizon Gold (#D97706, #F59E0B, #0F172A)
  8 — Sandy Shore (#D2A679, #B45309, #164E63)
  9 — Midnight Helm (#1E1B4B, #7C3AED, #C084FC)
  10 — Harbor Watch (#1F2937, #4B5563, #10B981)
  11 — Storm Front (#374151, #6B7280, #7C3AED)
  12 — Abyss (#0C0A09, #1C1917, #3B82F6)
  13 — Kelp Forest (#166534, #4ADE80, #CA8A04)
  14 — Tidal Marsh (#4D7C0F, #84CC16, #0F766E)
  15 — Moss & Violet (#4A7C59, #7C3AED, #D97706)
  16 — Seafoam (#047857, #34D399, #6EE7B7)
  17 — Sailcloth (#292524, #78716C, #E7E5E4)
  18 — Fog Light (#374151, #9CA3AF, #F3F4F6)
  19 — Compass Rose (#9F1239, #BE185D, #F0ABFC)
  20 — Nautical Gold (#1E3A5F, #B45309, #F5F5F4)
  21 — Enter my own hex codes →

---

**If "enter my own hex codes" (#21):**

> **Primary color** (headers, main actions):
[TEXT] Hex code — e.g. #4A7C59

> **First accent** (highlights, important values):
[TEXT] Hex code — e.g. #7C3AED

> **Second accent** (supporting elements):
[TEXT] Hex code — e.g. #D97706

[BUTTON] Preview these colors
[BUTTON] Save ✓
[BUTTON] Skip — use palette #15 as default

---

[SAVE] COLOR_PRIMARY, COLOR_ACCENT_1, COLOR_ACCENT_2, DISPLAY_MODE

---

### B5 — Time and date

> A few quick formatting preferences.
>
> *Why: Your timezone determines when your morning briefing arrives and when scheduled tasks run.
> Date and time formats are just personal preference — you'll see these on everything I build you.*
>
> **Date format:**

[BUTTON] MM/DD/YYYY — e.g., 04/30/2026
[BUTTON] DD/MM/YYYY — e.g., 30/04/2026
[BUTTON] YYYY-MM-DD — e.g., 2026-04-30

> **Time format:**

[BUTTON] 12-hour — 2:30 PM
[BUTTON] 24-hour — 14:30

> **Week starts on:**

[BUTTON] Monday
[BUTTON] Sunday

> **Your timezone:**
> [DETECTED: America/Los_Angeles — Pacific Time]

[BUTTON] That's right ✓
[BUTTON] Change it →

[SAVE] DATE_FORMAT, TIME_FORMAT, WEEK_STARTS_ON, TIMEZONE

---

### B6 — Working style

> When are you most active?

[BUTTON] 🌅 Early morning — before 9am
[BUTTON] ☀️ Daytime — 9am to 5pm
[BUTTON] 🌆 Evening — 5pm to 10pm
[BUTTON] 🌙 Night owl — after 10pm
[BUTTON] 📅 Varies — no consistent pattern

---

> When are you typically offline or unavailable?
> (This is when I'll schedule background work — ETF data pulls, backups,
> cleanup jobs — so they don't interrupt you.)

[BUTTON] 🌙 Overnight — midnight to 7am
[BUTTON] 🏖 Weekends — I check in less
[BUTTON] 🍽 Evenings — after 7pm
[BUTTON] 📅 No set pattern — run tasks whenever needed

[SAVE] WORKING_STYLE_ACTIVE_HOURS, WORKING_STYLE_OFFLINE_HOURS

---

### B7 — Trust level (moved to Stage 1 — see B3b above)

**[UX: Trust level was moved to Stage 1 (B3b) so it's collected before connector setup.
Collecting it here (after B2-B6) meant users hit connector setup at B11 without a trust level saved.
B3b collects it in the 3-tap Stage 1 block right after the aha moment.]**

[SKIP to B8 — trust level already collected at B3b]

---

### B8 — Usage preferences

> HELM uses your Claude subscription automatically. Here's how to manage it.
>
> **Warn me at multiple points** — check all you want:

[TOGGLE] Alert at 50% — early heads-up
[TOGGLE] Alert at 75% — moderate warning
[TOGGLE] Alert at 90% — near-limit warning
[TOGGLE] Alert at 95% — last-chance warning
[TOGGLE] Only alert me if I'm at risk of hitting the limit — skip the early warnings

---

> **Usage reports:**

[BUTTON] Weekly summary
[BUTTON] Monthly summary
[BUTTON] Only when something needs attention

---

> **Cost optimizations I find:**

[BUTTON] Show me each opportunity
[BUTTON] Apply small ones automatically, tell me after
[BUTTON] Only show significant savings

[SAVE] USAGE_WARNING_THRESHOLDS (array), USAGE_REPORTING_FREQUENCY,
       COST_OPTIMIZATION_PREFERENCE

Note: HELM uses your existing Claude subscription — no separate Claude API key required
unless you explicitly set one up. Cost is the flat subscription rate you already pay.

---

### B9 — Proactivity preferences

> **When something breaks or needs attention:**
> How should I reach out about problems?

[BUTTON] Right away — tell me the moment something's wrong
[BUTTON] Daily summary — batch issues into one message
[BUTTON] Only critical — ignore minor hiccups, tell me if something's broken

---

> **When I notice improvement ideas:**
> (New automations, better ways to handle something, tools I could connect)
> How often should I surface suggestions?

[BUTTON] As they come up — I want to know when you spot something
[BUTTON] Weekly batch — show me everything on Mondays
[BUTTON] Only significant — skip minor improvements
[BUTTON] Never — I'll ask when I want ideas

---

**If not Never (suggestions):**

> How many improvement suggestions at a time?

[BUTTON] Just the top 1
[BUTTON] Top 3
[BUTTON] Top 5
[BUTTON] Everything you have

[SAVE] PROBLEMS_OUTREACH_FREQUENCY, IMPROVEMENTS_FREQUENCY, IMPROVEMENTS_MAX_SURFACED

---

### B10 — Output destination

> When I create files, where should they live?
>
> The safest option is a dedicated account just for HELM work —
> separate from your personal files. You keep full control.
> But your personal account works fine too.

[BUTTON] Google Drive — dedicated HELM account (most organized)
[BUTTON] Google Drive — my personal account
[BUTTON] Microsoft OneDrive — dedicated HELM account
[BUTTON] Microsoft OneDrive — my personal account
[BUTTON] Let me decide per workspace
[BUTTON] Something else →

**If "Something else":**
> Where would you like files saved?
[TEXT] Describe your preference — e.g., a specific folder, a different service

---

**If using personal account:**

> Got it. I'll create a 'PAP' folder in your Drive and
> keep all my work organized there. Your personal files
> stay separate.
>
> What access should I have to your Drive?

[BUTTON] HELM folder only — don't access anything else
[BUTTON] Full Drive access when needed for tasks

---

**If creating new account:**
[Walk through new account creation step by step]
[VERIFY] Access confirmed before proceeding

[SAVE] OUTPUT_DESTINATION, OUTPUT_DRIVE_PREFERENCE

---

### B11 — Connectors

> The more tools I can see, the more useful I become.
> Connected tools let me do things like:
> → Draft meeting summaries by reading your calendar AND email together
> → Alert you when someone hasn't responded to a time-sensitive thread
> → Build you a weekly digest from Slack, email, and your task manager in one place
>
> *Why: Each tool you connect becomes part of your morning briefing and available to workspaces you build.
> You choose exactly what I can access. Nothing connects without your approval.*
>
> You can connect any of these now or skip and add them later.
> What tools do you use?

[Toggle buttons — tap to select, tap again to deselect]

[📅 Google Calendar] [📧 Gmail] [📁 Google Drive]
[📅 Outlook Calendar] [📧 Outlook Email] [📁 OneDrive]
[💬 Slack] [📝 Notion] [✅ Todoist]
[📋 Asana] [📋 Trello] [🔧 Something else →]

> Anything with 🔐 needs a credential in HELM Vault.
> I'll walk you through each one after you select.

[BUTTON] These are my tools — continue

---

**For each selected connector (OAuth flow):**

> Let's connect [Calendar].
>
> I'll open an authorization page.
> Sign in with the Google account you want to use,
> then tap Allow.

[BACKGROUND] Open OAuth authorization URL
[VERIFY] Authorization successful before marking complete

> [Calendar] is connected ✓
>
> What should I be able to do?

[BUTTON] Read only — I can see your calendar
[BUTTON] Read and write — I can create and update events

---

**For already-connected connectors (from bootstrap):**

> I can see Google Calendar is already connected ✓
>
> What access should I have?

[BUTTON] Read only
[BUTTON] Read and write

[SAVE] CONNECTOR_[NAME] with access level

---

### B12 — GitHub backup

> Your workspaces, preferences, and settings back up
> to GitHub every night. If anything ever goes wrong,
> everything can be restored.
>
> *Why: GitHub is your safety net. If this machine breaks, gets lost, or needs a fresh install,
> your entire HELM setup restores in about 5 minutes from the backup. It's free and private.*

[BACKGROUND] Check for GitHub token in HELM Vault

**If token found (from setup earlier in Cowork):**

> GitHub is already connected from setup ✓
>
> Testing connection...

[BACKGROUND] Verify GitHub access
[BACKGROUND] Run first backup

> First backup complete ✓
> Your settings are backed up nightly.

---

**If token not found:**

> We need to connect GitHub for nightly backups.
> I'll open GitHub's settings page — takes about 3 minutes.
>
> Ready?

[BUTTON] Let's do it
[BUTTON] Skip for now — remind me later

**If "Let's do it" (walks through PAT creation):**

> **Step 1 of 5**
> I've opened GitHub settings. Click 'Developer settings' at the bottom of the left sidebar.

[BUTTON] Done ✓  [BUTTON] I'm stuck

> **Step 2 of 5**
> Click 'Personal access tokens' → 'Tokens (classic)'

[BUTTON] Done ✓  [BUTTON] I'm stuck

> **Step 3 of 5**
> Click 'Generate new token (classic)'
> Note: type 'HELM backup'
> Expiration: No expiration (so HELM always has access)

[BUTTON] Done ✓  [BUTTON] I'm stuck

> **Step 4 of 5**
> Check the box next to 'repo' (top of the list)
> Then scroll down and click 'Generate token'

[BUTTON] Done ✓  [BUTTON] I'm stuck

> **Step 5 of 5**
> You'll see a long string starting with 'ghp_'
> Copy it and paste it here:

[TEXT] GitHub token (starts with ghp_)

[BACKGROUND] Save token to HELM Vault
[BACKGROUND] Verify GitHub access
[BACKGROUND] Run first backup

> ✓ GitHub connected. First backup complete.

[SAVE] GITHUB_USERNAME, GITHUB_BACKUP_REPO, GITHUB_TOKEN_VAULT_REFERENCE

---

### B13 — Computer Use

**Mode 1 (clean machine):**

> Computer Use lets me control the screen of the machine where HELM is installed
> (not necessarily the device you're reading this on now).
> This lets me log into websites, fill out forms, and extract data from apps
> that don't have a direct integration.
>
> On a dedicated HELM machine, it's safe — I only see what's on that machine
> and only act when you've approved the task type.
>
> Note: the first time I use Computer Use, I'll let you know what I'm about
> to do and what I can see. After that first time, I'll just do it silently.

[BUTTON] Authorize — do it when needed without asking each time
[BUTTON] Authorize — but ask before each new type of task
[BUTTON] Not right now — I'll set this up later

---

**Mode 2 (daily machine):**

> Computer Use would see everything on your daily machine — personal files,
> accounts, other apps. Most people on a daily machine choose 'Ask each time.'

[BUTTON] Authorize — ask me before each task
[BUTTON] Not right now

[SAVE] COMPUTER_USE_AUTHORIZED, COMPUTER_USE_TRUST_LEVEL

---

### B14 — Quiet hours

> Are there times when you don't want notifications?

[BUTTON] Yes — set quiet hours
[BUTTON] No — notify me anytime

---

**If setting quiet hours:**

> When should I hold notifications?

Start time: [TIME PICKER — default 10:00 PM]
End time: [TIME PICKER — default 7:00 AM]

> During quiet hours, notifications are held and
> delivered when your quiet period ends.

[BUTTON] Set these hours ✓

[SAVE] NOTIFICATION_QUIET_HOURS_START, NOTIFICATION_QUIET_HOURS_END

---

### B14b — Mobile alerts (optional — recommended)

> One more thing: if your internet or Discord goes down,
> how do I reach you?
>
> ntfy is a free app that sends alerts to your phone
> even when Discord is unreachable. Takes 2 minutes to set up.
>
> You can skip this now and set it up later —
> but if your system ever goes dark, you won't know until
> you check Discord manually.

[BUTTON] Set up now (2 min)
[BUTTON] Remind me later
[BUTTON] Skip — I'll manage without it

---

**If "set up now":**

> 1. Install ntfy from the App Store or Google Play
> 2. Create a free account at ntfy.sh
> 3. Paste your ntfy topic URL here:

[TEXT] ntfy topic URL — e.g. https://ntfy.sh/your-topic-name

[BACKGROUND] Test ntfy connection — send "HELM setup test" notification.

> Got it — test notification sent. Check your phone.

[BUTTON] I see it ✓
[BUTTON] I don't see it — help

[SAVE] NTFY_TOPIC_URL, NTFY_ENABLED

---

**If "remind me later":**

[BACKGROUND] Schedule weekly nudge in #helm-improvements with:
"ntfy mobile alerts aren't set up yet. Without them, you won't know if HELM
goes offline unless you check Discord manually. Want to set it up now?"

---

### B14c — Recovery setup

> Last piece of recovery: four optional pieces that let me (or you)
> restart HELM if everything goes down at once.
> Skip anything you don't want to set up — you'll get a weekly
> nudge to come back to it.

> **1. VPS login URL (optional)**
> If you have a VPS, where do you log into it from a browser?
> This lets you restart the server remotely if the machine
> can't be reached any other way.

[TEXT] VPS provider web console URL (optional) — e.g. https://cloud.digitalocean.com/droplets
[BUTTON] Skip — no VPS

> **2. Healthchecks.io heartbeat (optional)**
> HELM can ping a Healthchecks.io monitor every hour.
> If it stops pinging, Healthchecks.io emails you automatically —
> no Discord or ntfy needed. Takes 2 minutes to set up.
>
> Don't have an account? It's free for personal use.
> healthchecks.io → New Check → copy the ping URL.

[TEXT] Healthchecks.io ping URL (optional) — e.g. https://hc-ping.com/xxxxxxxx
[BUTTON] Skip

[BACKGROUND] If ping URL provided: save to RECOVERY_HEALTHCHECKS_URL in CONFIG.md
[BACKGROUND] Add hourly ping cron job to HELM watchdog

> **3. Emergency contact**
> If Discord and ntfy and Healthchecks.io are all unreachable,
> who else can alert you? (SMS, another email, a friend with access)

[TEXT] Secondary contact — e.g. email@example.com or phone number (optional)
[BUTTON] Skip

> **4. Recovery prompt (auto-created for you)**
> A personalized recovery guide is being pinned to your private #recovery channel.
> It includes a prompt you can paste into any AI chat app to rebuild HELM from scratch.
>
> The pinned message includes a button:
> **[Copy recovery prompt]** — tap it to copy to clipboard, then paste into any AI chat.
> Works with Claude.ai (free), ChatGPT (free), Gemini (free) — any major AI.

[BACKGROUND] If VPS URL provided: save to RECOVERY_VPS_CONSOLE_URL in CONFIG.md
[BACKGROUND] If Healthchecks.io URL provided: save to RECOVERY_HEALTHCHECKS_URL in CONFIG.md
[BACKGROUND] If contact provided: save to RECOVERY_SECONDARY_CONTACT in CONFIG.md

[BACKGROUND] Auto-pin in private #recovery channel:
"**If HELM goes completely dark, use this prompt:**

[RECOVERY PROMPT — personalized: agent name, Discord server ID, machine info,
GitHub backup location, Healthchecks.io URL if set, VPS console URL if set,
step-by-step rebuild instructions. LLM-agnostic — works with any AI chat.]

[BUTTON: Copy recovery prompt to clipboard]

Also pin: VPS console URL | Healthchecks.io dashboard | GitHub backup URL"

[SAVE] RECOVERY_VPS_CONSOLE_URL, RECOVERY_HEALTHCHECKS_URL, RECOVERY_SECONDARY_CONTACT, RECOVERY_CHANNEL_ID

---

### B14d — Deferred item nudges

[BACKGROUND] For any setup item skipped with "remind me later" (ntfy, GitHub backup,
recovery setup), schedule weekly reminder in #helm-improvements. Format:
"[Item] isn't set up yet.
Why it matters: [specific consequence — e.g. 'You won't know if HELM goes offline']
[BUTTON] Set it up now (2 min)"

Nudges continue weekly until the item is completed. User can silence with "don't remind me."

---

### B15 — Standing preferences

> Is there anything you always want in things I build?
> Tap any that apply — these become rules I follow for everything.
> Add custom ones at the bottom. Update anytime in #preferences.

[Toggle — tap to select, tap again to deselect]

☐ Always include an export option (CSV, PDF, etc.)
☐ Always show me the source data, not just a summary
☐ Always give me a TL;DR at the top
☐ Always give me a way to undo or roll back
☐ Always explain your reasoning, don't just give me the answer
☐ Always show confidence level when you're estimating
☐ Never show me more than 10 items at once — paginate
☐ Always flag when something might affect money or data
☐ Show me mobile-friendly output — no wide tables
☐ Always include a timestamp on data or reports

[BUTTON] Add my own →

**If "Add my own":**
[TEXT] What would you always want? [free text]

After each entry:
> Added: '[preference]' ✓

[BUTTON] Add another
[BUTTON] Done

[SAVE] STANDING_PREFERENCES in VOICE-AND-STYLE.md

---

### B16 — Daily briefing setup (optional)

> A daily briefing posts every morning — a summary of what matters today.
> Calendar events, email highlights, tasks due, anything you track.
>
> This is optional — you can set it up now, skip it, or build it later
> as your first workspace.

[BUTTON] Set it up now (5 minutes)
[BUTTON] Quick start — use defaults, customize later
[BUTTON] Skip — I'll set it up later as a workspace

---

**Quick start path:**

[BACKGROUND] Activate default briefing:
- Today's calendar
- Outstanding decisions
- HELM system status

Proceed to B17.

**Skip path:**
[BACKGROUND] Note: daily briefing not configured. Suggest as first workspace at B21.
Proceed to B17 (sample is skipped).

---

**Full setup path:**

> **Always included (these are always on):**
> ✓ Today's executive summary
> ✓ Outstanding decisions waiting for you
> ✓ HELM system status

---

> **From your connected tools:**
> (Only tools you've connected are shown)

[Toggle — on by default, tap to turn off]
✓ Today's calendar events
✓ Upcoming conflicts and prep needed
✓ Unread email summary

**If email shown:**

> How many unread emails to summarize?

[BUTTON] Top 5
[BUTTON] Top 10
[BUTTON] Top 20

---

[Toggle continued]
✓ New Slack messages (if connected)
✓ Tasks due today (if task manager connected)

---

> **Optional additions:**

[BUTTON] 📰 Top news →
**If selected:**
> What topics?
[TEXT] e.g., tech, finance, Seattle [free text]

> How much detail?

[BUTTON] Just headlines
[BUTTON] Short summaries
[BUTTON] Major developments only

---

[BUTTON] 🌤 Weather →
**If selected:**
> Which city?
[TEXT] [free text — default from ABOUT-ME.md location]

---

[BUTTON] 📡 RSS feeds →
**If selected:**
> Paste feed URLs (one per line):
[TEXT] [multi-line text field]

---

> **Proactive suggestions:**
> (All on by default — tap to turn off)

✓ Draft messages for birthdays and key dates
✓ Flag decisions needing attention
✓ Surface connections from your captures
✓ Flag tasks due today

---

> **How long should it take to read?**

[BUTTON] Under 2 minutes — keep it short
[BUTTON] Under 5 minutes — I have time
[BUTTON] As long as needed — don't cut anything

---

> **What time each day?**

[TIME PICKER — default 7:00 AM]

[SAVE] All briefing preferences to CONFIG.md

---

### B17 — Briefing sample

[BACKGROUND] Generate real sample briefing using
             connected calendar and email data]

> Here's what your briefing will look like:

[SAMPLE BRIEFING POSTED — uses real data, not fake]

> How does this feel?

[BUTTON] Looks great ✓
[BUTTON] Too long — trim it
[BUTTON] Too short — add more
[BUTTON] Change the format
[BUTTON] Adjust something specific →

---

**If adjustments requested:**
Make changes. Show updated sample.
Repeat until: [BUTTON] Looks great ✓

---

### B18 — Discord tour

> Want a quick tour of your Discord server?
> Takes about 2 minutes — I'll show you each channel with an example.

[BUTTON] Show me around
[BUTTON] Skip — I'll explore on my own

---

**If Show me around:**

[BACKGROUND] Post a series of screenshots captured during CI testing, showing each
             channel with real default content. One screenshot per channel group,
             annotated with arrows and labels. Shown as embedded images in Discord.

> Here's how your server is organized:

[EMBED: image of #general, #new-workspace, #capture with labels]

> **Where work happens:**
> → **#general** — your main channel for ideas and quick asks. Post anything here.
> → **#new-workspace** — say "I want to automate X" and I'll walk you through it.
> → **#capture** — save links, notes, screenshots here. They go into your second brain.

[EMBED: image of a workspace channel with sample output]

> **Where outputs land:**
> Each automation you build gets its own channel.
> Everything about that automation — results, status, conversation — lives there.
> They appear under 'Active Workspaces' as you build them.

[EMBED: image of system channels]

> **System channels:**
> → **#helm-improvements** — my suggestions, updates, and things that need your attention
> → **#notify** — time-sensitive alerts (only the important stuff)
> → **#help** — questions about how anything works
> → **#feedback** — rate things, tell me what's working or not
> → **#preferences** — change any setting anytime

> Two things worth knowing:
> → **👎 on any message** = that didn't work for me. I track patterns and improve.
> → **Bookmark (🔖)** on any message = save it permanently to your second brain.
>    Use it on useful outputs, interesting captures, or anything you want to come back to.

[BUTTON] Got it — continue ✓
[BUTTON] Tell me more about [specific channel] →
[BUTTON] I have a question →

---

### B19 — The trust the process reminder

> One thing that leads to better results:
>
> When you come to me with an idea, describe the problem
> you want to solve — not the solution you're picturing.
>
> If you say 'I need a spreadsheet,' you'll probably get
> a spreadsheet. But the right answer might be a dashboard,
> a weekly email, or a simple alert you hadn't considered.
>
> And if along the way you still decide you want a spreadsheet,
> you'll absolutely get there.
>
> The more you tell me about what's frustrating or what you
> wish just happened automatically, the better I can help.

[BUTTON] Got it ✓
[BUTTON] I have a question about this →

**If question:**
[Handle the question in-chat, then return to onboarding]
> Ready to keep going?
[BUTTON] Continue setup ✓

---

### B20 — Feedback and bookmarks

> Two reactions worth knowing:
>
> **👎 (thumbs down)** — shows on every message I send.
> Tap it when something didn't land — wrong format, wrong level of detail,
> missed the point. I track patterns and improve.
>
> **🔖 (bookmark)** — tap it on any message to save it permanently.
> Bookmarked messages go into your second brain and stay there forever —
> even if the channel is cleaned up. Good for useful outputs,
> interesting links you saved, or anything you want to come back to.
>
> You can add these reactions to any message by long-pressing (mobile)
> or hovering and clicking the emoji icon (desktop).
>
> Not required — but the more you use them, the smarter HELM gets.

[BACKGROUND] Pin a message in #general:
"Quick reactions you'll use often:
→ 👎 on any of my messages = didn't work for me (I track this and improve)
→ 🔖 bookmark on any message = save it to your second brain permanently"

---

### B21 — Onboarding complete

[BACKGROUND] Set ONBOARDING_COMPLETED = true in CONFIG.md
[BACKGROUND] Run system validation + end-to-end verification sequence
[BACKGROUND] Run capability audit in background (async — does not block user)
             Note: capability audit can be triggered any time with "audit my capabilities"
             in any channel. Running here just seeds an initial baseline.
[BACKGROUND] Queue first backup to run tonight at 11pm

**[UX: This is a real milestone — celebrate it. P8. Don't bury it in a status list. Lead with what they've built.]**

> You're done.
>
> Progress: ██████████ 100%
>
> Here's what you built today:
>
> ✓ [AGENT_NAME] is running — online 24/7, restarts automatically
> [IF daily briefing] ✓ Daily briefing arriving tomorrow at [TIME]
> [IF connectors] ✓ Connected to: [list — Calendar, Gmail, Drive, etc.]
> ✓ Settings backed up to GitHub every night
> [IF ntfy] ✓ Mobile alerts set up — even if Discord is down
>
> From here: describe anything you wish just happened automatically.
> I'll build it with you.
>
> Your friends who told you about this? They probably started with one of these:

> Ready to build your first automation?
>
> Here are some things other HELM users have started with:
> [BUTTON] 📊 Daily briefing — your morning summary
> [BUTTON] 📧 Email triage — surface what actually needs your attention
> [BUTTON] 📋 Task tracker — never lose track of what you're working on
> [BUTTON] 📈 Weekly digest — topics and metrics you care about
> [BUTTON] 💡 I have my own idea →
>
> Or head to #new-workspace and describe anything you wish just happened automatically.
>
> HELM posts an "Emergency Pause" button in your main channels.
> If anything ever feels off, use it — I'll stop and show you exactly what was happening.

[BACKGROUND] Post framing in #helm-improvements:
"🛑 **Emergency pause** — if HELM is doing something you want to stop, type `pause` here
or in any channel. I'll halt everything and show you what was running.
[BUTTON: Emergency Pause]
This button is always here."

[BACKGROUND] Post framing in #general:
"[AGENT_NAME] is set up. Head to #new-workspace any time you want to build something.
Type `pause` in any channel to stop all activity immediately."

---

## IMPLEMENTATION NOTES

### What's saved to CONFIG.md during onboarding:

```
PAP_MODE
AGENT_NAME
USER_PREFERRED_NAME
TIMEZONE
LOCALE
DISCORD_SERVER_ID
DISCORD_BOT_TOKEN_VAULT_REFERENCE
COMPUTER_USE_AUTHORIZED
COMPUTER_USE_TRUST_LEVEL
OUTPUT_DESTINATION
OUTPUT_DRIVE_PREFERENCE
OUTPUT_ACCOUNT_EMAIL
CONNECTOR_GOOGLE_CALENDAR
CONNECTOR_GMAIL
CONNECTOR_GOOGLE_DRIVE
[other connectors]
USAGE_WARNING_THRESHOLD
USAGE_REPORTING_FREQUENCY
COST_OPTIMIZATION_PREFERENCE
IMPROVEMENTS_FREQUENCY
IMPROVEMENTS_MAX_SURFACED
NOTIFICATION_QUIET_HOURS_START
NOTIFICATION_QUIET_HOURS_END
GITHUB_USERNAME
GITHUB_BACKUP_REPO
GITHUB_TOKEN_VAULT_REFERENCE
ONBOARDING_COMPLETED = true
ONBOARDING_COMPLETED_DATE
ASSUMPTIONS_EXPLAINED = false
```

### What's saved to VOICE-AND-STYLE.md:

```
PREFERRED_TONE
RESPONSE_LENGTH_PREFERENCE
INFORMATION_STYLE
DISPLAY_MODE
COLOR_PRIMARY
COLOR_ACCENT_1
COLOR_ACCENT_2
STANDING_PREFERENCES
```

### What's saved to ABOUT-ME.md:

```
AGENT_NAME
USER_PREFERRED_NAME
GOOGLE_EMAIL
TIMEZONE
DISCORD_SERVER_ID
```

### Resumption rule:

Every step saves ONBOARDING_STEP to CONFIG.md.

**Auto-resume (primary path):** When user posts in any channel and ONBOARDING_COMPLETED is false,
HELM checks the step and resumes automatically — the user doesn't need to type any command.
"Hey, I see we were in the middle of setup at step [N]. Want to continue now? [BUTTON: Resume] [BUTTON: Later]"

**On-demand resume:** Typing "setup", "onboarding", or "continue setup" in any channel also resumes.

**Scheduled nudge:** If ONBOARDING_COMPLETED is false and no onboarding activity in the past 24 hours,
HELM posts in #general: "Setup isn't finished yet. Pick up where you left off? [BUTTON: Resume setup]"
Nudge frequency: daily until complete, then stops. User can silence with "don't remind me about setup."

The user never loses progress — setup state persists across restarts, crashes, and multi-day gaps.

### Step ordering rationale:

1. Machine type → affects security warnings throughout
2. Prerequisites → must be done before any connections
3. Agent naming → sets tone for all subsequent messages
4. HELM Vault → MUST happen before bot token collection
5. Bot creation → token goes directly vault, never intermediate
6. Bot connection → hands off to Discord
7. All preference steps in Discord → any device, not Mac Mini
8. Briefing setup → immediately useful, validates connectors work
9. Briefing sample → confirms everything works end-to-end
10. Tour + trust the process → sets expectations correctly
11. Complete → directs to first workspace

### Credentials security:

Bot token: developer portal → HELM Vault only
           Never typed into a chat message
           Never stored in a config file
           Read by bootstrap/Claude Code from vault

GitHub PAT: github.com → HELM Vault only
            Read by backup script from vault

Google OAuth: never stored — token managed by Cowork connector

### Error recovery:

Every step has [I'm stuck] fallback.
Bootstrap errors saved to ~/Desktop/pap-bootstrap-log.txt.
Mid-onboarding issues handled by help agent in Discord.
"/onboarding" always resumes from last saved step.

---

### Platform support:

Bootstrap and onboarding support Mac, Windows, and Linux/VPS.
All three have been scoped as first-class targets (not Mac-only).
Platform-specific differences are handled transparently:
- Mac: screencapture + AppleScript for GUI
- Windows: PowerShell equivalents, winget for package management
- Linux/VPS: apt/homebrew-on-linux, systemd for process management
1Password CLI available on all three platforms.

### Credential/vault strategy:

Users are not required to use 1Password.
If user has no password manager: credentials encrypted locally using
platform keychain (Keychain Access on Mac, Credential Manager on Windows,
Secret Service on Linux). Vault abstraction layer handles both cases.
User is shown tradeoffs at bootstrap (password manager = more secure,
easier recovery; local encryption = no extra account required).

### Cost transparency:

Bootstrap shows estimated monthly costs before any setup begins.
Claude API charges are the user's primary cost. All optional
integrations (ntfy, VPS, custom domain) are clearly labeled as optional.
Onboarding never implies required spend beyond Claude API.

### End-to-end verification:

Final step before B21 COMPLETE: automated verification sequence.
  1. Send test message to #general — confirm routing works
  2. Post to #capture — confirm second brain ingest works
  3. Trigger daily briefing generation — confirm connectors work
  4. Check all connected services respond
  5. Report: "X of Y checks passed" before marking complete
If any check fails: show specific fix, offer to retry, never silently proceed.

### Error handling (runtime, post-onboarding):

**Self-heal policy:** HELM tries to fix it silently first.
User only sees it if HELM can't fix it AND it affects something they care about.

**Auto-heal (silent, never shown to user):**
- API rate limit → exponential backoff, auto-retry up to 5×, no notification
- Transient network error → retry up to 3×, then escalate
- Bot process crash → watchdog restarts in <30s, posts "Back online" in
  #helm-improvements, no user action needed
- Expired OAuth token → auto-refresh using stored refresh token, silent
- Healthchecks.io ping failure → retry 3× before marking down

**Notify but no action needed (one-line message, no wall of text):**
- API retry succeeded after >3 attempts: "Had some trouble with [service] — sorted now."
- Bot restarted: "Back online after a brief restart."
- Connector reconnected: "[Service] reconnected."

**User action required (tap-to-fix, not a wall of text):**
- Connector auth expired past refresh: "[Service] disconnected — tap to reconnect" [BUTTON]
- Vault read failure → hard stop + BLOCK — never ask user to retype credentials in chat
- Bootstrap failure → error logged to Desktop, help agent walks user through specific fix in Discord
- 3 consecutive crashes within 1 hour → escalate to user: "Something keeps crashing — I need your help."

**Pick up where you left off (resumption design):**
- Every multi-step task writes a checkpoint after each step
- On restart: agent reads checkpoint, announces "Picking up [task] from step [N]"
- User never needs to re-explain what they were doing
- Long-running tasks (>5 min) post a "Still working on [X]" update every 3 min
- On failure mid-task: "I was [doing X] and hit a problem. Here's where we are: [state]. Want me to retry or try a different approach?"

### Testing environments:

Three simulated environments for pre-release validation:
1. Mac: native (CI via GitHub Actions macOS runner)
2. Windows: UTM VM or GitHub Actions windows-latest runner
3. Linux/VPS: Docker container (ubuntu:22.04 + bash bootstrap)
Bootstrap script must pass on all three before distributable repo ships.
Onboarding flow tested via Fakechat on each platform.

---

### Core HELM package — what ships in the repo:

**Agents (all core — every instance gets these):**
- bot.js — Discord connection and message routing
- dispatcher agent — routes every incoming message to correct agent
- help agent — handles #help, #feedback, #preferences, system health
- curiosity agent — idea intake, workspace scoping (#new-workspace)
- scaffolder agent — creates workspace folders and initial files
- pm agent — product manager, weekly steward, proactive improvements
- steward agent — weekly system health, backlog review
- engineer agent — queued implementation tasks
- executor agent — launches and validates deployments

**Discord channels (all core — bot creates these on first run):**
- #general — main conversation
- #new-workspace — idea intake
- #capture — second brain drops
- #help — questions, troubleshooting
- #feedback — user feedback queue
- #preferences — live config changes
- #helm-status — system health ("is everything working?")
- #helm-improvements — PM-level notifications, proposals, design
- #helm-audit — read-only decision log
- #daily-briefing — morning summary
- #notify — time-sensitive alerts
- #recovery — pinned recovery prompt (private, auto-created)

**Config files (templated — no user data):**
- CLAUDE.md — agent instruction root (personalized during onboarding)
- behaviors.md — required behaviors checklist
- ABOUT-ME.md — user profile template (filled during onboarding)
- VOICE-AND-STYLE.md — tone and formatting template
- CONFIG.md — system config template
- CAPABILITIES.md — empty template (auto-filled post-onboarding)
- DOC-MATRIX.md — documentation requirements by action class
- turn-protocol.md — agent turn protocol
- USER-PROFILE.md → USER-PROFILE.md (renamed — template, no personal data)

**Scripts (all core):**
- bootstrap.sh — one-time install script (Mac/Win/Linux variants)
- discord-post.sh — posting to Discord
- queue-write.sh — atomic queue writes
- queue-restart.sh — queued bot restart
- safe-restart.sh — immediate restart (force path)
- pap-health-check.sh — system health check
- generate-recovery-prompt.sh — personalized recovery guide
- read-lessons.sh — agent lesson loading
- pre-deploy-security-check.sh — security gate for web deploys
- watchdog.sh / launchd plist — process auto-restart

**Skills (all core):**
- vault — credential reads
- lean-startup — BML loop
- capability-audit — pre-build capability check
- bml-memory-checkpoint — durable learnings
- output-validator — pre-delivery verification
- skill-import — external skill intake
- curiosity-interviewer — intake interview technique
- pap-architecture-guide — architectural constraints

**Optional (installable after core, not shipped by default):**
- Workspace agents (ETF tracker, options helper, etc.)
- reddit-researcher skill
- video-transcriber skill
- Desktop app developer skill
- Any workspace-specific CLAUDE.md files

**Excluded from repo (user data — never ships):**
- Any file with user's real name, email, or Discord server ID
- Vault credentials or references
- Workspace history, decision logs, work-items.json
- channel-state/*.json
- pap-audit.log, decisions-log.md, friction-log.md
- Second brain content (~/pap-workspace/second-brain/)
- Memory files (~/.claude/projects/*/memory/)
- engineer-queue.md (user-specific backlog)

**Scrubbing strategy (thorough — A):**
Automated script (clean-for-repo.sh) replaces all user data with template placeholders:
- Real name → [YOUR_NAME]
- Email → [YOUR_EMAIL]
- Discord server ID → [YOUR_DISCORD_SERVER_ID]
- Agent name → [YOUR_AGENT_NAME]
- Vault references → [PAP_VAULT_ITEM_NAME]
Scrubbing is not purely mechanical — script surfaces any string that LOOKS personal (proper nouns, addresses, phone-number patterns, API key shapes) and asks the maintainer to review before accepting.
Script run before every version tag. CI (automated test suite, see below) fails if any real user data pattern is detected in the committed files.

---

### File categorization process (deciding what's in the repo):

**Step 1 — Inventory:** Run `find ~/pap-workspace ~/.claude/agents ~/.claude/skills ~/marvin-bot -type f | sort`
**Step 2 — Flag user-data patterns:** Script detects emails, phone numbers, server IDs, credential strings
**Step 3 — Core vs. optional:** Core = required for basic HELM function. Optional = workspace-specific or specialized capability.
**Step 4 — Template:** Any core file with user data gets a template version with placeholders.
**Step 5 — Exclusion list:** Files that are outputs/logs (not inputs) stay out of the repo permanently.

---

### Emergency pause (user-initiated, #helm-improvements):

Users can pause all HELM activity from Discord at any time. This is a user-initiated safety valve, not an automated feature.

**How it works:**
1. User types "pause" or taps [BUTTON: Emergency Pause] in #helm-improvements
2. HELM immediately stops all in-flight agents (SIGTERM to running processes)
3. Posts in #helm-improvements: "Paused. Here's what was running: [task list with checkpoint state]. Nothing else will happen until you resume."
4. Shows: [BUTTON: Resume | Roll Back Last Task | Leave Paused]

**Resume path:**
- Tap Resume → HELM picks up each interrupted task from its last checkpoint, announces "Resuming [task] from step [N]"

**Roll Back path:**
- Tap Roll Back → HELM shows exactly what will be undone (files changed, messages sent, queue items)
- [BUTTON: Confirm Rollback | Cancel]
- On confirm: reverts git-tracked changes, removes queued items, posts "Rolled back [task]. State is now: [description]."
- Cannot roll back: messages already posted to Discord, emails already sent, deployed changes already live

**Leave Paused path:**
- Nothing runs. User can resume later. HELM remains responsive to direct questions but does not take any autonomous actions.

**Onboarding awareness:**
- B18 includes a brief explanation: "You can pause me at any time. Just say 'pause' in your main channel. I'll stop everything and show you what was happening."
- #recovery channel has the pause command pinned.

**Onboarding explanation for emergency pause (B18 script):**
> "One more thing before we wrap up setup.
>
> HELM can run tasks in the background — things you asked for, plus a few things I do proactively. If something ever feels wrong, you can stop everything immediately.
>
> Just type **pause** in any channel, or tap the Emergency Pause button in your main channel.
>
> I'll freeze all running tasks, show you exactly what was happening, and wait for your direction. Nothing restarts until you say so."
>
> [BUTTON: Got it — continue setup]

**#helm-improvements pinned notice (posted at end of onboarding):**
> 🛑 **Emergency pause** — if HELM is doing something you want to stop, type `pause` here or in any channel. I'll halt everything and show you what was running.
>
> [BUTTON: Emergency Pause]
>
> This button is always here. You can also type `pause` or `stop everything` at any time.

---

### Update delivery (bundled, not click-OK-each-time):

HELM updates are packaged and deployed silently when low-impact, with a single notice when they're ready.

**Update flow:**
1. New version available → PM posts one message in #helm-improvements: "Update ready (v[X.Y]): [1-2 sentence summary of what changed]. [BUTTON: Install Now | Later]"
2. "Install Now" → HELM downloads, runs bootstrap update, restarts, posts "Updated. Back online."
3. "Later" → update queued for next natural restart
4. Multiple small updates → bundled into one notice, one button click

User never sees individual file changes, dependency updates, or intermediate steps. The summary is always in plain English ("Added 3 new palette options", "Fixed a bug where briefings were late on Sundays").

---

### Terminal usage (zero-terminal aspiration):

Goal: users never need to open Terminal after initial bootstrap.
Bootstrap is the one-time exception. All subsequent operations (updates, config changes, troubleshooting) are Discord-first.
"Claude cowork" or a clean-machine GUI tool can replace terminal for power users who want to inspect files.
This is an aspiration for v1 — some edge cases (advanced troubleshooting, custom integrations) may require terminal. These are clearly labeled as "advanced" in docs.

---

### Platform support — deployment topology (D16):

**Primary compute: VPS (Linux)**
- Core HELM runs on VPS: Discord bot, all agents, scheduler, watchdog
- Recommended: 2GB RAM, Ubuntu 22.04, any cloud provider
- VPS = always-on, no dependency on user's local machine being awake

**Secondary compute: Mac Mini (for Computer Use)**
- Mac Mini hosts Computer Use capabilities (screencapture, AppleScript, GUI automation)
- Not required for core HELM — users without Mac Mini get all features except CU
- Onboarding clearly labels Mac Mini as optional / "unlocks Computer Use"

**User can mix and match:**
- VPS-only: full HELM minus Computer Use
- Mac Mini-only: full HELM including Computer Use, but dependent on Mac being on
- Both: full HELM + Computer Use, VPS provides always-on reliability

---

### CI (Continuous Integration) — what it means for HELM (D14 = A):

CI = automated tests that run every time the HELM repo gets an update.
Concretely: when the maintainer pushes a change to GitHub, GitHub Actions automatically:
1. Spins up a Mac runner, a Windows runner, and a Linux runner
2. Runs bootstrap.sh on each one
3. Runs the onboarding Fakechat simulation on each one
4. Runs a data scrub pass on each generated config
5. Fails the release if anything breaks on any platform

Users downloading HELM get a version that's been automatically verified to install correctly on all three platforms. "CI passes" = green checkmark on GitHub = safe to install.
CI does NOT mean users need to run tests themselves. It's a maintainer-side quality gate.

**Platform test matrix (all three required for every release):**
- macOS (GitHub Actions macos-latest runner)
- Windows (GitHub Actions windows-latest runner) — PowerShell bootstrap path
- Linux/VPS (GitHub Actions ubuntu-latest runner) — systemd service path

A release cannot ship if any platform fails CI. All three must pass.

---

### First workspace suggestion (examples-first, D13):

When onboarding reaches B21 (first workspace), HELM doesn't just ask "what do you want to build?" — it shows examples from real HELM users and top agentic AI use cases.

**Example suggestions shown (researched — top use cases):**
1. Daily briefing customizer — tune your morning summary
2. ETF/portfolio tracker — weekly performance snapshots
3. Email triage assistant — surface what actually needs your attention
4. Meeting notes → action items — auto-extract from transcripts
5. Research digest — weekly summary of topics you track
6. Expense categorizer — auto-tag and summarize spending
7. Content calendar — draft ideas, schedule reminders

User can pick from examples, describe their own idea, or skip.
Research note: Agentic AI use case research to be done before this step ships — examples should reflect actual community patterns, not just HELM brainstorming.

---

### Issues → PM proposals (D17) — revised design:

When a user encounters something HELM doesn't do (an unmet need, a missing capability, a different way they'd like HELM to work):

1. **HELM implements it for this user** — adapts locally, no gate
2. **After it works, HELM asks once:** "That worked. This might be useful for all HELM users. Want to suggest it as a feature?"
3. **If yes:** PM drafts a formal proposal in plain English, posts it in #helm-improvements for the user to review and approve
4. **Once approved:** PM packages it into a structured proposal (what it does, why it's useful, implementation notes)
5. **Proposal sent to central HELM maintainer** via GitHub issue on the official HELM repo — tagged as "user proposal"

The maintainer reviews proposals across all instances and decides which become official HELM capabilities.

**What the user sees:** "I suggested 'weekly briefing tone change' to the HELM team. [View proposal]" — links to the GitHub issue.

**What the maintainer sees:** A structured proposal with real-world context ("3 separate users asked for this").

**Not a support ticket.** Users never have to write a bug report or feature request themselves. PM does the work.

**Onboarding framing (B21):** "If you ever want HELM to work differently, just ask. I'll try to make it work for you — and if it's useful, I'll suggest it to the team so other users can benefit too."

**D17 open question (deferred):** What happens when a user's HELM instance falls behind because they haven't gotten an official update yet? Central maintainer proposals may require HELM version N+1. Version + proposal compatibility TBD.

---

### Preferences are always changeable (D5):

Every setting configured during onboarding can be changed anytime via #preferences. Nothing is permanent. HELM's answer to "can I change this later?" is always yes.
Onboarding uses language like "you can change any of this anytime in #preferences" rather than "choose carefully."


---

## Distributable Repo — Full Gap Audit
**Date: 2026-06-05 | Status: Open for design decisions**

This section enumerates every known gap between {{USER_JERRY}}'s functional HELM and a blank-slate repo that a new user can install, configure, and run without {{USER_JERRY}}'s context or data.

Gaps are split: **addressed in spec** (decided) vs **needs design input** ({{USER_JERRY}} call required).

---

### GAP CATEGORY 1 — Distribution & Installation

**G01 — No public repo** *(known, previously documented)*
The install path doesn't exist. A new user has no URL to clone from. This blocks everything else.
*Addressed: acknowledged, first build task after spec is locked.*

**G02 — No one-line install command**
Currently requires manual cloning, running multiple scripts, and editing config files. The gold standard is a single bootstrap command like `curl -fsSL helm.sh/install | bash`. Even without that, the install experience should be: clone → run bootstrap.sh → answer a few questions → done.
*Addressed: bootstrap.sh spec covers this. Needs platform variants (Mac/Win/Linux).*

**G03 — No dependency manifest**
No documented list of required versions (Node.js, Python, bun, whisper model, 1Password CLI). If a user has an older Node or missing bun, they get cryptic errors.
*Addressed in spec: bootstrap.sh must check all deps and either auto-install or surface a clear error.*

**G04 — Whisper download is large and silent**
The `base` model is ~140MB. If HELM auto-downloads it during install, users on slow connections wait with no progress bar. If it fails mid-download, there's no retry.
*Addressed: bootstrap.sh must show progress during Whisper download; offer to defer transcription capability if user declines. Not required for core HELM function.*

**G05 — QMD database initialization not documented**
The second brain database (QMD/SQLite) needs to be initialized on first run. Currently no initialization flow in onboarding.
*Addressed: QMD init is a B-step in onboarding; add B6b: "Setting up your second brain index — this takes about 30 seconds."*

**G06 — Discord bot app creation is undocumented**
Creating a Discord application, generating a bot token, setting permissions, and adding the bot to a server is a multi-step manual process. New users will get stuck here.
*Addressed: Add A-step guide with step-by-step screenshots (or a link to HELM docs page). Bot needs minimal permissions: read messages, send messages, manage channels, attach files.*

**G07 — No version tagging strategy**
HELM has no version number. When a new user installs, they don't know what "version" they have, and there's no way to tell them what changed in an update.
*Addressed: Define semantic versioning (v1.0.0 = first distributable release). Tag in GitHub. Include version in bot's health check output.*

---

### GAP CATEGORY 2 — Data Architecture (most critical)

**G08 — Code and user data share a directory**
Currently ~/pap-workspace contains both HELM system files (agents, skills, CLAUDE.md) and {{USER_JERRY}}'s personal data (second-brain/, channel-state/, memory/, workspace files). A git pull to update HELM would overwrite user data.
*Addressed: Define two-root architecture:*
- `~/.helm/system/` — HELM code, agents, skills (git-tracked, updateable)
- `~/.helm/user/` — personal data, second brain, memory (never touched by updates)
*CLAUDE.md includes $HELM_USER_DIR for all user-data references.*

**G09 — git history of current repo contains {{USER_JERRY}}'s data**
Can't fork {{USER_JERRY}}'s repo. Need a clean-history repo with only templated files. clean-for-repo.sh handles current state but git log would still show personal data.
*Addressed: New repo with no shared history. Not a fork — a fresh init with clean files only.*

**G10 — Memory starts empty for new users**
{{USER_JERRY}}'s MEMORY.md has 60+ entries. New users start with nothing, which is correct — but HELM needs to handle the empty-memory state gracefully (don't try to recall context that doesn't exist).
*Addressed: MEMORY.md template ships as an empty file. HELM behavior when memory is empty: proceed without memory context, don't mention its absence.*

**G11 — CLAUDE.md mixes system instructions with {{USER_JERRY}}-specific instructions**
The current CLAUDE.md contains {{USER_JERRY}}'s email, Discord server ID, specific channel IDs, and personal working hours. All of this needs to be in ABOUT-ME.md (user data) with CLAUDE.md only referencing it via `@ABOUT-ME.md` include.
*Addressed: Audit CLAUDE.md before repo creation. Move all personal data to ABOUT-ME.md. CLAUDE.md becomes fully generic system instructions.*

**G12 — No "new install" initialization flow**
What happens the first time a new user runs bot.js? It needs to detect "no user data exists" and trigger onboarding. Currently bot.js assumes user data exists.
*Addressed: bot.js startup check: if ABOUT-ME.md is empty or missing, route all messages to onboarding agent until setup completes.*

---

### GAP CATEGORY 3 — Credential & Auth Architecture

**G13 — Claude API key vs OAuth — new users use API keys**
{{USER_JERRY}}'s HELM authenticates via OAuth (Claude.ai subscription). New users will likely use a Claude API key (developer access). These are different auth paths with different cost structures and rate limits.
*Needs {{USER_JERRY}}'s input (see Q03 below)*

**G14 — 1Password CLI setup is non-trivial**
1Password CLI requires a separate install, signing in to a 1Password account, and creating a vault. For non-technical users this is a stumbling block.
*Needs {{USER_JERRY}}'s input (see Q04 below)*

**G15 — Vault item naming convention**
Current vault items use names like "{{USER_DOMAIN}} Site Auth" ({{USER_JERRY}}-specific). A generic HELM install needs standard names like "HELM Discord Bot Token", "HELM Claude API Key" that work for any user without renaming.
*Addressed: Define canonical vault item name list. bootstrap.sh creates them empty and guides user to fill them in.*

**G16 — .env file has no protection**
The Discord bot token lives in ~/marvin-bot/.env. No .gitignore, no permission restriction. A user who accidentally runs git init in that directory could commit credentials.
*Addressed: Add to bootstrap.sh: chmod 600 on .env; add .gitignore to ~/marvin-bot/ covering .env; warn during install if .env is in a git-tracked directory.*

---

### GAP CATEGORY 4 — Platform Differences

**G17 — Hardcoded paths throughout codebase**
`~/pap-workspace`, `~/marvin-bot`, `~/.claude/agents` appear in dozens of files. A user who wants to install to a different location is stuck.
*Addressed: Define HELM_HOME env var (default: ~/.helm). All scripts reference $HELM_HOME. bootstrap.sh exports it.*

**G18 — Process management per platform**
Mac: launchd plist. Linux: systemd unit file. Windows: Task Scheduler or NSSM. Three different startup configs — none of them templated.
*Addressed: Add three startup config templates to repo. bootstrap.sh detects platform and installs the right one.*

**G19 — Shell differences**
Scripts use bash/zsh syntax. Windows requires PowerShell equivalents for key scripts. Some bash-only features (string substitution, process substitution) don't translate.
*Addressed: Flag all scripts that need PowerShell variants. Windows support = Phase 2 unless effort is low.*

---

### GAP CATEGORY 5 — Onboarding UX

**G20 — No resume capability**
If onboarding is interrupted (bot crashes, user closes laptop, Discord goes offline), the user has to start over. No checkpoint state is saved during onboarding.
*Addressed: Onboarding checkpoints every section. A-step state, B-step state, and C-step state each persist to a dedicated onboarding-state.json. On restart: "Welcome back — picking up at step [N]." [BUTTON: Continue from step N | Start over]*

**G21 — No time estimate per section**
User doesn't know if setup takes 15 minutes or 3 hours. Without expectations, any step that takes more than 60 seconds feels broken.
*Addressed: Add time estimates to each major section header:*
- A (core setup): ~10 min
- B (configuration): ~15 min
- C (connectors): ~5 min each
- Total minimum (no optional steps): ~25 min
- Total with all optional steps: ~45 min

**G22 — No progress indicator**
User sees steps but doesn't see overall progress ("step 3 of 12"). For a long setup, progress visibility reduces abandonment.
*Addressed: Onboarding agent tracks section count and posts a progress bar emoji at each major section: `Progress: ████████░░ 80%`*

**G23 — Error handling per step is not fully designed**
What happens if the Discord token fails validation at step B6? Does onboarding stop? Retry? Skip? Each critical step needs an explicit error path.
*Needs {{USER_JERRY}}'s input (see Q05 below)*

**G24 — Mobile-first gap during setup**
Setup requires entering API keys and credentials, which is painful on mobile. The onboarding assumes desktop access but HELM's ongoing interface is Discord/mobile.
*Addressed: Note in pre-onboarding: "Setup works best on a desktop or laptop — it takes about 25 minutes and requires pasting some credentials. Once set up, everything runs from your phone."*

---

### GAP CATEGORY 6 — Recovery & Resilience

**G25 — Recovery prompt requires Claude.ai subscription**
The B14c recovery prompt (paste into Claude.ai if bot is unreachable) assumes the user has a Claude.ai subscription. API-key-only users may not have claude.ai access.
*Needs {{USER_JERRY}}'s input (see Q06 below)*

**G26 — ntfy topic security**
ntfy topics are public by default on ntfy.sh — anyone who knows your topic URL can send you fake alerts. HELM should guide users to use a private/authenticated topic.
*Addressed: B14b updated to recommend a private ntfy topic and show how to set one up. Also note: ntfy.sh self-hosted option exists for privacy-conscious users.*

**G27 — healthchecks.io setup is fully manual**
No automation exists for creating a healthchecks.io check, getting the ping URL, or configuring the interval. User must do all of this by hand.
*Addressed: Add step-by-step to B14c with the exact URL format and recommended interval (5 min).*

**G28 — Windows/Linux process restart strategy**
On Mac, launchd auto-restarts bot.js. On Linux/Windows, the equivalent process manager isn't configured or documented.
*Addressed: Covered by G18 (platform-specific process management). Flagged as a blocker for non-Mac installs.*

---

### GAP CATEGORY 7 — Update & Maintenance

**G29 — No update check mechanism**
HELM has no way to know a new version exists. Users stay on old versions indefinitely until they manually check.
*Addressed: PM job (runs weekly) checks GitHub releases API for the HELM repo. If a newer tag exists, posts in #helm-improvements: "HELM update available (v1.1.0): [summary]. [BUTTON: Install Now | Later]"*

**G30 — Database/state schema migrations**
If an update changes the structure of channel-state JSON or adds new fields to ABOUT-ME.md, existing installs may break. No migration strategy exists.
*Addressed: Add schema_version field to all state files. bootstrap-update.sh runs migration scripts (migrate/vX-to-vY.sh) in sequence before starting new version.*

**G31 — Skills/agents versioning**
New skills added to HELM may not auto-propagate to existing installs. Users could miss new capabilities indefinitely.
*Addressed: Update bundle includes new skill files. bootstrap-update.sh copies new skills to ~/.helm/system/skills/ without overwriting user-customized versions. User-modified skills are flagged with a diff.*

---

### GAP CATEGORY 8 — Security

**G32 — No .gitignore template**
Users setting up their own backup repo (D4) could accidentally commit credentials, second brain content, or sensitive workspace outputs.
*Addressed: Ship a .gitignore that excludes: .env, channel-state/, second-brain/, memory/, *.log, *.jsonl*

**G33 — Discord server permissions not specified**
HELM should run in a private server where only the owner has access. But new users might add HELM to an existing server with other members. No guidance on server permission setup.
*Addressed: Add A-step: "Create a new Discord server (private) for HELM. HELM works best in its own server — your conversations are personal and it'll be cleaner." [BUTTON: I'll create one | I want to use an existing server]*

**G34 — No privacy framing for sensitive capabilities**
When HELM accesses Gmail, calendar, or financial data, there's no explanation of what HELM stores vs. what it accesses in real-time. Privacy-conscious users need this.
*Addressed: B3b privacy briefing (already in spec) covers this. Flagged to ensure it runs before any OAuth connector step.*

---

### GAP CATEGORY 9 — Documentation

**G35 — No README for the repo**
First thing a potential user sees. Without it, the repo looks like a personal project, not a tool.
*Addressed: README template needed. Contents: what HELM is, what it does, install requirements, one-command install, link to docs.*

**G36 — No "what is HELM" onboarding video or walkthrough**
Text onboarding is good for technical users. Non-technical users benefit from seeing the finished product before committing to setup.
*Needs {{USER_JERRY}}'s input (see Q07 below)*

**G37 — No troubleshooting guide**
When something breaks post-install, where does the user go? Currently the only option is to ask HELM itself (which may be broken) or DM {{USER_JERRY}}.
*Addressed: Add troubleshooting section to docs: common error messages + fixes. Also: #help channel is the in-HELM support path — this is already designed.*

---

### Gaps addressed automatically (spec updated):
G01, G02, G03, G04, G05, G06, G07, G08, G09, G10, G11, G12, G15, G16, G17, G18, G19, G20, G21, G22, G24, G26, G27, G28, G29, G30, G31, G32, G33, G34, G35, G37

---

### Gaps addressed automatically (spec updated):
G01, G02, G03, G04, G05, G06, G07, G08, G09, G10, G11, G12, G15, G16, G17, G18, G19, G20, G21, G22, G24, G26, G27, G28, G29, G30, G31, G32, G33, G34, G35, G37

### Q01-Q08 Decisions — Locked 2026-06-05

**Q01 — Code/data separation:** Two-root architecture confirmed (~/.helm/system + ~/.helm/user). File categorization: run clean-for-repo.sh audit to produce a manifest; every file in ~/pap-workspace and ~/marvin-bot gets tagged system (ships in repo) or user (excluded). Result reviewed before repo init.

**Q02 — Onboarding sandbox:** Possibly — needs more design (see Round 2 below).

**Q03 — Claude API key vs OAuth:** Strongly encourage Claude.ai subscription (flat-rate, simpler). API key remains a valid fallback with a cost-transparency warning. Spec updated: A2 prerequisite now lists "Claude Pro or Max subscription (recommended)" as the first item.

**Q04 — Credential storage:** Must be encrypted. Use platform-native encrypted storage: macOS Keychain, Windows Credential Manager, Linux Secret Service (via libsecret). 1Password is the preferred path and gets full documentation. Non-1Password users get platform-native option — not a plain .env file.

**Q05 — Error handling during onboarding:** Loop back and fix. Every critical step that fails: explain what went wrong in plain English + guided correction flow. Never skip critical steps. User cannot advance until the step passes or explicitly marks it "I'll fix later" (which creates a deferred-item nudge).

**Q06 — Recovery without Claude.ai:** Recovery prompt is LLM-agnostic — any major AI chat (free tier is fine: Claude.ai free, ChatGPT free, Gemini free). Spec updated: recovery prompt section now says "paste into any AI chat app."

**Q07 — Video/demo:** Text-first. Video deferred to backlog. Ship text-only onboarding for close-friends beta.

**Q08 — First users:** A few close friends. {{USER_JERRY}} watches the install and gathers UI feedback. Scope: build as polished as possible before sharing.

---

## Round 2 — Open Design Decisions

**D-R2-01 — Q02 Sandbox / Demo Mode** ✅ DECIDED
Defer to broader launch. Close-friends beta doesn't need it — they'll have {{USER_JERRY}} watching. Backlog item added: "Demo mode — hosted walkthrough of HELM Discord for non-technical prospects before install commitment."

**D-R2-02 — Discord bot: shared vs. per-user** ✅ DECIDED
Per-user bot (A confirmed). Each user creates their own Discord application. HELM install wizard walks them through Developer Portal setup step by step.

**D-R2-03 — HELM brand/docs domain** ✅ DECIDED
GitHub for now. May move to a dedicated HELM domain later. All install docs point to GitHub README + GitHub Pages.

**D-R2-04 — Update delivery design** ✅ DECIDED
HELM proactively notifies + bundles. PM job checks GitHub releases weekly, bundles small updates, posts single notice in #helm-improvements with "Install Now / Later" buttons. User never sees individual file changes.

**D-R2-05 — Onboarding for non-Mac users** ✅ DECIDED
All 3 (Mac, Windows, Linux) from the start. Requires CI runners on all 3 platforms before v1 ships. Windows testing capability moved from backlog to v1 requirement.

**D-R2-06 — File separation: how to categorize current {{USER_JERRY}} files** ✅ DECIDED (design task, no user decision needed)
HELM will ship a `clean-for-repo.sh` script that scans ~/pap-workspace and outputs a manifest tagging each file as `system` (goes in repo) or `user` (stays local, never committed). {{USER_JERRY}} reviews the manifest and approves before any repo commit. Automated tagging + manual review is safer than either pure option.

**D-R2-07 — Onboarding script comfort gap** ✅ DECIDED 2026-06-06
Priority order: A (terminal) → B (password manager) → C (Discord Developer Portal)
Resolution: Cowork-first bootstrap eliminates A entirely. B addressed by platform-native keychain fallback
(no 1Password required). C addressed by guided step-by-step with every single click explained in plain English.
