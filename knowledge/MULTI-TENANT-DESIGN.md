# PL-02: Multi-Tenant PAP Architecture
## Design Decision Doc — 2026-05-17

---

## The Fork

Two models exist for serving more than one user:

**Model A: One instance per user (separate hardware)**
Each user gets their own Mac Mini (or VPS), their own Discord server, their own bot.js, their own pap-workspace/. Complete isolation by default.

**Model B: Shared bot, multi-tenant workspace**
One bot.js serves multiple Discord servers. User data lives in separate directories per user. Shared infrastructure (bot.js, agent files, skills).

---

## Tradeoffs

### Model A (Separate instances)

Pros:
- Zero data bleed risk — users can't touch each other's data structurally
- No routing complexity — bot.js doesn't need to know about multi-user anything
- Each user's PAP can have custom agents/skills without affecting others
- A crash or runaway process in User A's instance doesn't affect User B
- Onboarding = ship a preconfigured Mac Mini (literal product)

Cons:
- Infrastructure cost scales linearly with users (hardware per user)
- Updates require shipping patches to every instance independently
- No shared learning — CAPABILITIES.md improvements don't propagate automatically
- Mac Mini supply/cost is a real barrier for early users

### Model B (Shared bot)

Pros:
- Single infrastructure to maintain — one bot.js update reaches everyone
- Shared CAPABILITIES.md could grow faster with more workspaces contributing
- Lower marginal cost per user (VPS slices vs. dedicated hardware)

Cons:
- Data isolation is a software problem, not a hardware problem — requires careful path scoping
- A bug in one user's workspace agent could affect bot.js globally
- Financial data (Monarch, account balances) from multiple users in one process is a security concern
- Discord server scoping adds routing complexity to bot.js
- Credentials (PAP Vault) — each user needs their own 1Password account or vault

---

## Recommendation: Model A for first 10 users, then evaluate

**Reason 1:** PAP's core security contract ("never move money, read-only credentials, audit every access") is vastly easier to enforce when users are isolated at the OS level, not the application level. Sharing a process between users who each have financial data is a high-risk design choice that requires significant engineering to get right.

**Reason 2:** The Mac Mini IS the product. {{USER_JERRY}} runs PAP on a Mac Mini that's always on at home. That's the intended deployment model — not a VPS, not a cloud server. The residential IP is load-bearing (Monarch blocks data center IPs). Shipping a preconfigured Mac Mini to user 2 preserves this.

**Reason 3:** 10-user scale doesn't justify the shared-bot complexity. The inflection point is probably 50-100 users, where update logistics become painful. At that scale, revisit with a proper SaaS architecture decision.

---

## Onboarding Path for User 2 (Model A)

1. Ship Mac Mini with macOS + node + homebrew + claude CLI pre-installed
2. User creates Discord server, adds Marvin bot
3. Run bootstrap script (TASK-018 — not yet built) — walks through:
   - Discord bot token
   - 1Password vault setup
   - Required API keys (Tiingo, Alpha Vantage, etc.)
   - launchd plist installation
4. Pull helm-config repo to get agents/skills/workspace template
5. Done — user has a running PAP instance identical to {{USER_JERRY}}'s

**Shared learning path:** Users who want to contribute CAPABILITIES.md improvements submit a pull request to helm-config repo. Engineer reviews and merges. No automatic sync — explicit human gate on shared knowledge.

---

## Data Isolation (if Model B is ever chosen)

If the team ever moves to Model B, the minimum isolation requirements are:
- Per-user pap-workspace directory (`~/pap-workspace/{userId}/`)
- Per-user PAP Vault or credential store — no shared secrets
- Per-user Discord guild scoping in bot.js routing
- Financial data agents must never have cross-user file access
- audit log must tag every entry with userId

This is 3-6 months of engineering work to do safely. Not recommended until user 2's onboarding experience with Model A is validated.

---

## Decision

**Model A. One instance per user. Mac Mini as the deployment unit.**

Revisit at 10 active users or when update logistics become a recurring complaint (whichever comes first).
