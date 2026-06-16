# MENTION-REMOVE-001 — Remove the @-mention requirement (talk to HELM by just speaking)

**Decision ({{USER_JERRY}} 2026-06-16):** Speaking in HELM's channels IS talking to HELM. There is
no reason to require an `@`-mention for a single-user, dedicated-channel bot — the @ only
exists to disambiguate multiple bots and avoid replying to all human chat, neither of which
applies here. This is a locked decision (Appendix B, 2026-06-15) that drifted in
implementation. Treat as its own TESTED build — changing mention handling can break existing
command paths, so this is not a wording tweak.

## Root-cause bugs to fix (verified in bot.js)
1. **Non-interpolating literals:** ~27 user-facing `@HELM` references were changed to
   single-quoted `'@${AGENT_NAME}'`, which render as the raw text `@${AGENT_NAME}` instead of
   the user's bot name (e.g. "Atlas"). Convert to proper interpolation (template literals) or
   resolved variable so the user sees their actual agent name.
2. **Command parser hardcoded to "helm":** the command parser still matches the literal string
   "helm" (e.g. `@HELM status/help/init/retire/add lifeline`). It must (a) not require an
   @-mention at all in HELM's own channels, and (b) match the configured agent name, not "helm".

## Required behavior
- In HELM's dedicated channels, a plain message with no @-mention is routed to the agent.
- Command verbs (status, help, init, retire, add lifeline, deferred) work with OR without an
  @-prefix, and on the user's actual bot name — never the literal "helm".
- No user-facing string renders raw `${AGENT_NAME}` or a hardcoded "HELM"/"@HELM".

## Success criteria (must be tested, not asserted)
- `grep -rn '@\${AGENT_NAME}' bot.js` returns 0 raw single-quoted literals.
- `grep -rin '"helm"' bot.js` shows no command-parser branch keyed to the literal "helm".
- Manual/synthetic test: a plain non-@ message in a HELM channel triggers a response; a
  `status` command with no @ returns status. Paste the literal output in DELIVER.
- Prevention: add a test or assertion that fails if a user-facing template emits a literal
  `${` or a hardcoded bot name.
