# HELM Improvement Tracking System — Design Spec
# VISION-001 — 2026-06-05

## Problem

HELM marketing states: "The first week is useful. The third month is noticeably better. After six months, it knows your patterns."

This claim is aspirational. Currently there is no mechanism to:
- Measure whether HELM is actually improving
- Show users concrete evidence of improvement
- Detect when improvement has stalled

This spec defines the tracking system that makes the claim true and verifiable.

---

## What "Getting Better" Means (Measurable Signals)

| Signal | Measures | Direction |
|--------|----------|-----------|
| Violation rate | friction-log entries per session | ↓ good |
| Memory depth | MEMORY.md entry count | ↑ good |
| Behavior refinements deployed | friction → engineer fix → deploy cycles | ↑ good |
| Proactive action count | L0-3 actions logged in decisions-log per session | ↑ good |
| Engineer queue throughput | items completed vs. items added per week | ↑ good |
| Correction frequency | BLOCK count per session (proxy for user having to intervene) | ↓ good |

---

## Data Storage

### `~/pap-workspace/improvement-metrics.jsonl`
Append-only event log. One line per signal collection run.

```json
{"ts":"2026-06-05T00:00:00Z","days_active":1,"violations_7d":12,"memory_entries":6,
 "refinements_deployed":0,"proactive_7d":4,"queue_throughput_7d":0.5,"blocks_7d":3}
```

### `~/pap-workspace/improvement-baseline.json`
Snapshot from the first full week of operation. Used to calculate all % improvements.

```json
{"established":"2026-06-12T00:00:00Z","violations_per_session":8.2,
 "memory_entries":6,"proactive_per_session":1.4,"blocks_per_session":2.1}
```

### `~/pap-workspace/improvement-milestones.json`
Tracks which milestones have been crossed (prevents duplicate posts).

```json
{"week1":{"crossed":false},"month3":{"crossed":false},"month6":{"crossed":false}}
```

---

## Milestone Definitions

These are the criteria that make each marketing claim true:

### Week 1 — "Useful"
- At least 5 tasks completed (task-registry completions)
- At least 3 memory entries written
- Zero silent exits (B-04: all turns end in DELIVER or BLOCK)

### Month 3 — "Noticeably Better"
- Violation rate down ≥50% vs baseline
- Memory entries ≥20 (enough personalization to meaningfully adapt)
- At least 3 behavior refinements deployed (friction → fix cycle)
- Proactive action rate up ≥25% vs baseline

### Month 6 — "Knows Your Patterns"
- Violation rate down ≥75% vs baseline
- Memory entries ≥40
- At least 8 behavior refinements deployed
- Proactive action rate up ≥50% vs baseline

If a milestone's criteria aren't met, PM does NOT post the milestone card and instead surfaces the gap with a [CONFIRM] to the user.

---

## Collection Script

**`~/marvin-bot/collect-improvement-metrics.sh`**

Reads:
- `friction-log.md` — count violations in last 7 days
- `MEMORY.md` — count entries
- `decisions-log.md` — count L0-3 proactive actions in last 7 days
- `task-registry.jsonl` — count items completed in last 7 days vs. items added
- `channel-state/*.json` — count sessions with at least one BLOCK

Writes one line to `improvement-metrics.jsonl`.

If `improvement-baseline.json` doesn't exist and days_active ≥ 7, writes baseline snapshot.

Called by PM during weekly sweep.

---

## User-Visible Surface

### Monthly Progress Card
PM posts once per month to #pap-improvements during sweep.

```
[EMBED: HELM Progress — Month 2|Running for 62 days.|
Violations: 8.2 → 3.1/session (↓62%)|
Memory: 6 → 31 entries (415% more context)|
Proactive actions this week: 12|
Behavior fixes deployed: 4|
color:#4A7C59]
```

### Milestone Notifications
Posted when criteria first met. Not repeated.

```
[EMBED: Month 3 Milestone|"Noticeably better" criteria met.|
Violation rate: ↓58% from baseline|
Memory depth: 24 entries|
3 behavior fixes shipped from your feedback|
color:#4A7C59]
```

### `/progress` Command
User types `/progress` → bot calls `collect-improvement-metrics.sh` and returns current snapshot as [EMBED].

---

## When Improvement Stalls

If violation rate increases week-over-week for 2+ consecutive weeks:
- PM surfaces a [CONFIRM] identifying the pattern
- Does not auto-post to user — requires PM judgment call

---

## Implementation Order

1. `collect-improvement-metrics.sh` — data collector (no user-facing output)
2. `improvement-baseline.json` — auto-written after day 7
3. PM sweep modification to call collector weekly and check milestones
4. Monthly embed post in PM sweep
5. `/progress` command handler in bot.js (requires restart)
6. Milestone notification logic

Steps 1-4 require no restart. Step 5 requires restart.

---

## Open Questions

- **Proactive action tracking**: decisions-log entries don't currently tag L0-3 actions consistently. May need friction-log pattern or a new tag.
- **Sessions vs. calendar days**: violation rate "per session" is cleaner than "per day" (rate isn't meaningful on days with no usage).
- **Baseline timing**: if user installs HELM on a weekend with light usage, week-1 baseline will be atypically low. Consider using 14-day baseline window.
