# HELM Frequently Asked Questions

## General

**What is HELM?**

HELM is a personal automation assistant that lives in your Discord server. You describe what you want automated in plain language, and HELM designs, builds, and runs it — without you writing code.

**Do I need to know how to code?**

No. HELM handles all the technical work. You communicate in plain English.

**What can HELM automate?**

Anything that involves:
- Fetching data from APIs (stock prices, weather, email, calendar)
- Summarizing information (portfolio summaries, news digests, email recaps)
- Sending alerts (price thresholds, calendar reminders, status changes)
- Organizing and tracking (trip planning, project tracking, habit logging)
- Scheduled reports (daily/weekly summaries of anything)

---

## Setup

**How long does setup take?**

About 30–60 minutes for the initial setup. See [INSTALL.md](INSTALL.md).

**Do I need a VPS?**

No for basic use. A VPS is useful for automations that need 24/7 cloud compute or a public URL for webhooks.

**What if I don't have a domain?**

HELM works without a domain. Some features (like public dashboards) require a domain, but most automations don't.

---

## Usage

**Can I have multiple automations running at once?**

Yes. Each automation runs in its own workspace. You can have as many as you need.

**Does HELM run when I'm asleep?**

Yes. HELM runs 24/7. If something needs your input, it waits until you respond — it doesn't wake you up.

**How do I stop an automation?**

In the workspace channel, type `@HELM pause` to pause or `@HELM cancel` to stop permanently.

**Can I change an automation after it's built?**

Yes. In the workspace channel, describe what you want changed. HELM will update it.

**What if HELM builds something wrong?**

HELM shows you results before going live and asks you to confirm. If something is wrong during build, just describe the problem in the workspace channel.

---

## Privacy & Security

**Where is my data stored?**

Locally on your machine. HELM doesn't sync your data to any cloud service (except the APIs your automation specifically uses).

**Does HELM see my passwords?**

HELM uses 1Password to store any credentials it needs. It reads credentials from 1Password when needed, never stores them in plain text.

**Is my data sent to Anthropic (Claude)?**

Claude sees the context of your conversations with HELM (what you type, HELM's responses) to understand your requests. Anthropic's privacy policy applies to these calls.

**Can other people see my HELM workspaces?**

No, unless they're in your Discord server. HELM is designed for personal, single-user use.

---

## Troubleshooting

**HELM stopped responding**

1. Wait 2 minutes
2. Type `!force-restart` in #helm-status
3. If that doesn't work, check the pinned message in #helm-status for recovery options

**My automation output looks wrong**

Describe the issue in the workspace channel: `@HELM the output is missing [X]`

**I can't find a workspace channel**

Workspace channels appear automatically when created. Scroll through your Discord channel list. Channel names match the workspace name.

**HELM says it can't do something**

Some things require capabilities that HELM doesn't have yet (browser automation, phone calls, etc.). Ask HELM what the closest alternative is.

---

## Technical

**What model does HELM use?**

HELM uses Claude Sonnet by default. Complex decisions use Claude Opus. Routing uses Claude Haiku (faster, cheaper).

**How are HELM improvements made?**

HELM has a product-manager agent that identifies improvements and queues them for an engineer agent to implement. Both run automatically.

**Can I contribute to HELM?**

Not directly to the core right now — HELM is a personal project. Ideas and bug reports are welcome via GitHub issues on this repo.

**What version of HELM am I running?**

Type `!version` in #helm-status.
