# {{USER_JERRY}} Feedback — 2026-06-12 — Spec Reviews (P5.1/P5.2/P5.3/P5.4 + Recovery)
Source: Discord thread {{USER_CHANNEL_BETA_USERS}}, message.txt attachment

## P5.1 — APPROVED
- All 3 thread changes APPROVED: (1) two-stage permissions (Admin first, specific-scopes fallback), (2) optional GitHub/domain/email with consequences on Skip, (3) optional isolated QMD setup step.
- ACTION: update canon at {{USER_GITHUB}}/helm-config/specs/P5.1-ONBOARDING-FLOW.md

## P5.3 — Workspace Dashboard
1. SCRAP "Current phase (A/B/C/D)" nomenclature — {{USER_JERRY}} never adopted it, doesn't apply consistently to workspaces. Remove from spec.
2. Don't over-rely on "loop completion" — real workspaces start with assumptions/BML then shift to prototyping + directed user updates. Capture those too. Proposal: update pinned dashboard at end of every turn (every DELIVER).
3. Add a link/way for user to see current backlog/queue state ("task-ledger").
4. "Safety Refresh (PM Agent)" — approved, keep.
5. Output links: must live on user's drive (OneDrive/GoogleDrive/whatever they use) or user's GitHub — NOT local file paths.
6. "Loop notes: [link to workspace learnings.md]" — invalid; can't link local files on a clean machine. Must be drive/GitHub link.
7. "https://[workspace].{{USER_DOMAIN}}" — single-user assumption violation. If user has VPS/domain → preferred; if not → need fallback (define one).

## P5.4 — Preferences Channel
1. "The 10 Core Preferences" — source unclear; P5.1 has more, conversations have more. ACTION: review second brain for all preference discussions. Must include at minimum: tone, style, palette, timezone, date/time formats, and more.
2. Preferences should be a PINNED message always visible — not an on-request display.

## P5.2 — Help System
1. No "@HELM" prefix — users speak plain language.
2. Search targets: add second brain (QMD).
3. "Creating Automations" guide → should be "new workspaces". Same for automation triggers — those happen in the workspace.
4. "Bot not responding" guide → must include all latest from the recovery thread.
5. Help channel = existing #troubleshooting (1510783493477498993) only — no new #help channel. AND most help questions should be answerable from ANY channel/thread, not routed to #troubleshooting.
6. Conversational should be FIRST FALLBACK after search (not eliminated).

## Recovery — Lifeline Bot (NEW REQUIREMENT)
- Recovery needs a second, backup bot ("Lifeline bot") created at the same time as the main bot.
- Onboarding: new users create TWO Discord bots from the start (Main HELM + Lifeline).
- Onboarding docs need exact step-by-step: Discord Developer Portal → screenshots per click → copy token → paste into setup wizard.
- ACTION: integrate into P5.1 onboarding flow.
