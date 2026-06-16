# 5-Minute Quickstart

## What is HELM?

HELM is your personal automation assistant. It runs in your Discord server and automates anything you describe in plain language. You don't write code — HELM does.

---

## Step 1: Send Your First Proposal

Type this in any channel:

```
@HELM [describe what you want automated]
```

**Examples:**
- `@HELM send me a daily digest of my portfolio changes`
- `@HELM when my credit card hits $5k, remind me to pay it off`
- `@HELM track my Japan trip planning in one place`
- `@HELM every morning, pull the top 5 news stories about AI`

HELM will respond with:
1. What it understood
2. A few clarifying questions
3. A design proposal
4. Build estimate
5. A yes/no for you to decide

Once you say yes, HELM builds it. A new channel appears for that automation (your workspace), and it starts running.

---

## Step 2: Watch It Build

HELM works in a dedicated workspace channel. You'll see:
- What it's building
- When it's testing
- Questions it needs you to answer
- When it's ready

You don't need to do anything except answer questions when asked.

---

## Step 3: It Runs Automatically

Once your workspace is live, HELM runs your automation without you. You can:
- Check the workspace channel any time to see what happened
- Ask HELM to change something: `@HELM [describe the change]`
- Pause it: `@HELM pause this workspace`
- Cancel it: `@HELM cancel this workspace`

---

## Key Concepts

**Workspace** — a dedicated Discord channel for one automation. Every automation gets its own workspace.

**Phases** — HELM builds things in stages: Understand → Validate → Optimize → Live. See [GUIDE.md](GUIDE.md#phases) for details.

**Proposals** — when you ask HELM to build something, it shows you a plan first. You approve or refine before it builds.

**Preferences** — HELM adapts to your style (brief vs. detailed, formal vs. casual). See [PREFERENCES.md](PREFERENCES.md) to customize.

---

## Common Questions

**"What if I don't like the proposal?"** — Just say so. HELM will refine until you're happy.

**"Can I change it after it's built?"** — Yes. Just ask in the workspace channel.

**"What if something breaks?"** — HELM monitors automations. If something breaks, it tells you what happened and how to fix it.

**"Where's my data stored?"** — Locally on your machine. HELM doesn't send your data to external services (except the APIs your automation uses). See [REFERENCE.md](REFERENCE.md#data-storage) for details.

---

## Next Steps

- Send your first proposal (see Step 1 above)
- Read [GUIDE.md](GUIDE.md) for the full user guide
- Configure your preferences: [PREFERENCES.md](PREFERENCES.md)
