# INF-07: Second Brain as Core Infrastructure
## Design Doc — For Review Before Implementation
## Written: 2026-05-17

---

## Current State (What's Wrong)

The second brain lives as a separate "workspace" — it requires a dedicated Discord channel,
a CLAUDE.md, and a manual user trigger. That means:
- {{USER_JERRY}} has to manually ask for synthesis ("what do I think about X?")
- There's no automatic pattern-surfacing — captures accumulate, nothing acts on them
- The workspace lifecycle (BML loops, go-live, etc.) is overkill for a background process

The connector agent already writes captures to `~/pap-workspace/second-brain/` correctly.
The synthesizer-nightly.sh script exists but just invokes a claude subprocess with no
structured output path or workspace context.

---

## Proposed Design

### Three components (all exist, just need wiring):

**1. Connector (already works)**
- User drops idea, URL, or note in #capture
- Security scans → deduplication → writes to `~/pap-workspace/second-brain/YYYY-MM-DD-{title}.md`
- Posts brief ACK to #capture, no further action

**2. Synthesizer (scheduled, no workspace)**
- Runs nightly at 11 PM PT via existing `synthesizer-nightly.sh`
- Reads ALL files in `~/pap-workspace/second-brain/`
- Looks for: recurring themes, connections between captures, items marked for revisit
- Decision gate: only post to #pap-improvements if something is genuinely interesting
  (new pattern spotted, a cluster of 3+ related captures, or a capture {{USER_JERRY}} flagged with ⭐)
- Output format: one Discord message max, 5-10 bullet points, no walls of text
- If nothing interesting: logs to `synthesizer.log` only, no Discord post (silence = good)

**3. User-triggered synthesis (already in synthesizer.md)**
- When {{USER_JERRY}} asks "what do I think about X?" → synthesizer reads second-brain/, responds in pap-chat
- No change to this path

---

## Implementation Steps

### Step 1 — Ensure connector writes to correct location (verify, not rebuild)
Connector already writes to `~/pap-workspace/second-brain/`. Confirm path is consistent.
Create the directory if it doesn't exist (mkdir -p).

### Step 2 — Update synthesizer.md to handle scheduled runs
Add a "SCHEDULED SYNTHESIS" section:
- Trigger: when invoked with no user message (from synthesizer-nightly.sh)
- Read second-brain/ directory
- Identify patterns using the Opinionated + Curatorial framework already in the agent
- Post to #pap-improvements only if something worth surfacing
- Always write a log entry to synthesizer.log

### Step 3 — Update synthesizer-nightly.sh
Current script points to the right channel (PAP_IMPROVEMENTS_CHANNEL = 1501656066340032776)
but invokes claude with no structured prompt. Update prompt to trigger the SCHEDULED SYNTHESIS path
explicitly: `claude -p "SCHEDULED SYNTHESIS RUN — read ~/pap-workspace/second-brain/, surface any patterns worth {{USER_JERRY}}'s attention. Post to #pap-improvements only if genuinely interesting. Always log outcome."`

### Step 4 — Remove second-brain workspace (if one exists)
The workspace channel and CLAUDE.md for "second-brain" can be retired. Connector and synthesizer
are both core agents — no workspace lifecycle needed.

---

## What Does NOT Change

- connector.md: no change needed
- synthesizer.md user-trigger path: no change needed
- #capture channel routing: no change
- launchd plist for nightly runs: already in place

---

## Open Questions for {{USER_JERRY}}

1. **Frequency**: nightly (11 PM PT) is the current schedule. Is that right, or would weekly synthesis be less noise?
2. **Threshold**: should synthesizer post even for a single interesting capture, or only when it spots a pattern across 2+ captures?
3. **Existing workspace**: is there a second-brain workspace channel to retire, or did it never get created?

---

## Effort Estimate

- Step 1 (verify/create dir): 5 min
- Step 2 (synthesizer.md update): 15 min
- Step 3 (nightly script update): 10 min
- Step 4 (retire workspace if needed): 5 min
Total: ~35 min after {{USER_JERRY}} approves this design

**No bot.js changes needed. No restart required.**
