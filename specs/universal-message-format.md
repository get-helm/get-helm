# Universal Message Format Spec

**Author:** PM (Marvin), 2026-06-14
**Engineer item:** UNIVERSAL-MESSAGE-FORMAT-001 (queued, 240 min, HIGH)
**Folds in:** rich-discord-ui-spec.md (action-formatting work becomes Phase 1)

---

## Problem

HELM agent messages are too long, dense, and hard to scan. The user reports every message has:
- 5 schema fields (PUSHBACK / VERIFICATION_REQUIRED / PROACTIVE_NEXT / Docs updated / RESEARCH) — adds ~80 words of trailer
- DELIVER bodies up to 200 words — typically read like status reports
- No visual cue for which messages need user action vs. inform vs. block
- Schema fields duplicate compliance information that bot.js already audits

Result: the user has to scan every message to find the ask, decision, or status. Apple's clarity principle is violated end-to-end.

## Goal

Every agent message — ACK, UPDATE, BLOCK, DELIVER — follows ONE format contract:
- ≤120 words DELIVER body (compressed schema saves ~80 vs today's 200 limit)
- One question per screen (Apple HIG): result OR decision OR FYI — never all three
- Schema fields compressed to a single-line icon trailer for Discord; full schema persists in helm-audit.log for compliance audit
- All 22 mandates still enforced — agent writes more, user sees less

## Apple HIG principles applied

| HIG principle | Today's behavior | Universal format rule |
|---|---|---|
| Clarity | Schema duplicates compliance info | Icon trailer; full schema in audit log |
| Deference | Headers, dividers, "---" everywhere | Use structure only when content demands it (3+ peer items). One thought = one paragraph. |
| Depth | Schema always visible | Compliance lives behind disclosure / audit log. User sees the answer; auditor sees the trail. |
| One question per screen | Report + ask + evidence + status mixed | Pick the message type. Result OR decision OR FYI. Never all three. |
| Ask = button, never prose | "Should I proceed?" / "Approve X so I can Y" | Verb-noun button. The ask IS the button label. |

## Message types (exhaustive)

### 1. ACK (no body — phase + cadence)
```
👍 [Agent: pm] ACK — investigating B-02 pattern. ~6 min, updates every 2 min.
```
Rules: 1 line. No questions. No narration. Cadence ≥ 120s.

### 2. UPDATE (1 line — state change only)
```
⏳ Gate: B-01 ✓ | B-22 ✓ | Verified queue writes, drafting spec.
```
Rules: 1 line. New information only. Never the final message.

### 3. BLOCK (orange embed)
- Color: orange (#E67E22)
- Title: one-sentence reason
- Body: what I tried (2 approaches) + what I need
- Trailer: full schema in audit log only

### 4. DELIVER — mini (result + 0-1 ask)
```
✅ B-23 caught its first violation at 1:36 AM. Live.
But action-formatting spec didn't queue — write failed silently. Tonight's run won't build it.
  [ Re-queue now ]  [ Skip — handle later ]
🔍✓ 🤔 premise stress-tested · ➡️ added backstop · 📚 read CPO-BACKLOG · 🧪 grep friction-log
```
Rules: ≤3 sentences body. One ask via button. Schema as icon trailer.

### 5. DELIVER — decision (yellow embed + [CONFIRM])
- Color: yellow (#F39C12)
- Body: the decision question, nothing else
- Embed: 1-2 line context max
- Schema: full schema in audit log only

### 6. DELIVER — FYI (green embed, no ask)
- Color: green (#2ECC71)
- One line. No schema visible. Audit retains schema.

## Schema compression (icon trailer)

bot.js render-compressor reads the full schema written by the agent and emits a single-line trailer:

| Field | Icon | Format |
|---|---|---|
| B-01 verify | 🔍 | `🔍✓` (pass) or `🔍 grep:file:line` (evidence) |
| B-15 pushback | 🤔 | `🤔 premise stress-tested` (6 words max) |
| B-09 proactive | ➡️ | `➡️ queued backstop` (6 words max) |
| B-11/12 research | 📚 | `📚 QMD score=0.82` or `📚 web 2 sources` |
| B-23 test | 🧪 | `🧪 grep returned 4 entries` |
| Docs updated | 📝 | `📝 3 files` (count only) |

Trailer rendered as Discord embed footer (2048 char limit, renders small).
Full schema persists in helm-audit.log and event-stream.jsonl for compliance audit.

## Bot.js implementation

1. **Pre-send hook** intercepts agent message; parses schema fields out of raw body.
2. **Compressor** maps each field to icon + 6-word summary.
3. **Audit writer** appends full schema to helm-audit.log keyed by message ID.
4. **Discord render** sends compressed message with footer trailer + optional embed (decision/FYI/BLOCK).
5. **Mandate validation** (existing) still scans the FULL agent-written schema before compression — compression does not weaken any gate.

## DELIVER body cap

Drops from 200 → 120 words. Compressed schema saves ~80 words. Total visible-to-user length: ~150 words max (body + trailer + embed).

## Phase plan

- **Phase 1 — Rich Discord UI embeds** (folds in rich-discord-ui-spec.md): orange BLOCK, yellow decision, green FYI. Build first; immediate visible improvement.
- **Phase 2 — Schema compressor**: bot.js parses schema, writes audit log, emits icon trailer.
- **Phase 3 — Body cap enforcement**: bot.js rejects DELIVER >120 words; agent gets one auto-resplit per turn.
- **Phase 4 — Migration**: roll across all agents (PM, engineer, workspace, help, curiosity). Validate no compliance regression.

## Open research (engineer to verify before Phase 2)

- Discord embed footer behavior with icons + non-ASCII trailer
- Mobile truncation: does Discord mobile truncate the trailer differently than desktop?
- Linear / Cursor / v0 2026 message-length conventions (qualitative benchmark)
- Whether one render compressor handles all agent schema variance or needs per-agent profiles

## 22-mandate check

| Mandate | Enforcement under spec |
|---|---|
| B-01 verify | full grep in audit log; icon `🔍✓` visible |
| B-02 estimates | unchanged (separate gate) |
| B-09 proactive | full reasoning in audit; icon `➡️` visible |
| B-11/12 research | full citations in audit; icon `📚` visible |
| B-15 pushback | full pushback in audit; icon `🤔` visible |
| B-17 brevity | structurally enforced via 120-word cap |
| B-22 no pause | structurally enforced — only valid prose question is `[CONFIRM:]` sentinel |
| B-23 test | full tested/verified line in audit; icon `🧪` visible |
| Other mandates | unchanged |

## Success criteria

1. Average DELIVER body length drops from current baseline to ≤120 words.
2. Mobile user can read one DELIVER without scrolling on a typical phone screen.
3. Every decision DELIVER renders with a button (no prose "should I" questions).
4. Audit log retains 100% of agent-written schema (compliance unchanged).
5. No B-17 violations in 7-day post-launch window.

## Risk + mitigation

- **Risk:** schema compression hides information the user wants to see → **Mitigation:** expand-on-tap (Discord reaction or footer click)
- **Risk:** different agents emit schema differently, compressor breaks → **Mitigation:** per-agent profile fallback, log compression failures to friction-log
- **Risk:** mandate auditors can't read compressed trailer → **Mitigation:** full schema lives in audit log; auditors read that

## Rollback

Single feature flag in bot.js: `USE_UNIVERSAL_FORMAT=true`. Set to false reverts to current schema-visible format.
