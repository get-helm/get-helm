# Placeholder Lifecycle Architecture — Closed-Loop Personalization

**Status:** Plan (awaiting {{USER_JERRY}} approval)
**Author:** product-manager
**Date:** 2026-06-15
**Drives:** beta-readiness — "the entire HELM experience, scrubbed of personal info, fillable during onboarding"

---

## Problem (verified, not assumed)

{{USER_JERRY}}'s intuition is correct: there is no process that fills placeholders after onboarding, and we need templates already stripped of his info. Both halves are partially built but **not closed-loop**, so they drift and leak. Verified evidence:

1. **Publish side already scrubs** — `helm-publish.sh` v2 is a denylist model (ships marvin-bot + helm-workspace + .claude/agents minus a block-list), runs `helm-placeholder-convert.sh` (replaces ~11 personal values with `{{USER_*}}`), a 4-layer scan, and an npm-install completeness test. This part is good.

2. **No canonical token manifest** — the set of `{{USER_*}}` tokens is invented in three disconnected places and they disagree:
   - `helm-placeholder-convert.sh` produces: `USER_EMAIL, USER_GMAIL, USER_FULL_NAME, USER_FAMILY_MEMBER_1/2, USER_DOMAIN, USER_HOME, USER_GITHUB, USER_JERRY, USER_LAST_NAME`
   - Shipped files actually contain (token → count): `USER_JERRY ×178, USER_DOMAIN ×34, USER_JTOLZMAN ×11, USER_EMAIL ×8, USER_HOME ×4, USER_PREFERRED_NAME ×3, USER_VPS_SSH ×2, USER_VPS_IP ×2, USER_LAST_NAME ×2, USER_GMAIL ×2, USER_GITHUB ×2, USER_FULL_NAME ×2, USER_DISCORD_SERVER_ID ×2, USER_NAME ×1, USER_ID ×1`
   - Collision: convert.sh emits `USER_GITHUB` for {{USER_GITHUB}}, but 11 files hardcode `{{USER_GITHUB}}`. Two tokens, same value, neither canonical.
   - `USER_NAME` vs `USER_PREFERRED_NAME` vs `USER_JERRY` all mean "what to call the user."

3. **No hydration step** — `helm-init.sh` does ZERO `{{}}` substitution (grep confirms). It collects 4 values (name, email, timezone, + bot/channel IDs) and writes a few fresh config files via heredoc. It never walks the cloned repo to replace the 250+ `{{USER_*}}` occurrences. **Result: after install, a new user's CLAUDE.md literally says `{{USER_JERRY}}` 178 times.** This is the missing post-onboarding process.

4. **Onboarding collects less than the manifest needs** — wizard never asks for `USER_DOMAIN`, `USER_LAST_NAME`, family members, etc. Some it collects under a different name than the token. So even with hydration, tokens would be left unfilled.

5. **Template drift** — two template copies exist: `helm-workspace/*.md.template` AND `helm-workspace/specs/templates/*.template.md`. No single source.

---

## Solution — one manifest, four stages, each validates against it

Pattern confirmed by industry standard (Cookiecutter: a single `cookiecutter.json` manifest is the template's public interface; Jinja2 substitutes `{{ }}` tokens at generation time; Cruft links the generated project back to the template for ongoing update sync).

### Artifact 1 — `placeholder-manifest.json` (single source of truth)
Every `{{USER_*}}` token defined once:
```json
{
  "USER_JERRY":            {"desc":"what to call the user", "collect":"onboarding", "question":"What should I call you?", "required":true},
  "USER_DOMAIN":           {"desc":"user's web domain", "collect":"onboarding", "required":false, "default":""},
  "USER_HOME":             {"desc":"OS username", "collect":"auto", "source":"$USER"},
  "USER_GITHUB":           {"desc":"github username", "collect":"onboarding", "required":false},
  "USER_DISCORD_SERVER_ID":{"desc":"guild id", "collect":"onboarding", "required":true},
  "...": "..."
}
```
- `collect`: `onboarding` (ask) | `auto` (detect) | `vault` (credential ref) | `derived`
- First: consolidate duplicates → ONE canonical token each (kill `USER_JTOLZMAN`→`USER_GITHUB`, `USER_NAME`→`USER_JERRY`).

### Artifact 2 — publish-side scrub reads the manifest (refactor `helm-placeholder-convert.sh`)
Replace its hardcoded substitution list with the manifest's personal→token map. The scan then asserts: **(a) zero personal values leaked, (b) every `{{USER_*}}` token in shipped files exists in the manifest** (no orphan tokens). Drift becomes impossible to publish.

### Artifact 3 — install-side hydration (NEW: `helm-hydrate.sh`) — the missing piece
Runs as the LAST onboarding step. Inputs: collected answers keyed by manifest token. Walks every shipped text file, substitutes `{{USER_*}}` → value. Then **self-verifies**: `grep -r '{{USER_'` across the install — any remaining token means a value wasn't collected → prompt for it inline or flag. This is the post-onboarding process {{USER_JERRY}} described, and it closes the loop with a completeness assertion.

### Artifact 4 — onboarding collects against the manifest
Wizard (conversational P5.1 flow, already queued as CONVERSATIONAL-ONBOARD-001) iterates manifest tokens where `collect:onboarding`, asks each once, auto-detects `collect:auto` (USER_HOME=$USER, timezone). Guarantees onboarding gathers exactly what hydration needs — no more, no less.

---

## Why this is closed-loop (the property that prevents {{USER_JERRY}}'s "avoidable mistakes")

```
manifest defines tokens
   → publish scrubs personal→token & asserts every shipped token is in manifest
   → onboarding collects every manifest token marked 'onboarding'
   → hydration fills every token & asserts none remain ({{USER_ count == 0)
```
Each stage validates against the same manifest. A new token can't ship without a manifest entry; a manifest token can't go uncollected; an uncollected token can't survive hydration silently. Structurally drift-proof.

## Bonus: future-improvement delivery (answers {{USER_JERRY}}'s earlier "why didn't improvements reach users")
Adopt the Cruft pattern: the installed repo records the template version it came from. A `helm update` pulls new HELM improvements (config + code) and re-hydrates with the user's stored answers. This is how every future improvement reaches existing users without a reinstall.

---

## Build sequence (cheapest → most expensive, each independently testable)
1. **Manifest** — author `placeholder-manifest.json` from the verified token census above; consolidate duplicates. (foundation — everything reads it)
2. **Refactor convert.sh** to read manifest + add orphan-token assertion to the scan.
3. **Build `helm-hydrate.sh`** + the `grep {{USER_` completeness gate. Test: clone → hydrate with fake answers → assert zero tokens remain.
4. **Wire onboarding** to iterate the manifest (folds into CONVERSATIONAL-ONBOARD-001).
5. **Consolidate template dirs** to one location.
6. (post-beta) `helm update` / Cruft-style sync.

## Real test of done
A clean clone, hydrated with a fake user's answers, has zero `{{USER_` strings remaining AND zero real personal values, AND boots (`npm install` + bot.js syntax already gated in publish).
