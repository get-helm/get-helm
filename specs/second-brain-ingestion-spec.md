---
name: Second Brain Ingestion Spec
description: Locked scope for Discord backfill and email ingestion into QMD second brain — post-QMD gate applies
type: reference
created: 2026-05-21
status: locked — awaiting QMD setup
---

# Second Brain Ingestion Spec

**Gate:** Nothing below runs until QMD is set up and operational.
**Status:** Spec locked. Implementation pending.

---

## Discord Backfill

### Channels (all history, no date cutoff)

**Workspace channels:**
- etf-tracker ({{USER_CHANNEL_ETF_TRACKER}})
- options-helper ({{USER_CHANNEL_OPTIONS_HELPER}})
- japan-2026 (1504684387852222465)
- daily-brief (1504126943669260403)
- financial-review (1504160847134720050)
- mission-control (1505752160057561149)
- pl-01-onboarding (channel ID TBD — workspace in early stage)
- Any future workspace channels (auto-detected via channel registry — see below)

**Named non-workspace channels:**
- #pap-improvements ({{USER_CHANNEL_HELM_IMPROVEMENTS}}) — {{USER_JERRY}}'s main channel
- #capture (1499287733007421611) — everything dropped here already has intent signal
- #new-workspace (1500203712692486326) — workspace intake conversations
- Old pap-improvements / archived (1501656066340032776) — historical decisions

### Threads
Include ALL threads within every listed channel — threads often contain the most specific decision content.

### Auto-detect new workspaces
When the scaffolder creates a new workspace channel, it must write the channel ID to a channel registry file:
```
~/pap-workspace/channel-registry.json
```
Format:
```json
{
  "workspace_channels": [
    {"name": "etf-tracker", "channel_id": "{{USER_CHANNEL_ETF_TRACKER}}"},
    ...
  ],
  "last_updated": "2026-05-21"
}
```
The ingestion pipeline reads this file to stay current. Scaffolder adds an entry on every new workspace creation.

### Distillation filter (not raw dumps)
Each batch of 50 messages → LLM distillation pass: "What decisions, outcomes, or preferences were established?" Write summaries, not transcripts.

### TTL defaults for Discord content
- Workspace decisions: 1 year (or tied to workspace lifecycle — expires when workspace archived)
- #pap-improvements conversations: 2 years
- #capture saves: 90 days (content already saved separately via capture flow)
- #new-workspace intake: 180 days

---

## Email Backfill

### Criteria and lookback windows

| Criterion | Lookback | Notes |
|-----------|----------|-------|
| Inbox + Updates label, sent or replied to | 5 years | Covers sent mail and threads you engaged with |
| To/from anyone in contacts | 5 years | May be broad — monitor signal quality on first run |
| To/from anyone you've replied to | 1 year | Stronger signal of real relationships |
| Directly to {{USER_GITHUB}}13@gmail.com or @{{USER_DOMAIN}} | 1 year | With marketing filtered OUT |

### Marketing filter (for direct-address criterion)
Exclude emails matching standard marketing signals: List-Unsubscribe header present, bulk/promotional sender patterns, "unsubscribe" in body, automated sender domains.

### Noise filter — junk@{{USER_DOMAIN}}
Do NOT include junk@{{USER_DOMAIN}} in any criterion — this address receives SMS-forwarded texts and marketing noise. Evaluate separately if/when SMS ingestion becomes a use case.

### TTL defaults for email content
- Inbox/sent: 2 years
- Contacts: 1 year
- Direct-address: 1 year
- No expiry: emails tagged as preferences or key decisions (requires manual or agent tagging)

---

## QMD Setup — Confirmed 2026-05-22

**Database path:** `~/pap-workspace/.qmd/index.sqlite`
**Binary:** `~/.bun/bin/qmd`
**Collections:** `second-brain` (16 files) + `memory` (26 files)
**Test query result:** `qmd search "PAP architecture"` → returns results scored 58-59%, correct docs surface first.

## Pre-build checklist (before any ingestion script is written)

- [x] QMD operational and indexed — confirmed 2026-05-22 (42 files, search working)
- [ ] Channel registry file created and scaffolder updated to write to it
- [ ] pl-01-onboarding channel ID confirmed
- [ ] Marketing filter approach reviewed (header-based vs. label-based)
- [ ] First run scoped to one channel as pilot (recommended: etf-tracker — high decision density, bounded history)
- [ ] Pilot output reviewed for distillation quality before full run

---

## Open items (minor)

1. **Marketing filter direction confirmed:** Reading {{USER_JERRY}}'s criteria as "filter marketing OUT" for the direct-address emails. If the intent was "filter marketing IN" (i.e., capture only marketing emails from those addresses), this needs correction before build.
2. **pl-01-onboarding channel ID:** Workspace exists but no CLAUDE.md found — channel ID unknown. Confirm when workspace is fully set up.
