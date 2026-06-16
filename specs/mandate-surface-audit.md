# Mandate Execution-Surface Audit
# Generated 2026-06-10 — MANDATE-SURFACE-AUDIT-001
# Input: specs/mandates-ground-truth.md (Phase 1 data)
# Lens: B-09 root cause — spec on wrong surface never executes
#
# For each mandate:
# (1) WHERE is enforcement supposed to execute?
# (2) Has that surface EVER executed? (log citation or NONE)
# (3) Verdict: right-surface / wrong-surface / dead-code
# (4) Proposed fix (wrong-surface items queued as follow-ups)
#
# Evidence sources: ~/helm-workspace/system/friction-log.md (2405 lines, cross-searched)

---

## Verdict Legend

- **RIGHT-SURFACE/CORRECT**: code on correct surface, log evidence found
- **RIGHT-SURFACE/INCOMPLETE**: code on correct surface, gap in what it detects
- **RIGHT-SURFACE/WRONG-VISIBILITY**: code fires but logs/reacts in wrong way per v3 tier spec
- **RIGHT-SURFACE/NO-EVIDENCE**: code exists on correct surface, no friction-log evidence found
- **WRONG-SURFACE**: enforcement relies on agent prompt only — no bot.js gate

Wrong-surface mandates need a follow-up engineer task to move detection to a surface that actually runs.

---

## Execution Surface Definitions

| Surface | Runs when? | Reliability |
|---|---|---|
| bot.js gate | Every message processed | High — always fires |
| PM sweep step | Each scheduled sweep (every ~10 min) | High — cron-driven |
| Script/cron | On schedule | Medium — depends on launchd |
| Agent prompt | Agent reads turn-protocol.md | Low — agents skip, mis-apply, or forget |

The B-09 insight: mandates whose enforcement lives only in agent prompt are structurally dead — they depend on agent self-compliance with no external verification loop.

---

## 22-Row Surface Audit

| # | Mandate | Supposed surface | Actual code | Execution evidence | Verdict | Proposed fix |
|---|---|---|---|---|---|---|
| B-01 | Truthfulness — file readback | bot.js L2 gate | bot.js L4225–4234 CLAIM-NO-READBACK | friction-log CLAIM-NO-READBACK 10+ entries (2026-06-09/10) | RIGHT-SURFACE/WRONG-VISIBILITY | Remove 🤖 reaction (user-visible); keep friction-log only per v3 Tier 1 |
| B-02 | ACK must declare time + cadence | bot.js L2 gate | bot.js L3913–3928 | friction-log B02_OVERRUN (50+ entries), B02_ACK_NO_ESTIMATE (2026-06-09) | RIGHT-SURFACE/CORRECT | None |
| B-03 | Checkpoint must have task steps | bot.js L2 gate | bot.js L3934–3938, L4381–4394 | WI-017 taskPlan references in friction-log (2026-06-06); no B03-NO-TASKPLAN entries in recent log | RIGHT-SURFACE/NO-EVIDENCE | Verify gate writes B03-NO-TASKPLAN to friction-log (not event-stream only); run test case |
| B-04 | No sleeping — quiet >5 min | bot.js L2 gate | bot.js L1516, L1538, L5796–5813 | friction-log B04-ORPHAN-EXIT (2026-06-08/09, multiple) | RIGHT-SURFACE/WRONG-VISIBILITY | Silence L1538 visible warn ("⏳ Still working"); v3 Tier 2 = silent recovery unless spawn fails |
| B-05 | Seamless restart — read checkpoint | bot.js L2 gate (intended) | agent prompt only — zero bot.js code found | NO evidence in friction-log or event-stream | WRONG-SURFACE | Add bot.js detector: if agent resume path lacks checkpoint read in first 3 tool calls → friction-log b05_context_request. Queue as follow-up. |
| B-06 | No "Should I?" in DELIVER | bot.js L1 gate | bot.js L4263–4276 B06-PROACTIVE-GATE | validation_failure entries show PROACTIVE_NEXT scanned; no direct B06 entries but gate overlaps with schema validation | RIGHT-SURFACE/INCOMPLETE | Extend B06 scan to full DELIVER body text (not only PROACTIVE_NEXT field); body check is prompt-only today |
| B-07 | 2 approaches before BLOCK | bot.js L2 gate | bot.js L4027–4039 B07-BLOCK-GATE | friction-log B07-BLOCK-NO-EVIDENCE 10+ entries (2026-06-08/09) | RIGHT-SURFACE/CORRECT | None |
| B-08 | No passback to user | bot.js L2 gate | bot.js L4582–4600 B08_PASSBACK_PATTERNS | friction-log b08_passback_flag (2026-06-09) | RIGHT-SURFACE/CORRECT | None |
| B-09 | PM self-triggers after DELIVER | bot.js L2 gate | bot.js L4541–4551 (trigger fires); no failure detector | Positive trigger fires confirmed; NO evidence of "failed to self-trigger" detection | RIGHT-SURFACE/INCOMPLETE | Add negative-space detector: if PM DELIVER has no pm_engineer_complete_trigger event within 60s → friction-log b09_no_self_trigger. Queue as follow-up. |
| B-10 | DELIVER items verified in registry | bot.js L2 gate | bot.js L4431–4474 | NO b10_missing_done_mark or b10_done_mark_verified in friction-log (2405 lines searched) | RIGHT-SURFACE/NO-EVIDENCE | Verify gate writes to friction-log (grep bot.js L4431 for friction-log write path); likely writing to event-stream only. Queue audit. |
| B-11 | RESEARCH field non-empty | bot.js L1+L2 gate | bot.js L4068–4069 | validation_failure entries with missing=["RESEARCH"] confirmed in log | RIGHT-SURFACE/CORRECT | None |
| B-12 | QMD citation — query+score | bot.js L1+L2 gate | bot.js L4494–4504 MANDATE-GATE-004 | friction-log B12-QMD-CITATION (2026-06-09, multiple) | RIGHT-SURFACE/CORRECT | None |
| B-13 | CAPABILITIES check before implement | bot.js L2 gate (intended) | agent prompt only — no bot.js code | NO evidence in friction-log | WRONG-SURFACE | Add PM sweep T1-B13 step: if any engineer DELIVER lacks "CAPABILITIES: checked PROVEN" string in checkpoint notes → friction-log B13-NO-CHECK. Queue as follow-up. |
| B-14 | Skills check before implement | bot.js L2 gate (intended) | agent prompt only — no bot.js code | NO evidence in friction-log | WRONG-SURFACE | Add bot.js spawn-gate: before agent start, if channel-state taskPlan includes implementation step, verify last checkpoint has "SKILLS:" note → friction-log B14-NO-SKILLS-CHECK. Queue as follow-up. |
| B-15 | Provocative — challenge premise | bot.js L1 gate | bot.js L4071–4096 NONE-LOOPHOLE-001 | NO NONE-LOOPHOLE entries found in 2405-line friction-log (recent 2 weeks searched) | RIGHT-SURFACE/NO-EVIDENCE | Verify gate fires: send test DELIVER with PUSHBACK: none → confirm NONE-LOOPHOLE logs. If not firing, check bot.js L4071 condition. |
| B-16 | Context required before proceeding | bot.js L2 gate (intended) | agent prompt only — no bot.js code | NO evidence in friction-log | WRONG-SURFACE | Add bot.js gate: if DELIVER has no checkpoint notes containing "Context check:" → friction-log B16-NO-CONTEXT-CHECK. Scope to tasks with 2+ taskPlan steps. Queue as follow-up. |
| B-17 | DELIVER body ≤200 words | bot.js L1+L2 gate | bot.js L4278–4297 B-17-LENGTH-GATE | friction-log B17-LENGTH 30+ entries (2026-06-08/09/10) | RIGHT-SURFACE/CORRECT | None |
| B-18 | Rich UI for decisions | bot.js L1+L2 gate | bot.js L4299–4328 B-18-RICH-UI-GATE | friction-log B18-PROSE-QUESTION 10+ entries (2026-06-08) | RIGHT-SURFACE/CORRECT | None |
| B-19 | No internal paths to user | bot.js L1+L2 gate | bot.js L3997–4013 B-19-PATH-GATE | friction-log B19_INTERNAL_PATH (2026-06-10), B19-PATH entries | RIGHT-SURFACE/CORRECT | None |
| B-20 | No timeline promises | bot.js L1+L2 gate | bot.js L4015–4024, L4098–4107 | friction-log B20-TIMELINE (2026-06-10) | RIGHT-SURFACE/CORRECT | None |
| B-21 | Spawn within 90s | bot.js L2 gate | bot.js L1477–1508 b21DelayTimer | NO b21_spawn_delayed entries in friction-log (recent 2 weeks) | RIGHT-SURFACE/WRONG-VISIBILITY | Fix threshold: 60s event → silent (ok); 120s alert → should be at 90s per spec; alert should post to agent's own channel, not PAP_IMPROVEMENTS_CHANNEL |
| B-22 | No pause — no "which step first" | bot.js L1+L2 gate | bot.js L4330–4378 | friction-log B22-ENUM 6+ entries (2026-06-09/10), B22-NO-PAUSE | RIGHT-SURFACE/CORRECT | None |

---

## Summary Table

| Verdict | Count | Mandates |
|---|---|---|
| RIGHT-SURFACE/CORRECT | 10 | B-02, B-07, B-08, B-11, B-12, B-17, B-18, B-19, B-20, B-22 |
| RIGHT-SURFACE/INCOMPLETE | 2 | B-06, B-09 |
| RIGHT-SURFACE/WRONG-VISIBILITY | 3 | B-01, B-04, B-21 |
| RIGHT-SURFACE/NO-EVIDENCE | 3 | B-03, B-10, B-15 |
| WRONG-SURFACE | 4 | B-05, B-13, B-14, B-16 |

---

## Wrong-Surface Fix Queue (follow-up items)

These 4 mandates live only in agent prompt text. No bot.js gate catches violations. They need to move to a surface that runs automatically:

### B-05: Seamless restart detection
- **Current**: turn-protocol.md prompt text only
- **Fix**: bot.js checkpoint-resume path check — if first 3 tool calls after resume include no checkpoint read → friction-log b05_context_request
- **Estimate**: 45 min, no restart required

### B-09 negative-space: PM self-trigger failure
- **Current**: trigger fires (positive), but no detector for PM skipping self-trigger
- **Fix**: pm-jobs.md sweep step: if last PM DELIVER > 10 min ago and no pm_engineer_complete_trigger event → friction-log b09_no_self_trigger
- **Estimate**: 30 min, no restart required

### B-13: CAPABILITIES pre-approach check
- **Current**: turn-protocol.md prompt text only
- **Fix**: bot.js or PM sweep: on engineer DELIVER, check checkpoint notes for "CAPABILITIES:" string → friction-log B13-NO-CHECK if absent
- **Estimate**: 45 min, no restart required

### B-14: Skills pre-approach check
- **Current**: turn-protocol.md prompt text only
- **Fix**: bot.js: on agent spawn for implementation task, verify checkpoint notes contain "SKILLS:" → friction-log B14-NO-SKILLS-CHECK
- **Estimate**: 45 min, no restart required

### B-16: Context check before proceeding
- **Current**: turn-protocol.md prompt text only
- **Fix**: bot.js: on DELIVER where totalSteps ≥ 2, if checkpoint notes lacks "Context check:" → friction-log B16-NO-CONTEXT-CHECK
- **Estimate**: 30 min, no restart required

---

## Visibility Fix Queue (right-surface but wrong behavior)

These 5 mandates detect correctly but report in the wrong visibility tier per v3:

### B-01: Remove 🤖 reaction
- Remove L4234 addReaction call, keep friction-log write (v3 Tier 1 = silent)
- Estimate: 15 min, restart required

### B-04: Silence warn post
- L1538 "⏳ Still working" post should be silent per v3 Tier 2
- Keep B04-ORPHAN-EXIT visible posts (correct for failure case)
- Estimate: 20 min, restart required

### B-21: Fix spawn threshold and channel
- Change 120s threshold to 90s; post ⚠️ to agent's own channel (not PAP_IMPROVEMENTS_CHANNEL)
- Estimate: 20 min, restart required

### B-03, B-10, B-15: Verify friction-log writes
- Run test cases to confirm these gates write to friction-log (not event-stream only)
- If not: add explicit friction-log write at each gate
- Estimate: 30 min, no restart required

---

## Feeds: Fable Phases 2-3
- Phase 2: bot.js ghost-code removal → WRONG-SURFACE mandates confirm which prompt-only text can stay vs needs a gate
- Phase 3: surface fixes queue → the 4 WRONG-SURFACE items + 3 NO-EVIDENCE items are the concrete engineer tasks
