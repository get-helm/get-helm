# HELM Onboarding — New-User UX Walkthrough

**Date:** 2026-06-16
**Author:** Audit agent (new-user perspective)
**Scope:** Every screen, prompt, and question a brand-new user sees, in order, across the three onboarding layers:
- **Layer 1 — Landing page + Phase-1 pre-install prompt** (Claude.ai, daily machine)
- **Layer 2 — Phase-2 install prompt** (Claude Desktop → Code tab → Local, dedicated machine)
- **Layer 3 — Discord onboarding** (bot.js: welcome, Stage 1 / Stage 2 preferences, tour, connectors)

**This is a UX review, not a spec/code mesh audit.** A separate audit (`ONBOARDING-MESH-FIXES-20260616.md`) covers tour ordering, timezone collection, and connector wiring as spec-vs-code mismatches. Where the *UX framing* of one of those is itself confusing, it appears here.

**Sources read (literal text quoted below):**
- `specs/P5.1-ONBOARDING-SPEC.md` (canonical Phase-0/1/2 user-facing text)
- `specs/helm-cowork-install-prompt.md` (the published Phase-2 prompt — "Code tab → Local")
- `specs/helm-cowork-prompt.md` (older "Cowork" variant — see Finding W-0)
- `marvin-bot/bot.js` (`ONBOARDING_STEPS`, `buildTourSteps`, `COMPLETE_MSG`, guild-create welcome — lines 2893-3097, 4770-4849, 7152-7293)
- 2nd brain: `qmd-query.sh "onboarding user experience"` and `"onboarding script preferences questions"`

**2nd-brain prior decisions (cited):** The top hit (relevance 0.93), *Discord #helm-improvements — Thread: Additional users*, records {{USER_JERRY}}'s own retrospective that the fresh-user flow was *"almost skipped entirely"* and called out *"Terminal/SSH assumptions (should have been 'zero terminal ever' from the start)."* P5.1's "zero-terminal" design is the direct response. This walkthrough holds the live flow against that bar.

**Research grounding (web, 2026):** Progressive disclosure = reveal complexity just-in-time; permission/credential priming = explain value *before* the ask (Starbucks location, camera-at-tap patterns); start forms light, defer optional fields; momentum-building beats upfront commitment. Sources listed at the end.

---

## PART A — LAYER 1: Landing page + Phase-1 pre-install prompt (Claude.ai)

### Step 1 — Landing page header + value props
**What the user sees** (P5.1 §"Page content"):
> **HELM — a personal AI that runs 24/7 on your own machine.**
> Not a subscription to a service. Yours. On your hardware. Customized exactly to how you work.
> → You wake up to a summary of what's on your calendar, what emails need replies...
> **What you need:** A Claude subscription ($20/month) · A computer you can leave on 24/7 · About 45–60 minutes

**UX judgment:** Strong. Leads with outcome ("you wake up to a summary"), not features. Sets honest time + cost expectations up front — exactly the "explain value, set expectations early" pattern. "Not a subscription to a service. Yours." is a genuinely good differentiator.

**One concern:** "45–60 minutes" on the landing page vs. P5.1 §"BEFORE YOU START" which says "~35-45 minutes" vs. "~45 minutes." Three different totals across the same spec. A new user budgeting their evening will notice if it runs long.

**Suggested improvement:** Pick ONE honest number and use it everywhere. Recommend: "About an hour, and you can stop and pick up later anytime." The "you can pause" reassurance matters more than the precise figure.

---

### Step 2 — The single call-to-action button
**What the user sees:**
> [BUTTON: Copy prompt + open Claude.ai] *(clicking copies the text to your clipboard and opens Claude.ai in a new tab — free to use for this step)*
> Paste into Claude.ai — it's already in your clipboard. Press Enter.

**UX judgment:** Good — one action, one outcome (textbook first-screen simplicity). The "free to use for this step" parenthetical preempts "wait, am I being charged already?" anxiety. The "already in your clipboard" line is reassuring.

**Concern:** A brand-new user does not know what "paste a prompt into Claude.ai" *does* or *why*. They've been told HELM "runs on your machine" — now they're pasting text into a website. The mental model jump (website chat → installs software on a different machine later) is unexplained.

**Suggested improvement:** Add one sentence under the button: *"This opens a free AI guide that walks you through the whole setup, one step at a time — it doesn't install anything yet, it just helps you get ready."* Removes the "what am I about to trigger?" hesitation.

---

### Step 3 — Phase-1 greeting (STEP 1.1)
**What the user sees** (verbatim):
> "Hi — I'm your HELM setup guide. I'll walk you through everything step by step... First question: do you have a computer that you could leave on 24/7 — one that isn't your main daily machine? An old laptop, a Mac Mini, an old desktop — anything that could just sit on a desk and stay on."

**UX judgment:** Excellent. Warm, sets the "step by step" contract, and the first question is concrete with examples. Asking hardware first is the right gate.

**No change needed.** This is a model opening.

---

### Step 4 — Hardware branch (STEP 1.2)
**What the user sees** (NO branch): 
> "No problem — HELM can run on your daily computer. The main difference: HELM pauses when your machine goes to sleep. It'll still work, just won't run scheduled tasks overnight."

**UX judgment:** Honest about the tradeoff (sleep = no overnight tasks). Good. The Mac Mini "$600, leave it and forget it" framing is helpful without pressuring.

**Concern (anxiety-inducing for the daily-machine user):** This user is about to be told (Step 5) to potentially WIPE a machine. The no-branch reassures them they can use their daily machine — but does NOT say "we will NOT wipe your daily machine." A nervous reader may fear the next step erases their main computer.

**Suggested improvement:** Append to the NO branch: *"Don't worry — we won't change or erase anything on your daily machine. HELM installs alongside what's already there."* Explicit safety statement before the wipe steps appear for the other branch.

---

### Step 5 — Machine wipe (STEP 1.3 Mac / 1.4 Windows)
**What the user sees** (Mac, abbreviated):
> "Let's wipe this Mac and start fresh... is there anything on that machine you'd want to keep? If so, take a few minutes to back it up first..."
> "Step 1: Click the Apple logo... Step 4: ... click 'Erase All Content and Settings.'"

**UX judgment:** This is genuinely good click-by-click instruction — one step at a time, "tell me when you see it" confirmation gates, backup warning first, post-wipe setup screens enumerated (Apple ID skip, account creation, etc.). Meets the "click-by-click, never assume knowledge" bar. The backup prompt before an irreversible erase is the single most important safety beat and it's present.

**Concern 1 (highest-anxiety moment in the entire flow):** "Erase All Content and Settings" is the most destructive action a user will ever take, and the lead-in is brisk ("Let's wipe this Mac and start fresh"). For a non-technical user this is terrifying.

**Suggested improvement:** Before Step 1, add an explicit framing + point-of-no-return note: *"This next part erases the spare machine completely and reinstalls a fresh copy of [macOS/Windows]. Nothing touches your daily computer or your phone. Once it starts you can't undo it, so let's make 100% sure there's nothing on this machine you need first. Ready?"* Naming "point of no return" reduces panic more than hiding it.

**Concern 2:** No "why wipe at all?" The user is never told *why* a clean machine matters (security, no conflicting software, a dedicated box). A reasonable person asks "why can't I just install on the machine as-is?"

**Suggested improvement:** One sentence: *"A clean machine means HELM has its own space — nothing else interfering, and your personal files stay on your own computer, separate from the always-on assistant."*

---

### Step 6 — Subscription check (STEP 1.5)
**What the user sees** (verbatim):
> "HELM runs on Claude, which requires a paid subscription — Claude Pro at about $20/month. Do you have one?... Choose Claude Pro ($20/month) to start — for always-on 24/7 use, Max ($100/month) is recommended; you can upgrade anytime"

**UX judgment:** Mostly good and now honest about Pro-vs-Max (the locked decision: "Pro is enough to start; heavy use may need Max"). Asking "you'd have signed up at claude.ai" helps the user check.

**Concern (mixed-message risk):** The landing page said "$20/month." Here the user learns that for "always-on 24/7 use" — which is *literally what HELM is* (the header said "runs 24/7") — Max at $100/month "is recommended." A sharp reader feels a bait-and-switch: the headline price is 5× higher for the advertised use case. This is exactly the G-A / G-G usage-cap risk surfacing as a UX trust issue.

**Suggested improvement:** Align the landing page and this step. On the landing page, say: *"$20/month to start (Claude Pro). Heavy daily use may need Max ($100/month) — you can start on Pro and upgrade only if you hit limits."* Then Step 1.5 reads as a reminder, not a surprise. Never let the price the user committed to mentally change mid-setup.

---

### Step 7 — Install Claude Desktop (STEP 1.6)
**What the user sees:**
> "Go to: **anthropic.com/claude-desktop** ... Click the download button... For Mac: Open the downloaded file — it ends in .dmg ... drag the Claude Desktop icon into the Applications folder..."

**UX judgment:** Good click-by-click for both Mac and Windows. ".dmg" / ".exe" explained by example. The "Anthropic is the company that makes Claude" aside is the right level of hand-holding.

**No major change.** Verify the URL is correct and live before beta (the spec uses `anthropic.com/claude-desktop`; the Phase-2 prompt elsewhere uses `anthropic.com/download` — pick the canonical one).

---

### Step 8 — Code tab → Local (STEP 1.6 cont.)
**What the user sees:**
> "In the Code tab, look for a dropdown or toggle near the top that shows the current environment — it might say 'Cloud' or 'Remote.' We need to switch it to 'Local.'... [If they can't find it:] It might look slightly different depending on your version. Try looking for: a selector near the top..."

**UX judgment:** This is the single most fragile UX step in the whole flow, and the copy already shows awareness (it has a fallback for "can't find it"). But "look for a dropdown that might say Cloud or Remote, switch to Local" is hand-wavy for the one step that, if done wrong, dead-ends the entire install (the whole Cowork→Local correction, G-B, exists because of this).

**Concern:** The user has never opened the Code tab. The instruction assumes they're already in it ("In the Code tab...") without telling them how to *get* to the Code tab. Where is it? What does it look like?

**Suggested improvement:** Add the missing predecessor step: *"When Claude Desktop opens, look along the top (or left side) for a tab or icon labeled 'Code' — it may look like `</>`. Click it. Tell me what you see."* Then the Local-mode step. Also strongly recommend a **screenshot or short GIF** here (research P12 "show before asking" — preview de-terrifies). This is the step most likely to strand a beta user.

---

### Step 9 — Handoff to Phase 2 (STEP 1.7)
**What the user sees:**
> "Copy the text below exactly as written and paste it into Claude Desktop. Press Enter. The AI there knows everything about HELM and will walk you through the rest automatically.
> --- [COWORK INSTALL PROMPT — SEE PHASE 2 BELOW] ---"

**UX judgment:** Clear handoff with a reassuring "the AI there knows everything." Time estimate ("20–30 minutes") and role-reframe ("mostly confirming steps") are good.

**Concern:** The placeholder `[COWORK INSTALL PROMPT — SEE PHASE 2 BELOW]` is internal scaffolding. If the published prompt ever ships with that literal placeholder instead of the real Phase-2 text, the user copies garbage. **Verify the published artifact has the real prompt substituted in.** Also: the label still says "COWORK" — a residual of the pre-correction naming.

**Suggested improvement:** Ensure the publish pipeline inlines the actual Phase-2 prompt text here and renames the marker. The user should be able to copy a real, complete prompt in one action.

---

## PART B — LAYER 2: Phase-2 install prompt (Claude Desktop → Code/Local)

> Source: `helm-cowork-install-prompt.md` (the current Code/Local version). NOTE — see Finding W-0 about the stale `helm-cowork-prompt.md` still in the repo.

### Step 10 — Install starts + name-the-bot (STEP A0)
**What the user sees:**
> "Setup is running in the background — I'm downloading and installing HELM now. Takes about 2 minutes. While that's going, let me ask you the most important question in this whole setup: What would you like to call me?... Choose something you'll like seeing every day."
> [Atlas] [Scout] [Remi] [Flynn] [Sage] [Something else →]

**UX judgment:** Excellent. Parallelizing the install with the most emotionally engaging question (naming) is exactly right (research P7/P11 — front-load personalization, back-load technical). "The most important question in this whole setup" + "something you'll like seeing every day" creates investment. Pre-set name buttons remove blank-page paralysis.

**No change needed.** This is the best-designed step in the flow.

---

### Step 11 — User's name (STEP A1)
**What the user sees:**
> "[AGENT_NAME]. I like it. And what should I call you? Just a first name or nickname — I'll use it whenever we're talking."

**UX judgment:** Good. Reciprocity (they named the bot, now it learns their name). Brief.

**No change.**

---

### Step 12 — Preview the destination (STEP A2)
**What the user sees:**
> "Here's where we're headed — this is what your Discord will look like in about 15 minutes:
> > Good morning [USER] — here's what's on today:
> > 📅 Connect your calendar to see today's events.
> > 📧 Connect your email to see messages.
> That message, every morning, in your own Discord server."

**UX judgment:** Strong "show the payoff" moment (research P9 — never show an empty state; show the real destination). It tells the user the briefing exists and that calendar/email get connected. Good motivation before the hard Discord step.

**Minor concern:** "in about 15 minutes" — yet Phase-1 Step 1.7 just said this phase takes "20–30 minutes." Internal time estimates disagree again. Pick one.

---

### Step 13 — Discord install check (STEP A3)
**What the user sees:**
> "Discord is a free app — think of it like a private group chat, but one we fully control. HELM lives there as a bot. Do you have Discord installed?"
> [Yes] [No, I need to install it] → "go to discord.com/download..."

**UX judgment:** Good. Explains what Discord is ("private group chat") for someone who's never used it, before asking. Provides both desktop and mobile install paths.

**No major change.** Verify the "create an account or log in" landmark wording matches current Discord UI.

---

### Step 14 — Create the bot application (STEP A3 cont.)
**What the user sees:**
> "Now let's create [AGENT_NAME]'s bot account. This happens in a browser tab — not in Discord itself. Open a browser and go to: discord.com/developers/applications... Click 'New Application' — it's a blue button in the top right corner... Type exactly: [AGENT_NAME]. Check the checkbox agreeing to Discord's terms, then click 'Create.'"

**UX judgment:** This is genuinely click-by-click with UI landmarks ("blue button in the top right"), "tell me when you see..." gates throughout, and the explicit "this happens in a browser tab — not in Discord itself" disambiguation (a real point of confusion for newbies). This is well done.

**Concern (no "why"):** The user is dropped into the **Discord Developer Portal** — an intimidating, developer-facing site — with no framing of *why* they're there or *what a bot application is*. Research (permission priming, P5 "we'll handle this" frame) says explain the purpose first.

**Suggested improvement:** Prepend one calming line: *"This next part uses Discord's developer page — it looks technical, but you'll only click a few buttons and I'll name every one. We're creating the 'account' your assistant uses to log into Discord, the same way you have a login."*

---

### Step 15 — Privileged Gateway Intents (STEP A3 cont.)
**What the user sees:**
> "Look toward the bottom of this page for a section called 'Privileged Gateway Intents.' You'll see three toggle switches. Turn ALL THREE on... → Presence Intent → Server Members Intent → Message Content Intent"

**UX judgment:** Clear and specific (names all three, says "turn blue or green"). Good.

**Concern:** "Privileged Gateway Intents" is alarming jargon — *privileged* sounds like granting something dangerous, with zero explanation of what it does. A privacy-conscious user may hesitate or refuse.

**Suggested improvement:** *"These three switches let [AGENT_NAME] actually read and respond to your messages — without them, it can't hear you. (Discord calls them 'intents' — just flip all three on.)"* Explains the benefit, defuses "privileged."

---

### Step 16 — Reset/copy the token (STEP A3 cont.)
**What the user sees:**
> "Click 'Reset Token.' If a warning appears asking you to confirm — click 'Yes, do it!' A long string of letters and numbers will appear. This is [AGENT_NAME]'s password for Discord. Copy it and paste it here."
> [after paste:] "Got it — saved to your local config file. It's stored on your Mac and only your user account can read it."

**UX judgment:** Good. "This is [AGENT_NAME]'s password for Discord" is the perfect plain-English analogy for a token (never assumes the user knows "token"). The post-paste reassurance about storage is honest and matches reality — this correctly implements the G-C fix (no false "Vault" promise; says "stored on your Mac, only your account can read it").

**Minor concern (anxiety-first, research P4):** The user is pasting a secret into a chat. Lead with what you're NOT doing. Currently the reassurance comes *after* they paste.

**Suggested improvement:** Move the safety note *before* the paste: *"You'll paste this here. It's stored only on your own machine, in a file only your account can open — it never leaves this computer and isn't sent anywhere. Go ahead and paste it."*

---

### Step 17 — OAuth2 URL generator + Administrator permission (STEP A3 cont.)
**What the user sees:**
> "In the 'Scopes' section, find 'bot'... check it. ... a second section appears below called 'Bot Permissions.' Find 'Administrator' at the top of that section and check it."

**UX judgment:** Click-by-click is fine. But granting **Administrator** to a bot is the broadest possible permission, presented with zero justification.

**Concern:** A cautious user sees "Administrator" and balks — this is the same instinct that makes people decline app permissions. No "why" is given, and "Administrator" is the scariest checkbox in the flow after "Erase All Content."

**Suggested improvement:** *"'Administrator' lets [AGENT_NAME] manage your private server for you — create the channels you'll use, organize them, post your briefings. It only has this power inside your own HELM server, nowhere else."* (Scopes-the-blast-radius reassurance.) If a tighter permission set would work, prefer it — but if Admin is genuinely required, at least justify it.

---

### Step 18 — Create/select server + authorize (STEP A3 cont.)
**What the user sees:**
> "You need a Discord server for HELM to live in — it's a private space, just you and your AI. Do you have a Discord server already, or do you need to create one?"
> [I have one] [I need to create one] → "Look at the very left edge — there's a column of circle icons. At the bottom is a + button..."

**UX judgment:** Good. "A private space, just you and your AI" is a reassuring mental model. Click-by-click for server creation with visual landmarks.

**No major change.**

---

### Step 19 — Server ID + owner User ID (STEP A3 cont.)
**What the user sees:**
> "I need your Discord server ID... right-click on your server name... If you see 'Copy Server ID' — click it. If you don't see that option: open Discord settings... → 'Advanced' → turn on 'Developer Mode.'"
> [then] "I need your personal Discord ID so I know who's in charge... Right-click on your own username..."

**UX judgment:** Good fallback (Developer Mode toggle) for when "Copy ID" isn't visible. The "so I know who's in charge" framing for the owner ID is the right just-in-time explanation.

**Concern:** Two ID-copy tasks back to back, both requiring Developer Mode, both involving right-click-and-find-the-menu-item. This is fiddly and the most likely place a non-technical user mis-copies (grabbing a channel ID, a message ID, or their username instead of the numeric ID). No validation feedback is described for the user (the spec validates 17-20 digits internally but the user isn't told what a "right" answer looks like).

**Suggested improvement:** Tell the user what a correct value looks like: *"It'll be a long string of numbers, like 9-18 digits — paste that."* And if validation fails, the bot should say plainly: *"Hmm, that doesn't look like a server ID (it should be ~18 digits). Make sure you right-clicked the server name, not a channel — try again."* Don't silently accept or reject.

---

### Step 20 — GitHub backup (OPTIONAL) (STEP A4)
**What the user sees:**
> "HELM keeps a nightly backup of your setup on GitHub — a free service that stores your configuration. If this machine ever fails, your HELM is recoverable. Do you have a GitHub account?"
> [Yes, set up backup] [Skip for now] → (if yes) "github.com/settings/tokens → Generate new token (classic)... check the 'repo' checkbox... Copy the long string that appears (starts with 'ghp_')..."

**UX judgment:** This is the ONE optional step that's framed well: states the value (recoverability), states it's free, gives a clean Skip. Good optional-step framing per research ("make optional steps low-pressure, state the value").

**Concern (incomplete optional-choice framing):** Per the audit goal — for optional choices, lay out *what value they miss by declining.* "Skip for now" doesn't say what they lose. A user should know: "If you skip, and this machine dies, you'd have to set HELM up again from scratch." Also "Generate new token (classic)" and "repo scope" are developer concepts dropped without explanation — the GitHub PAT step is the least newbie-friendly in the flow (it assumes a GitHub account and comfort generating scoped tokens).

**Suggested improvement:** (1) On the Skip button add consequence: *"[Skip for now — I'll risk re-doing setup if this machine ever dies]"* or a one-line note. (2) For users without GitHub, don't make them create an account + PAT mid-install — defer it cleanly: *"No GitHub? No problem — skip this, and I'll remind you later. Your HELM works fine without it; backup just makes recovery easier."* (The deferred-items nudge already exists — lean on it.)

---

### Step 21 — Launch + "go to Discord" (STEP A5/A6)
**What the user sees:**
> "That's everything I need. Starting [AGENT_NAME] now. ⏳ Configuring... ✓ [AGENT_NAME] is online. Head to your Discord server — go to the #general channel. There's a message waiting for you."
> "Did you see it?" [Yes — I see a message] [Not yet] → (diagnostic, restart if needed)

**UX judgment:** Excellent close. Clear "aha" handoff, a confirmation gate, and a real diagnostic+self-heal path for "Not yet" (checks process, restarts). This is the moment of first value and it's handled with care.

**No change needed.** Strong finish to Layer 2.

---

## PART C — LAYER 3: Discord onboarding (bot.js)

> **CRITICAL STRUCTURAL UX BUG — see Finding W-1.** The order the user actually experiences in Discord does NOT match the Phase-2 handoff promise or the P5.1 design. This is the highest-impact finding in the report.

### Step 22 — First Discord message + immediate tour (bot.js guild-create, lines 4821-4828)
**What the user sees** (verbatim, posted to #general on guild-create):
> "✅ [AGENT_NAME] is set up and ready — see each channel for a quick intro. Just type in any channel to get started."
> "👋 Here's a quick tour to get you started:"
> [then the 5-step tour embed fires immediately]

**UX judgment / Finding W-1 (BUG):** The Phase-2 prompt told the user (Step A6): *"[AGENT_NAME] will introduce themselves and walk you through a few quick preferences — just a few taps."* And P5.1's locked order is **Stage 1 prefs → Stage 2 prefs → THEN tour**. But the live guild-create handler **fires the full tour immediately**, before any preference questions. Then separately, the Stage-1 questions fire on the user's *first typed message* (line 7277-7280), and `COMPLETE_MSG` fires the tour *again* (line 3021-3022, `sendTourStep(channel, 0)`).

**Result the user experiences:** A tour they didn't ask for appears before they've done anything → then when they type, they get hit with preference questions → then at the end of preferences, **the same tour plays a second time.** This is confusing and feels broken ("why is it showing me the tour again?"). It also contradicts the "introduce themselves and walk you through a few quick preferences" promise — preferences should come first.

**Suggested improvement:** Remove the tour fire from the guild-create handler (lines 4824-4827). On first user message, run Stage 1 → Stage 2, and let `COMPLETE_MSG` fire the tour exactly once at the end (as P5.1 specifies). The guild-create welcome should invite the *first message*, not launch a tour: *"✅ [AGENT_NAME] is ready. Say hi in #general to get started."* (Note: the separate mesh audit covers the spec/code ordering; the *UX* harm — a double-played tour and broken promise — is what's flagged here.)

---

### Step 23 — Stage 1, Question 1 (bot.js `stage1_q1`)
**What the user sees** (verbatim):
> "When I have something to tell you, how much detail do you want?"
> [Just the highlights — keep it short] [Give me the full picture — more is fine]

**UX judgment:** Good. Plain-English, benefit-oriented button labels (not "Verbose / Concise"). One question per screen. Tappable — zero typing. This is well done.

**Minor concern:** No preamble. The user's first interaction with the live bot jumps straight into a question with no "hi, I'm [name], let me learn 3 quick things about how you like to work — just tap." A one-line intro before q1 would orient them.

**Suggested improvement:** Precede `stage1_q1` with: *"Hi [USER] 👋 I'm [AGENT_NAME]. Three quick taps and we're set — you can change any of these later."* (Sets the "only 3, reversible" expectation → reduces survey anxiety, research P14.)

---

### Step 24 — Stage 1, Question 2 (bot.js `stage1_q2`)
**What the user sees:**
> "How do you want messages to look?"
> [Dark mode] [Light mode]

**UX judgment:** Clear, tappable. Fine.

**Minor concern:** "How do you want messages to look?" maps to Dark/Light — but a user might expect more (font, density). It's actually only theme color. Slight mismatch between question scope and answer scope.

**Suggested improvement (minor):** *"Light or dark color theme for my messages?"* — narrows the question to match the answer.

---

### Step 25 — Stage 1, Question 3 (bot.js `stage1_q3`)
**What the user sees:**
> "When I think I can improve your idea, how should I tell you?"
> [Be direct — just say it] [Blend it in — mix with the idea] [Be subtle — hint at it]

**UX judgment:** Good — this is a genuinely thoughtful personalization question with clear options. Reflects {{USER_JERRY}}'s "challenge first / pushback" value being offered to the user.

**No change.** Nicely done.

---

### Steps 26-31 — Stage 2 (bot.js `stage2_*`)
**What the user sees** (verbatim, in order):
- `s2a` — "How should I sound when we talk?" [Casual — like we're texting] [Professional — clear and structured]
- `s2b` — "Are there times you don't want me sending notifications?" [Yes — quiet 10pm–7am] [No — notify me anytime]
- `s2c` — "When I notice something worth telling you, how often do you want to hear?" [Often — tell me everything] [Daily summary — batch it up] [Only if it's urgent]
- `s2d` — "I'll warn you before you hit Claude's weekly limit. Alert me at:" [70%] [85%] [95%]
- `s2e_date` — "Date format:" [MM/DD/YYYY (US)] [DD/MM/YYYY (EU)]
- `s2e_time` — "Time format:" [12-hour (2:30 PM)] [24-hour (14:30)]
- `s2e_week` — "Week starts on:" [Monday] [Sunday]

**UX judgment:** All tappable, all plain-English, one-per-screen. The proactive-cadence question (`s2c`) and quiet-hours (`s2b`) are well-framed with example values baked into the buttons. This is solid.

**Concern 1 (survey fatigue):** That's **7 Stage-2 questions immediately after 3 Stage-1 questions = 10 taps in one sitting** before the user has done anything useful. P5.1's *own* research principle P14 says Stage 2 should come "after first value, ~48 hours" — but the locked decision (and the code) runs Stage 2 immediately. The user just finished a 30-minute install; 10 preference taps before they get to *use* anything risks fatigue. The three date/time/week questions especially feel like a settings form, not a conversation.

**Suggested improvement:** Collapse the 3 locale questions (`s2e_date/time/week`) into ONE: *"Quick locale setup — which matches you?"* [US: MM/DD, 12-hour, Sun] [Europe: DD/MM, 24-hour, Mon] [Let me set each] — most users fit a regional default; offer granular only on request. Cuts 3 taps to 1 for the common case. Better still, **infer date/time/week from the machine locale at install** and skip the questions entirely (the install machine already knows its locale) — only ask if detection fails.

**Concern 2 (`s2d` — usage limit, no context):** "I'll warn you before you hit Claude's weekly limit. Alert me at: 70% / 85% / 95%" — a brand-new user has no idea what Claude's weekly limit is, whether they'll hit it, or what happens when they do. This question front-loads the G-A/G-G usage-cap anxiety with no explanation.

**Suggested improvement:** Add context or defer it. Either: *"Claude has a usage limit each week (you're unlikely to hit it on normal use). I'll give you a heads-up before you get close so nothing goes quiet unexpectedly — warn me at:"* — or move this to Stage 3 / #preferences entirely and default silently to 85%, since it's not a day-1 decision.

---

### Step 32 — Onboarding complete (bot.js `COMPLETE_MSG`)
**What the user sees** (verbatim):
> "Good. That's your setup done.
> → Health checks running every 6 hours
> → Nightly backup — 1am
> → Daily briefing starts once you connect a calendar or email (say **connect** in #preferences when ready)
> Now switch to your daily machine or phone and open Discord — that's where [AGENT_NAME] lives. Go to **#general** to start using it."
> [then the tour fires — see Finding W-1]

**UX judgment:** The "switch to your daily machine/phone" handoff is correct and important. But two problems:

**Concern 1 (broken connector promise — UX framing of G-E):** P5.1's locked decision G-E says *"Do NOT let the user leave onboarding with an empty briefing... the daily briefing is generated with live data and shown during onboarding."* But `COMPLETE_MSG` says the briefing "starts once you connect a calendar or email (say **connect** in #preferences when ready)" — i.e., it punts connector setup entirely and the user exits onboarding with NO connectors and NO first briefing. The "👋 say connect when ready" is a passive deferral, not the in-flow connector walkthrough that was decided. **This is the connector step (C24 / Steps that should exist) simply not being present in the live flow.** A new user finishes onboarding and their headline feature (the morning briefing they were shown in Step 12) is empty.

**Suggested improvement:** Insert the connector step **before** COMPLETE_MSG (this is the missing Step in Layer 3): a single question — *"Want your morning briefing to actually have your calendar and email in it? It takes about a minute. Which do you use?"* [Google (Gmail/Calendar)] [Outlook/Microsoft] [Skip for now]. Then walk them to Claude Desktop → Settings → Connectors (the corrected G-J architecture — no custom OAuth), confirm with a test "what's on my calendar?", and generate one real briefing they see before they leave. If they Skip, COMPLETE_MSG's current "say connect when ready" wording is the correct graceful-degrade fallback.

**Concern 2 (`connect` discoverability):** "say **connect** in #preferences" is a magic keyword. The tour (Step 28 below) tells users "no commands, no special syntax needed" — then COMPLETE_MSG hands them a command-keyword. Mild contradiction.

**Suggested improvement:** *"...just tell me in #preferences when you'd like to connect your calendar or email."* — plain English, consistent with the "no commands" promise.

---

### Steps 33-37 — The tour (bot.js `buildTourSteps`)
**What the user sees** (verbatim, 5 embeds with [Next →]):
1. "👋 Welcome to [name]" — "[name] is your personal automation platform. It turns plain-English requests into working automations..."
2. "📋 Your channels" — dynamic list: #general, #new-workspace, #capture, #daily-briefing, #help, #preferences with one-line descriptions
3. "💬 How to give instructions" — "Just type plain English — no commands, no special syntax needed..."
4. "⏸️ Emergency controls" — "Type **pause** / **resume** / **pause 2h**..."
5. "🚀 Build your first automation" — "Head to **#new-workspace** and type something you do manually..." [then a kickoff prompt posts to #new-workspace]

**UX judgment:** The tour content itself is good — clear, plain-English, the channel list is generated dynamically from `channels.json` (so it only names real channels, per the G-J/tour-channels fix), and ending on "build your first automation" with a concrete CTA + auto-posted kickoff prompt is a strong activation move.

**Concern 1 (the double-tour, Finding W-1):** As noted, this fires twice — once on guild-create, once after preferences. Fix per W-1.

**Concern 2 (tour vs. emergency-controls contradiction):** Step 3 says "no commands, no special syntax needed" — then Step 4 immediately teaches "type **pause** / **resume** / **pause 2h**" (commands) and COMPLETE_MSG taught "say **connect**" (a command). The "no commands" promise is technically about *requests* but reads as absolute and is immediately undercut.

**Suggested improvement:** Reword Step 3: *"Just type plain English for anything you want done — no special syntax. (A couple of quick words like **pause** are handy for emergencies — I'll show you next.)"* — sets up Step 4 instead of contradicting it.

**Concern 3 (timing):** Five tour embeds fire right after 10 preference taps. The user has now done ~15 sequential taps with no break. The tour would land better split: show it, but consider letting the "Build your first automation" step breathe (it's the activation moment).

---

### Step 38 — First-message intercept edge case (bot.js lines 7285-7291)
**What the user sees:** If onboarding is mid-flow and the user types a normal message (not tapping a button), the bot re-shows the current question.

**UX judgment:** Reasonable anti-derail guard. But a user who types "what can you do?" mid-onboarding just gets the same preference button re-posted with no acknowledgment — feels like the bot ignored them.

**Suggested improvement:** Add a one-line ack: *"I'll answer that in a sec — let's finish these quick taps first (almost done!)."* then re-show the question. Acknowledging > silently re-posting.

---

## FINDINGS THAT SPAN STEPS

### W-0 — Stale "Cowork" install prompt still in the repo
`specs/helm-cowork-prompt.md` still says "Cowork mode," "Required: Claude Desktop with Cowork mode enabled," and references the OLD `~/helm` path + a different question order (it asks for the token inline as text D3, vs. the click-by-click portal walk in the current prompt). The current/correct prompt is `helm-cowork-install-prompt.md` (Code/Local). **Two install prompts with the same-ish name, one stale and contradicting the Cowork→Local correction (G-B), is a publish-pipeline landmine.** If the wrong one is ever served, every user dead-ends. **Recommendation:** delete or clearly archive `helm-cowork-prompt.md`; ensure the publish pipeline only ever serves the Code/Local version.

### W-2 — Time estimates disagree across the flow
"45–60 min" (landing) / "~35-45 min" + "~45 min" (P5.1 BEFORE YOU START) / "20–30 min" (Phase-1 handoff) / "about 15 minutes" (Phase-2 A2). A user can't trust any of them. Pick one honest end-to-end number and one per-phase number, used consistently.

### W-3 — Price expectation shifts mid-flow ($20 → "$100 recommended for 24/7")
Covered in Step 6. This is a trust issue, not just a number. Align landing + Step 1.5.

### W-4 — Optional steps don't consistently state "what you lose by declining"
GitHub backup (Step 20) and the connectors/skip (Step 32) both offer a Skip without spelling out the cost of declining. The audit goal explicitly asks for pros/cons on optional choices. Add a one-line consequence to every Skip.

---

## TOP UX IMPROVEMENTS (ranked by user impact)

1. **Fix the double-played tour + wrong order (Finding W-1).** Remove the tour fire from guild-create (bot.js 4824-4827); run Stage 1 → Stage 2 → tour-once via COMPLETE_MSG. Today the tour plays before prefs AND again after — confusing and feels broken. *Highest impact: it's the first thing every user experiences in Discord and it's visibly wrong.*

2. **Add the missing in-flow connector step before COMPLETE_MSG (Step 32 / G-E).** The user is shown a morning-briefing preview (Step 12) as the headline feature, then exits onboarding with no connectors and an empty briefing. Insert a one-question connector setup (ask provider → Settings→Connectors walkthrough → test → show one real briefing) before completion; graceful-degrade on Skip. *Closes the gap between the promised payoff and reality.*

3. **De-terrify the two scariest steps with "why" + blast-radius framing.** "Erase All Content and Settings" (Step 5) and "Administrator permission" (Step 17) are the highest-anxiety moments and both lack explanation. Add a point-of-no-return note + "nothing touches your daily machine" to the wipe, and "only inside your own server" to the Admin grant. *Prevents abandonment at the two fear cliffs.*

4. **Align the price story end-to-end (Steps 1 + 6).** Landing says "$20/month"; Step 1.5 says Max ($100) "recommended" for the 24/7 use that is HELM's whole pitch. Say "$20 to start, heavy use may need Max — upgrade only if you hit limits" *on the landing page* so the number never changes mid-setup. *Trust-preserving; avoids felt bait-and-switch.*

5. **Cut Stage-2 survey fatigue: collapse the 3 locale questions into 1 (or auto-detect), and add context to the usage-limit question (Steps 26-31).** 10 preference taps in one sitting right after a 30-min install is a fatigue risk; the date/time/week trio is a settings form, and the "Claude weekly limit %" question means nothing to a new user. Infer locale from the machine; reframe the limit warning with reassurance. *Shortens the lowest-value, highest-fatigue stretch of the flow.*

**Honorable mentions:** delete the stale Cowork prompt (W-0, a publish landmine); add a one-line intro before Stage-1 q1 (Step 23); fix the "no commands" vs. "type pause/connect" contradiction (Steps 28/32); add ID-format hints + friendly validation errors for the Server/User ID copy (Step 19); add the missing "how to find the Code tab" predecessor + a screenshot at the Code→Local step (Step 8, the most fragile step).

---

## Research sources
- [9 User Onboarding Best Practices for 2026 — Formbricks](https://formbricks.com/blog/user-onboarding-best-practices)
- [What Is Progressive Disclosure in UX? — UXPin](https://www.uxpin.com/studio/blog/what-is-progressive-disclosure/)
- [User Onboarding Best Practices: 10 Strategies — Appcues](https://www.appcues.com/blog/user-onboarding-best-practices)
- [Onboarding UX: 10 patterns, best practices, and real examples — Appcues](https://www.appcues.com/blog/user-onboarding-ui-ux-patterns)
- [Priming users to grant mobile apps permission — Appcues](https://www.appcues.com/product-adoption-academy/mobile-app-onboarding-101/priming-users-to-grant-mobile-apps-permission)
- [Onboarding UX Patterns: Permission Priming — UserOnboard](https://www.useronboard.com/onboarding-ux-patterns/permission-priming/)
- 2nd brain: `qmd://second-brain/discord-helm-improvements-thread-additional-users.md` ({{USER_JERRY}}'s "zero terminal ever" + "fresh user flow almost skipped" retrospective)
