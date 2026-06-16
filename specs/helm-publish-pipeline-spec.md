# HELM Publish Pipeline — Sandbox → Production
## Created: 2026-06-09 | Status: DESIGN (answers {{USER_JERRY}}'s 4 questions, Session 26)

{{USER_JERRY}}'s instance = sandbox. get-helm/helm = production. Updates flow one way:
sandbox → publish pipeline → production repo → user instances via helm-update.sh.

---

## Q1: How does {{USER_JERRY}}'s HELM match the structure users get?

It already does, by construction. PARTITION.json (built 2026-06-08) declares every
file as Core / User / Runtime:

- **Core** = the product. Identical across all instances. {{USER_JERRY}}'s copy is the master.
- **User** = personal. Users get blank templates via helm-init.sh; {{USER_JERRY}}'s versions
  never leave the machine.
- **Runtime** = generated. Never published.

Parity guarantee: users receive exactly the Core set + templates. {{USER_JERRY}}'s instance is
a superset (Core + his User data). Same directory layout, same scripts, same agents.

**Parity verification (new):** CI job on every publish — clean checkout, run
helm-init.sh with dummy config, run smoke test (partition check + bot dry-start).
If the repo can't bootstrap a working instance, publish fails.

---

## Q2: Defined publish process (initial + updates)

One script: `helm-publish.sh`. Never `git push` from the live workspace by hand.

1. **Stage** — copy ONLY files allowlisted as Core in PARTITION.json into a clean
   staging dir. Allowlist, not denylist: a new file that isn't in the manifest is
   excluded by default and flagged for classification.
2. **Scan (4 layers, any hit = hard block, exit 1):**
   - a. Secret scan — existing pre-deploy-security-check.sh (creds, tokens, keys)
   - b. Personal-data scan — pattern file: names ({{USER_JERRY}}, Le, {{USER_FAMILY_MEMBER_2}}, Stephen),
     emails, domain, phone, account fragments, Discord IDs, IPs, SSH paths,
     1Password item names
   - c. Placeholder integrity — Core files must use {{USER_*}} placeholders;
     a resolved personal value in a Core file = block
   - d. Partition check — helm-partition-check.sh must pass
3. **Review gate** — first publish of any file: human-readable diff posted for
   {{USER_JERRY}}'s approval (L4). Subsequent updates to already-published files: auto
   (L2) with audit log entry.
4. **Push** — staging dir → get-helm/helm via the scoped HELM PAT from Vault.
   Tag with version. Append to decisions-log + helm-audit.
5. **Verify** — CI parity job (Q1) runs; failure auto-reverts the tag.

---

## Q3: Refactoring — how old/deprecated code gets cleaned

The first-publish review gate IS the refactor forcing function:

- Every Core file passes through a one-time **publish review** before first
  publish: Is it current? Does it reference dead concepts (PAP naming, retired
  flows, superseded specs)? Is it needed at all?
- Three outcomes per file: **publish** / **refactor first** (queued to engineer
  with specific cleanup) / **retire** (deleted from sandbox too — not published,
  not kept).
- Do it directory-by-directory (scripts → agents → CLAUDE.md/behaviors → specs),
  batches of ≤10 files, so it's reviewable and doesn't stall the split.
- Result: production repo starts clean by definition — nothing deprecated can
  reach it because everything passed review on the way in.

---

## Q4: Guarantee no personal data in Core — ever

Defense in depth, structural first, scanning last:

1. **Templating (prevention)** — Core files never contain personal values, only
   {{USER_*}} placeholders resolved at runtime from CONFIG.md (User partition).
   Already the pattern in CLAUDE.md ({{USER_DOMAIN}}).
2. **Agent rule (prevention)** — add to behaviors.md: "Never write user-specific
   values (names, IDs, domains, emails) into Core-partition files. User values go
   in CONFIG.md / user files only." Violation = friction-log.
3. **Allowlist publish (containment)** — unclassified files can't leak; they're
   excluded by default.
4. **4-layer scan (detection)** — every publish, no exceptions, hard block.
5. **Weekly drift scan (audit)** — security agent greps the Core partition on the
   sandbox for personal-data patterns, so contamination is caught in days, not at
   publish time.
6. **History safety** — production repo history starts from the staged copy, never
   from sandbox git history. A leaked value can never hide in old commits.

---

## Build order

1. Personal-data pattern file + scan script (extends pre-deploy-security-check.sh)
2. helm-publish.sh (stage + scan + push)
3. First-publish review batches (refactor pass, directory-by-directory)
4. CI parity job on get-helm/helm
5. behaviors.md rule + weekly drift scan hook

Items 1-2 are engineer tasks; 3 needs {{USER_JERRY}}'s review approvals; 4-5 follow.
