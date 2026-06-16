# Mandates Ground-Truth Audit — Phase 1
# Generated 2026-06-10 — FABLE-PHASE1-AUDIT-001
# Reference: specs/fable-mandates-brief.md + specs/helm-architecture-v3-design.md

## Status legend
- **ENFORCED**: code exists at named file:line, detection fires correctly per v3 visibility tier
- **PARTIAL**: detection code exists, but response is wrong vs v3 spec (wrong visibility or incomplete coverage)
- **ASPIRATIONAL**: prompt text only — no bot.js detection code found after grepping named patterns

## V3 visibility tiers (from helm-architecture-v3-design.md L118-120)
- Tier 1: always silent (friction-log only)
- Tier 2: silent recovery, visible only on failure
- Tier 3: always visible

---

| # | Mandate | v3 Layer | v3 Tier | Status | Code citation | Evidence / gap |
|---|---|---|---|---|---|---|
| B-01 | Truthfulness — did file read-back happen? | L1 (agent self-check) | L3 pattern loop | **PARTIAL** | bot.js L4225–4234 CLAIM-NO-READBACK gate | Detection: checks `Verified:` citation in DELIVER; adds 🤖 reaction (visible). Gap: v3 says violations → silent; 🤖 reaction is user-visible. Prompt gate in turn-protocol.md pre-DELIVER section ✓ |
| B-02 | Estimates — ACK must declare time + cadence | L1 (agent) | L3 pattern loop | **ENFORCED** | bot.js L3913–3928 | `hasTimeEstimate` regex checks `N min`, `about N`, `estimate uncertain`. Writes `lastValidationError` to channel-state (silent to {{USER_JERRY}}) + friction-log. Test: ACK without "N min" → friction-log `B02_ACK_NO_ESTIMATE` fires ✓ |
| B-03 | Task plan — checkpoint must have steps | L1 (agent) | L3 pattern loop | **ENFORCED** | bot.js L3934–3938 (FIX-RESTART-002), L4381–4394 (WI-017) | L3934: warns when resume has <2 taskPlan steps → friction-log. L4381: DELIVER with currentStep=0 + totalSteps≥2 + taskPlan<2 → friction-log `B03-NO-TASKPLAN` (silent) ✓ |
| B-04 | No sleeping — agent quiet >5 min after ACK | L2 (bot.js) | Tier 2 (silent recovery) | **PARTIAL** | bot.js L1516 silenceInterval, L5796–5813 B04-ORPHAN-EXIT-001 | Detection fires. Gap: L1538 posts visible "⏳ Still working" at warn threshold and L1542 "⏳ Agent quiet for X min" — these are user-visible. v3 Tier 2 = silent to user unless spawn fails. Orphan-exit at L5808 posts visible ⚠️ message (correct for failure case). Silence warn should be silent per v3. |
| B-05 | Seamless restart — agent must read checkpoint on resume | L2 (bot.js) | Tier 1 (silent) | **ASPIRATIONAL** | nothing found after grepping: `b05`, `seamless`, `context_request`, `b05_context` in bot.js | Only in turn-protocol.md prompt text. No code detects "agent restarted without reading checkpoint." Checkpoint empty-notes detection at L3930 is related but only fires on empty notes, not on agent ignoring context. |
| B-06 | Proactive — no "should I?" in DELIVER | L1 (agent) | L3 pattern loop | **PARTIAL** | bot.js L4263–4276 B06-PROACTIVE-GATE | Scans PROACTIVE_NEXT field for approval phrases → friction-log (silent) ✓. Gap: no scan of full DELIVER body for "Should I?" per turn-protocol B-06 body scan rule. Body check is prompt-only. |
| B-07 | Overcome blockers — 2 approaches before BLOCK | L1 (agent) | L3 pattern loop | **ENFORCED** | bot.js L4027–4039 B07-BLOCK-GATE | Scans BLOCK messages for evidence keywords (tried/attempted/approach 1/2/alternative). Friction-log `B07-BLOCK-NO-EVIDENCE` (silent). Test: BLOCK without "tried" → friction-log fires ✓ |
| B-08 | No passback — don't ask {{USER_JERRY}} to do what agent can | L1 (agent) | L3 pattern loop | **ENFORCED** | bot.js L4582–4600 B08_PASSBACK_PATTERNS | 7-pattern regex (you'll need to manually, go ahead and log/navigate, etc.). Friction-log `b08_passback_flag` (silent). Test: "you'll need to manually run X" → friction-log fires ✓ |
| B-09 | Agents drive product — PM self-triggers after DELIVER | L2 (bot.js) | Tier 1 (silent) | **PARTIAL** | bot.js L4541–4551 pm_engineer_complete_trigger | PM auto-trigger ON DELIVER fires (correct mechanism). Gap: no detection of PM failing to self-trigger — the v3 spec says "log to friction-log when PM didn't self-trigger after last DELIVER." Current code only fires the trigger; doesn't log when it doesn't fire. |
| B-10 | Product mgmt — DELIVER items verified in task-registry | L2 (bot.js) | Tier 1 (silent) | **ENFORCED** | bot.js L4431–4474 b10 state transition check | Engineer DELIVER checked for completion language + item IDs → verified against task-registry.jsonl. Friction-log `b10_missing_done_mark` or `b10_done_mark_verified` (silent) ✓ |
| B-11 | Research — RESEARCH field non-empty | L1 (agent) | L3 pattern loop | **ENFORCED** | bot.js L4068–4069 missingFields check | RESEARCH: field presence checked in DELIVER (same gate as PUSHBACK/VERIFICATION_REQUIRED). Missing → `lastValidationError` in channel-state + `validation_failure` event (silent) ✓ |
| B-12 | QMD citation — query string + score required | L1 (agent) | L3 pattern loop | **ENFORCED** | bot.js L4494–4504 MANDATE-GATE-004 | If RESEARCH says "searched QMD" but lacks `query="..."` or `score=N.N` → friction-log `B12-QMD-CITATION` (silent). Test: `RESEARCH: searched QMD` without query string → fires ✓ |
| B-13 | CAPABILITIES check before implementation | L1 (agent) | none | **ASPIRATIONAL** | nothing found after grepping: `B-13`, `capabilities.*check`, `pre.approach`, `b13` in bot.js | Only in turn-protocol.md B-13/B-14 PRE-APPROACH GATE section. No code detection. |
| B-14 | Skills check — use skill if one exists | L1 (agent) | none | **ASPIRATIONAL** | nothing found after grepping: `B-14`, `b14`, `skills.*check` in bot.js | Only in turn-protocol.md. No code detection. |
| B-15 | Provocative — challenge premise before agreeing | L1 (agent) | L3 pattern loop | **PARTIAL** | bot.js L4071–4096 NONE-LOOPHOLE-001 | Detects bare `none` in PUSHBACK field (<15 chars, no explanation) → friction-log `NONE-LOOPHOLE` (silent). Gap: no quality check beyond bare-none; no detection of challenge content. Prompt gate in CHALLENGE-FIRST section ✓. |
| B-16 | Curious — name missing context before proceeding | L1 (agent) | none | **ASPIRATIONAL** | nothing found after grepping: `B-16`, `b16`, `context.required`, `b16_context` in bot.js | Only in turn-protocol.md B-16 CONTEXT-REQUIRED CHECKLIST. No code detection. |
| B-17 | Comms — DELIVER body ≤200 words | L1+L2 | Tier 1 (silent) | **ENFORCED** | bot.js L4278–4297 B-17-LENGTH-GATE | Counts words after stripping schema fields. >200: friction-log `B17-LENGTH`. >220: additional `b17_length_excess` event (silent). Test: 221-word DELIVER → both events fire ✓ |
| B-18 | Rich UI — decision questions need sentinels | L1+L2 | Tier 1 (silent) | **ENFORCED** | bot.js L4299–4328 B-18-RICH-UI-GATE | Detects decision-question pattern (`which`, `should I`, `want me`, etc.) without `[CONFIRM/BUTTON/SELECT]` sentinel. Writes `lastValidationError` to channel-state + friction-log (silent to {{USER_JERRY}}) ✓ |
| B-19 | Doc sharing — no internal ~/paths to user | L1+L2 | Tier 1 (silent) | **ENFORCED** | bot.js L3997–4013 B-19-PATH-GATE | Strips code blocks + schema fields; regex matches `~/` or `{{USER_HOME}}` paths → friction-log `B19-PATH-EXPOSED` + `b19_violation` event (silent). Excludes `.local/bin`, `opt/homebrew` system paths ✓ |
| B-20 | No timelines — no date/time promises | L1+L2 | Tier 1 (silent) | **ENFORCED** | bot.js L4015–4024 (UPDATE), L4098–4107 (DELIVER) | Pattern: "by tomorrow/monday/...", "within N days", "I'll have this done by". Both UPDATE and DELIVER phases checked → friction-log `B20-TIMELINE` (silent) ✓ |
| B-21 | Spawn — first message within 90s | L2 | Tier 3 (visible) | **PARTIAL** | bot.js L1477–1508 b21DelayTimer + b21KillTimer | 60s: appends `b21_spawn_delayed` event (silent only). 120s: posts visible ⚠️ to #helm-improvements ✓ (Tier 3 correct). Gap: spec says 90s; bot.js fires at 120s. b21_spawn_delayed at 60s has no visible alert. Also: v3 says ⚠️ in agent's channel; current posts to PAP_IMPROVEMENTS_CHANNEL. |
| B-22 | No pause — don't ask which step to start first | L1+L2 | Tier 1 (silent) | **ENFORCED** | bot.js L4330–4345 (phrase scan), L4348–4378 (enum scan) | Phrase scan: `which should I`, `which do you want me to` etc. → friction-log `B22-NO-PAUSE`. Enum scan: 3+ bullets after question without sentinel → channel-state `lastValidationError` + friction-log (silent). Test: "Which should I start with?" in DELIVER → both fire ✓ |

---

## Summary

| Status | Count | Mandates |
|---|---|---|
| ENFORCED | 12 | B-02, B-03, B-07, B-08, B-10, B-11, B-12, B-17, B-18, B-19, B-20, B-22 |
| PARTIAL | 6 | B-01, B-04, B-06, B-09, B-15, B-21 |
| ASPIRATIONAL | 4 | B-05, B-13, B-14, B-16 |

## Key gaps for Phase 2

**Partial — wrong visibility (needs fix per v3):**
1. B-01 at L4234: add 🤖 reaction → remove, keep friction-log only
2. B-04 at L1538: silence warn posts visible "⏳ Still working" → make silent
3. B-21 at L1503-1504: ⚠️ posts to PAP_IMPROVEMENTS_CHANNEL → should be agent's own channel; threshold 120s vs spec's 90s

**Partial — incomplete detection:**
4. B-06 at L4263: only scans PROACTIVE_NEXT field; needs full DELIVER body scan for "Should I?"
5. B-09: no detection when PM fails to self-trigger after DELIVER (only fires the trigger, doesn't verify it fired)
6. B-15: bare-none check exists; no quality gate on PUSHBACK content

**Aspirational — no bot.js code at all:**
7. B-05: no checkpoint-resume detection
8. B-13: no CAPABILITIES.md check verification
9. B-14: no skills-list check verification
10. B-16: no context-required check verification

---

## Phase 2 scope (auto-queued per brief — {{USER_JERRY}} pre-approved 2026-06-09)
Per fable-mandates-brief.md Phase 2: implement v3 detection table for B-04/05/09/10/17/18/19/20/21.
Focus: ghost-code removals (visible reactions → silent) + missing detectors (B-05, B-09 failure detection).
