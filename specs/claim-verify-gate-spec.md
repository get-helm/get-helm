# DELIVER Claim-Verification Gate — Implementation Spec
## CLAIM-UNVERIFY-001 (Level 4 — Requires Approval Before Implementation)
## Status: SPEC — awaiting {{USER_JERRY}} approval

---

## Problem

Agents claim "I wrote file X" or "I edited line N" in DELIVER messages, but bot.js has no way to verify these claims. Unverified claims that are false produce silent state divergence — PM thinks work is done, it isn't.

---

## Proposed Gate Behavior

**On every DELIVER message received by bot.js:**

1. **Extract file path claims** — regex scan for patterns like:
   - `marvin-bot/bot.js` (bare paths)
   - `~/helm-workspace/...`
   - `[A-Za-z0-9_-]+\.md` (markdown files)
   - `[A-Za-z0-9_-]+\.sh` (shell scripts)

2. **For each extracted path:** stat the file for mtime. If mtime > (agentSpawnedAt - 30s): claim is plausible. If no recent mtime change: claim is suspicious.

3. **Reaction marking:**
   - All claims plausible → 🔍 reaction ("claims reviewed — plausible")
   - 1-2 suspicious claims → log to friction-log.md, 🔍 reaction
   - 3+ suspicious claims → 🤖 reaction + CLAIM-UNVERIFIED friction event + 30s pause before agent can spawn again

4. **PM reconciliation:** During T1 sweep, PM reads last 6h of friction-log for CLAIM-UNVERIFIED events and surfaces to engineer if pattern (3+ in session).

---

## Why mtime, not git diff

`git show HEAD:path` requires a commit — agents don't commit every file write. File mtime is the right signal: if the file was modified since the agent spawned, the claim is plausible.

**Limitation:** mtime can be updated by other processes. This is a heuristic gate, not a forensic proof.

---

## Implementation Plan (pending approval)

1. Add `extractFileClaims(messageText)` to bot.js — returns array of local paths
2. Add `verifyFileClaims(claims, spawnedAt)` — stat each file, return pass/suspicious/missing
3. Wire into DELIVER detection block (currently at ~L3684 where `ledgerOnDeliver` is called)
4. Add friction-log write for CLAIM-UNVERIFIED events
5. 30s pause: set `lastClaimViolationAt` in channel state, check in `enqueueClaudeRun`

**Estimated effort:** 90 min (as spec'd). This is a bot.js routing change — requires restart.

---

## Approval criteria

- [ ] {{USER_JERRY}} approves mtime-based verification approach (not git-based)
- [ ] {{USER_JERRY}} approves 3-claim threshold for 🤖 reaction + pause
- [ ] {{USER_JERRY}} approves 30s pause behavior (not a hard block)
- [ ] Engineer implements after approval

---
*Spec written: 2026-06-08 — awaiting CONFIRM in helm-improvements before any code change*
