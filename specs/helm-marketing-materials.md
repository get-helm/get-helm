# HELM — Marketing Materials
## Value propositions, positioning, and requirements
## Draft: June 2026

---

## THE ONE-LINE PITCH

**You steer the ship, we row.**

---

## THE ELEVATOR PITCH (60 seconds)

HELM is a personal platform that builds the tools you keep wishing existed — customized exactly to how you work, running 24/7 on a machine you own.

You describe what you want — in plain English, through Discord — and HELM builds it. A morning briefing tailored to your day. A portfolio tracker with the specific columns and alerts you actually care about. A trip planner that handles logistics while you think about where to eat.

The difference from other AI tools: HELM is proactive. It doesn't wait for you to ask. It has opinions, challenges your thinking, and surfaces things you didn't know you needed.

And it's yours. Your data stays on your machine. Your credentials stay in your password manager. You're not renting time on someone else's system — you're running your own.

---

## CORE VALUE PROPOSITIONS

---

VP 1: "A morning briefing that already knows what matters to you"

Before you check your phone, HELM has already scanned your calendar, your email, your active workspaces, and anything overnight that needs your attention.

It delivers a single, structured briefing every morning — calibrated to how much you want to read. Under 2 minutes. Or longer, if you have time. Either way, you start your day knowing exactly where things stand.

No app switching. No checking five places. One message, when you want it.

---

VP 2: "Your tools, built exactly to spec — no code required"

Most software is built for everyone. HELM builds for you.

"I want a dashboard that shows my portfolio performance. Flag anything down more than 3%. Color-code it by sector. Make it look good on my phone."

HELM doesn't give you a generic template and wish you luck. It builds the actual thing you described — with the layout you want, the data you care about, the alerts that match how you think.

The tools HELM produces look and work like professional software. The difference: you described them in plain English, and they appeared.

---

VP 3: "A memory that compounds"

Most information you encounter disappears. You read an article, close the tab, and it's gone. You save a link, lose it in a folder. You had a great conversation, can't remember what you decided.

HELM captures everything — links, notes, articles, decisions, context from your conversations — and makes it searchable forever. By meaning, not just keywords.

The longer you use HELM, the smarter it gets about what you care about. It starts connecting things for you that you wouldn't have thought to connect yourself.

---

VP 4: "AI that challenges you, not just agrees with you"

Most AI tools are compliant. You propose something, they say "great idea" and get started.

HELM is designed to push back. Before it builds, it names the risk. Before it agrees, it checks the assumption. Before it delivers, it asks whether the goal was right in the first place.

This isn't friction — it's quality. The stuff you build with HELM is better because it got stress-tested before you built it.

---

VP 5: "Your data stays yours"

You install HELM on a machine you own. Your credentials live in your password manager. Your data never passes through HELM's servers.

One honest note: HELM is powered by Claude, Anthropic's AI model. What you share with HELM goes through the Claude API — like any AI service, Claude processes what you send it. HELM minimizes this by keeping sensitive data local and using read-only credentials wherever possible. You control what HELM can access.

You can see HELM's full audit log anytime. And if something goes wrong, recovery is one command away.

---

VP 6: "Scales from one workspace to a dozen"

Start with one tool. Add more as you find problems worth solving.

Each workspace runs independently, gets its own Discord channel, and delivers on its own schedule. They don't interfere with each other. When one finishes its purpose, it archives — and the learnings feed into whatever gets built next.

The system is designed for someone who's serious about getting more out of their time. As you build more, HELM gets better at building what you need.

---

## WHAT MAKES HELM DIFFERENT

| | HELM | Typical AI chat | Off-the-shelf automation | OpenClaw |
|---|---|---|---|---|
| **Proactive?** | Yes — acts before you ask | No — waits for prompts | Partially — schedule only | Yes — cron-driven |
| **Builds custom tools?** | Yes — full apps and dashboards | No | No | No |
| **Personalized?** | Yes — built for your workflow | Generic responses | Template-based | Configurable |
| **Your data?** | On your machine | Stored on their servers | Varies | On your server |
| **Learns over time?** | Yes — every build improves | No | No | Partial — memory system |
| **Challenges your thinking?** | Yes — by design | Rarely | No | No |
| **Requires coding?** | No | No | Sometimes | Yes — builder's tool |
| **Setup complexity?** | Guided, ~1 hour | Instant | Low | High — DIY |

---

## REQUIREMENTS

What you need to get started with HELM:

---

REQUIRED

1. A Claude Pro or Max subscription
HELM runs on Anthropic's Claude. The Pro plan (~$20/month) covers most users. Heavy users may want Max.

2. A dedicated machine that runs 24/7
HELM needs to run continuously to handle scheduled tasks and respond to you at any hour. Options:
- Any computer (Windows, Mac, or Linux) you can leave running
- A small dedicated device like a Mac Mini, NUC, or mini PC (~$600 one-time)
- A VPS (Virtual Private Server) — a cloud server you rent for ~$5–15/month

A dedicated machine is strongly recommended: scheduled tasks never miss, and HELM isn't sharing access with your personal files.

3. A password manager
HELM uses your password manager to store credentials securely. It never sees your personal passwords — only what you explicitly put in its vault section. Most major password managers are supported.

4. A Discord account
HELM runs through Discord. You'll create a private server that becomes your personal command center.

5. A GitHub account (free)
For nightly backups of your config and workspaces. Private repo.

---

STRONGLY RECOMMENDED

A dedicated machine, not your daily computer.

On a daily machine, HELM has access to your personal files and apps. Most people are comfortable with that, but a dedicated machine gives better security and ensures scheduled tasks never miss.

A mini PC running 24/7 uses about as much power as an LED light bulb. Inexpensive to operate, easy to set up.

---

OPTIONAL (unlocks more features)

Connected accounts:
- Email — summaries, smart notifications, draft assistance
- Calendar — daily briefing, scheduling, meeting prep
- Cloud drive — file creation, storage, sharing of outputs

A VPS or hosted server: For workspaces that need to run web services (like a hosted dashboard at your own domain). Not required to start — most users never need this.

---

## THE TRADEOFFS (honest version)

HELM requires upfront setup. About an hour, guided step-by-step. Once it's done, you shouldn't have to touch the host machine again.

HELM gets better over time. The first week is useful. The third month is noticeably better. After six months, it knows your patterns.

HELM is not a replacement for human judgment. It's a force multiplier. The decisions still belong to you — HELM just handles the information gathering, the routine work, and the "I keep forgetting to do that" tasks.

HELM requires a Claude subscription. This is the ongoing cost. Currently: $20/month (Pro) or $100/month (Max).

---

## FOR THE PERSON WHO REFERS SOMEONE

Things worth flagging for someone you're introducing HELM to:

1. It's not magic out of the box. The first workspace takes 30-60 minutes to build and tune. Once you've done one, the next ones go faster.

2. It works best for people who have recurring problems they keep wishing were solved. If you can't name 3 of those right now, start slower.

3. The second brain is the sleeper feature. It sounds less exciting than custom tools, but it's what makes HELM compoundingly valuable.

4. Set it up on the dedicated machine if at all possible. The daily-machine experience is good, but the dedicated-machine experience is what makes you stop babysitting it.
