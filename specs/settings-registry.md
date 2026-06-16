# PAP Settings Registry
## Purpose: Catalog every configurable behavior in PAP agents and infrastructure
## Last updated: 2026-05-25 (Session 119)
## Classification: (A) Product decision — hardwired; (B) User preference — per-user, surfaceable in onboarding

---

## SECTION 1 — Voice & Communication Style
*Source: ~/pap-workspace/VOICE-AND-STYLE.md (user-written) + curiosity.md onboarding*

| Setting | Source File | Class | Current Default/Value | In USER-PROFILE.md? | In Onboarding? |
|---|---|---|---|---|---|
| Preferred tone | VOICE-AND-STYLE.md | B | "Conversational and brief. Like a capable assistant." | Yes | Yes (curiosity.md asks formality Q) |
| Response length preference | VOICE-AND-STYLE.md | B | "Short. Mobile-first. 30s max read time." | Yes | Yes (curiosity.md asks verbosity Q) |
| Information style | VOICE-AND-STYLE.md | B | "Decision-first. Lead with what {{USER_JERRY}} needs to act on." | Yes | Yes (curiosity.md asks info style Q) |
| Display mode | VOICE-AND-STYLE.md | B | dark | Yes | Not yet in onboarding flow |
| Color palette — primary | VOICE-AND-STYLE.md | B | #4A7C59 (Palette Olive-4) | Yes | Not yet in onboarding flow |
| Color palette — accent 1 | VOICE-AND-STYLE.md | B | #7C3AED | Yes | Not yet in onboarding flow |
| Color palette — accent 2 | VOICE-AND-STYLE.md | B | #D97706 | Yes | Not yet in onboarding flow |
| Communication filter | VOICE-AND-STYLE.md (COMMUNICATION_FILTER) | B | "so what?" filter — silent/decision/inform buckets | Yes | Yes (curiosity.md asks activity style Q) |
| Notification preferences | VOICE-AND-STYLE.md | B | Failures: 1-2 sentences. Success: 1-2 sentences. | Yes | Not yet in onboarding flow |
| Standing preferences | VOICE-AND-STYLE.md | B | No code blocks in status. Number all lists. Lead with action. | Yes | Not yet in onboarding flow |

---

## SECTION 2 — Model Routing
*Source: CLAUDE.md (root workspace)*

| Setting | Source File | Class | Current Default/Value | In USER-PROFILE.md? | In Onboarding? |
|---|---|---|---|---|---|
| Default agent model | CLAUDE.md | A | Sonnet (judgment, writing, workspace work) | No | No |
| Routing/validation model | CLAUDE.md | A | Haiku (status checks, log writes, routing) | No | No |
| Opus trigger | CLAUDE.md | A | Only when user signals "big decision" — return to Sonnet after | No | No |

Agent-level model overrides (hardwired per agent, not user-configurable):

| Agent | Model | Source |
|---|---|---|
| connector | claude-haiku-4-5-20251001 | connector.md frontmatter |
| cost-monitor | claude-haiku-4-5-20251001 | cost-monitor.md frontmatter |
| curiosity | claude-sonnet-4-6 | curiosity.md frontmatter |
| dispatcher | claude-haiku-4-5-20251001 | dispatcher.md frontmatter |
| etf-data-agent | claude-haiku-4-5-20251001 | etf-data-agent.md frontmatter |
| executor | claude-haiku-4-5-20251001 | executor.md frontmatter |
| financial-data-agent | claude-haiku-4-5-20251001 | financial-data-agent.md frontmatter |
| help | claude-sonnet-4-6 | help.md frontmatter |
| monarch-data-agent | claude-haiku-4-5-20251001 | monarch-data-agent.md frontmatter |
| performance-monitor | claude-haiku-4-5-20251001 | performance-monitor.md frontmatter |
| scaffolder | claude-haiku-4-5-20251001 | scaffolder.md frontmatter |
| security | claude-haiku-4-5-20251001 | security.md frontmatter |
| steward | claude-sonnet-4-6 | steward.md frontmatter |
| synthesizer | claude-sonnet-4-6 | synthesizer.md frontmatter |
| validator | claude-haiku-4-5-20251001 | validator.md frontmatter |
| engineer | (no frontmatter — CLI default) | — |
| product-manager | (no frontmatter — CLI default) | — |

---

## SECTION 3 — Silence Watchdog & Timeout Thresholds
*Source: bot.js constants*

| Setting | Source File | Class | Current Default/Value | In USER-PROFILE.md? | In Onboarding? |
|---|---|---|---|---|---|
| Default silence cadence (when agent doesn't declare) | bot.js line ~1212 | A | 90 seconds | No | No |
| Cadence multiplier — standard channels | bot.js line ~1244 | A | ×3 (warn at 2×cadence, kill at 3×cadence) | No | No |
| Cadence multiplier — medium timeout channels (#general, #pap-audit) | bot.js line ~1244 | A | ×6 | No | No |
| Cadence multiplier — long timeout channels (#etf-tracker, #options-helper) | bot.js line ~1244 | A | ×10 | No | No |
| Cold-start warn window | bot.js line ~1218 | A | 5 minutes (before first post) | No | No |
| ACK warn threshold | bot.js line ~1357 | A | 45 seconds after spawn | No | No |
| ACK kill threshold | bot.js line ~1365 | A | 90 seconds after spawn | No | No |
| Post-exit-watchdog check interval | bot.js CONST | A | Every 2 min | No | No |
| Post-exit auto-resume delay | bot.js CONST | A | 5 min after exit before resuming | No | No |
| Max auto-resume attempts | bot.js line ~1260 | A | 4 attempts before giving up | No | No |

---

## SECTION 4 — Concurrency & Parallelism
*Source: bot.js constants*

| Setting | Source File | Class | Current Default/Value | In USER-PROFILE.md? | In Onboarding? |
|---|---|---|---|---|---|
| Max concurrent Claude subprocesses (global) | bot.js MAX_CONCURRENT_CLAUDE | A | 2 | No | No |
| Max parallel agents per conversational channel | bot.js MAX_PARALLEL_AGENTS | A | 3 | No | No |
| Parallel threading eligible agents | bot.js supportsParallel() | A | help, curiosity (engineer excluded) | No | No |

---

## SECTION 5 — Scheduled Jobs & Cron Cadences
*Source: ~/Library/LaunchAgents/, bot.js*

| Setting | Source File | Class | Current Default/Value | In USER-PROFILE.md? | In Onboarding? |
|---|---|---|---|---|---|
| PM sweep cadence | com.pap.pm.sweep.plist | A | Every 30 min (1800s) | No | No |
| Nightly restart time | com.pap.nightly-restart.plist | A | 2am PT | No | No |
| Synthesizer nightly run time | synthesizer-nightly.sh | A | Nightly at ~2am PT (after restart) | No | No |
| QMD second-brain update cadence | com.pap.second-brain-qmd-update.plist | A | Every 30 min (1800s) | No | No |
| Performance monitor cadence | bot.js CONST | A | Weekly (7 days) | No | No |
| Health watchdog quiet threshold | bot.js CONST | A | 10 minutes before ntfy alert | No | No |
| Peak hours moratorium set | com.pap.moratorium.set.plist | A | 9am PT | No | No |
| Peak hours moratorium clear | com.pap.moratorium.clear.plist | A | 10pm PT | No | No |
| VPS cron fallback — nightly restart | VPS crontab | A | 9:30 UTC (30 min after launchd) | No | No |
| VPS cron fallback — synthesizer | VPS crontab | A | 6:15 UTC | No | No |

---

## SECTION 6 — Channel Routing
*Source: CLAUDE.md (root workspace)*

| Setting | Source File | Class | Current Default/Value | In USER-PROFILE.md? | In Onboarding? |
|---|---|---|---|---|---|
| #general → intent routing | CLAUDE.md | A | Exploratory→help, Idea→curiosity, Broken→help, Ambiguous→help | No | No |
| #new-workspace routing | CLAUDE.md | A | curiosity agent | No | No |
| #capture routing | CLAUDE.md | A | connector agent (security scan first) | No | No |
| #help/#feedback/#preferences routing | CLAUDE.md | A | help agent | No | No |
| #pap-improvements routing | CLAUDE.md | A | product-manager agent | No | No |
| Workspace channel routing | CLAUDE.md | A | workspace CLAUDE.md | No | No |

---

## SECTION 7 — Web Deploy & Security
*Source: CLAUDE.md (root workspace)*

| Setting | Source File | Class | Current Default/Value | In USER-PROFILE.md? | In Onboarding? |
|---|---|---|---|---|---|
| Default web auth gate | CLAUDE.md | B | Password-protected (confirm with {{USER_JERRY}} per deploy) | No | Not yet in onboarding flow |
| etf.{{USER_DOMAIN}} auth | CLAUDE.md | B | Open ({{USER_JERRY}} approved) | No | Not yet in onboarding flow |
| options.{{USER_DOMAIN}} auth | CLAUDE.md | B | Password-protected | No | Not yet in onboarding flow |
| mockups.{{USER_DOMAIN}} auth | CLAUDE.md | B | Password-protected | No | Not yet in onboarding flow |

---

## SECTION 8 — Firecrawl / API Budget
*Source: workspaces/etf-tracker/CLAUDE.md + firecrawl-usage.json*

| Setting | Source File | Class | Current Default/Value | In USER-PROFILE.md? | In Onboarding? |
|---|---|---|---|---|---|
| Firecrawl monthly credit cap | firecrawl-usage.json (monthlyCapCredits) | B | 100 credits/month | No | Not yet in onboarding flow |
| Firecrawl large-batch gate | etf-tracker/CLAUDE.md | A | Block + user approval for batches >10 calls | No | No |
| API call batch size (all agents) | CLAUDE.md | A | ≤5 items per pass | No | No |

---

## SECTION 9 — Large Audio / Whisper
*Source: bot.js constants*

| Setting | Source File | Class | Current Default/Value | In USER-PROFILE.md? | In Onboarding? |
|---|---|---|---|---|---|
| Large audio threshold | bot.js LARGE_AUDIO_THRESHOLD_BYTES | A | 10MB — above this, use background Whisper + ScheduleWakeup | No | No |
| Inline Whisper timeout | bot.js fetchAttachments | A | 5 minutes (files ≤10MB) | No | No |

---

## SECTION 10 — Second Brain TTL
*Source: ~/pap-workspace/second-brain/TTL-FRAMEWORK.md (design locked, not yet built)*

| Setting | Source File | Class | Current Default/Value | In USER-PROFILE.md? | In Onboarding? |
|---|---|---|---|---|---|
| Article/link TTL — no highlight | TTL-FRAMEWORK.md | B | 90d→1yr→2yr→gone | No | Not yet in onboarding flow |
| Discord capture TTL — no highlight | TTL-FRAMEWORK.md | B | 30d→90d→gone | No | Not yet in onboarding flow |
| PAP decision/audit TTL | TTL-FRAMEWORK.md | A | Always PAP-tier min (2yr→5yr→10yr→gone) | No | No |
| User-tier highlight gate | TTL-FRAMEWORK.md | B | Hard gate — {{USER_JERRY}} must approve deletion | No | Not yet in onboarding flow |
| Reference boost | TTL-FRAMEWORK.md | A | Any item accessed in last 90d resets TTL clock | No | No |
| Cross-link boost threshold | TTL-FRAMEWORK.md | A | 3+ references → PAP-tier minimum | No | No |
| Email capture filter | TTL-FRAMEWORK.md | B | All @{{USER_DOMAIN}}, {{USER_GITHUB}}13@gmail.com; exclude marketing | No | Not yet in onboarding flow |

---

## SECTION 11 — Turn Protocol Behavior
*Source: turn-protocol.md*

| Setting | Source File | Class | Current Default/Value | In USER-PROFILE.md? | In Onboarding? |
|---|---|---|---|---|---|
| DELIVER schema enforcement | turn-protocol.md | A | All 4 fields required: PUSHBACK, VERIFICATION_REQUIRED, PROACTIVE_NEXT, Docs updated | No | No |
| Schema collapse for routine messages | turn-protocol.md | A | Low-stakes lookups can omit schema, use "[routine — no schema]" | No | No |
| DELIVER body word limit | turn-protocol.md | A | ≤200 words | No | No |
| PUSHBACK escalation gate | turn-protocol.md | A | Concrete PUSHBACK with alternative must be built, [CONFIRM]ed, or explicitly deferred | No | No |
| Authority scale | turn-protocol.md | A | Level 0-3 auto-execute; Level 4-5 propose + wait | No | No |
| Long-thread lightweight mode trigger | turn-protocol.md | A | >15 injected messages → lightweight mode | No | No |
| Step-count gate | turn-protocol.md | A | Post UPDATE every 5 tool calls; stop at 20 | No | No |
| Max DELIVER body word count | turn-protocol.md | B | 200 words — user can request longer | Yes | Not yet in onboarding flow |

---

## SECTION 12 — Proactivity & Challenge Behavior
*Source: turn-protocol.md, USER-PROFILE.md*

| Setting | Source File | Class | Current Default/Value | In USER-PROFILE.md? | In Onboarding? |
|---|---|---|---|---|---|
| Pushback volume | VOICE-AND-STYLE.md (PUSHBACK_VOLUME) | B | "Challenge freely, user will dial it down if needed" | Yes | Yes (curiosity.md asks pushback Q) |
| Proactive-first gate | turn-protocol.md | A | Before every response: ask "most useful thing I could do?" Level 0-3: do it. Level 4+: surface it. | No | No |
| Challenge-first gate | turn-protocol.md | A | Stress-test user premise before agreeing — mandatory | No | No |
| Proactive next — Level 0-3 threshold | turn-protocol.md | A | Act without asking permission | No | No |

---

## Summary: User Preference Settings Not Yet in Onboarding Flow

These are (B) settings that belong in an onboarding conversation but are currently only set in VOICE-AND-STYLE.md after the fact, or not surfaced at all:

1. **Display mode** (dark/light) — affects Discord embed color rendering
2. **Color palette** — 5 options available, user picks by taste
3. ~~**Communication filter level**~~ — ✅ Added to curiosity.md onboarding (COMMUNICATION_FILTER)
4. **Notification verbosity** — how much detail on success/failure
5. **Standing preferences** — formatting rules (headers, code blocks, list numbering)
6. **Default web auth gate** — open vs. password-protected per subdomain
7. **Firecrawl monthly budget** — cost tolerance (currently 100 credits)
8. **Max DELIVER body length** — default 200 words; some users may want more
9. **Second brain TTL tiers** — how aggressively to decay captured content
10. ~~**Pushback volume**~~ — ✅ Added to curiosity.md onboarding (PUSHBACK_VOLUME)
11. **Email capture filter scope** — which addresses to ingest

---
*This registry is a snapshot. Settings evolve as bot.js and agent files change.*
*Run: grep -rn "const [A-Z_]* = " ~/marvin-bot/bot.js to find new configurable constants.*
