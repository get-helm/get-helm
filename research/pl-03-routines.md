# PL-03: Claude Code Routines Feasibility for PAP Scheduled Jobs
## Researched: 2026-05-23 (Session 91)
## Verdict: NOT FEASIBLE as launchd replacement

---

## What was evaluated

Claude Code provides two scheduling mechanisms:

### Option A: RemoteTrigger API (cloud-side)
Calls `claude.ai/v1/code/triggers` — creates agents that run on Anthropic's cloud infrastructure.
No Mac Mini involvement. Tested: current account has 0 existing remote triggers.

### Option B: CronCreate (local, session-bound)
Fires a prompt inside the active Claude Code REPL on a cron schedule.
With `durable: true`, persists to `.claude/scheduled_tasks.json` across Claude Code restarts.
Without a persistent REPL running on Mac Mini, jobs don't fire.

---

## Research questions and answers

### 1. Does it support Discord webhook calls as output?
**Option A (cloud):** NO. Remote cloud agents have no access to `~/marvin-bot/discord-post.sh`.
They could call Discord's REST API directly, but would need the bot token embedded as a secret in
the Routine payload — no mechanism exists to inject it from PAP Vault.

**Option B (local CronCreate):** YES. Runs on Mac Mini, can call `discord-post.sh` normally.

### 2. Can Routines access PAP Vault (1Password service account)?
**Option A (cloud):** NO. The 1Password service account token is in `~/.zshrc` on Mac Mini.
Remote agents have no filesystem access. They'd need credentials passed at creation time, which
is a security anti-pattern and not supported by the API.

**Option B (local CronCreate):** YES. Mac Mini environment includes the 1Password service
account token. `op item get` works normally.

### 3. Cost model — per-run, per-token, or subscription-included?
**Both options:** Token costs are normal Claude model rates. No separate per-run fee.
Runs count toward the same usage bucket as interactive Claude Code sessions.
Routines run Sonnet/Opus/Haiku depending on the prompt configuration — same rates.

### 4. Can Routines read/write to ~/pap-workspace/?
**Option A (cloud):** NO. Cloud agents have no access to Mac Mini filesystem. The entire
PAP state layer (channel-state/*.json, event-stream.jsonl, engineer-queue.md, CAPABILITIES.md)
is inaccessible.

**Option B (local CronCreate):** YES. Full filesystem access, but ONLY while a Claude Code
REPL is open and idle on Mac Mini. PAP does not maintain a persistent REPL — it uses
`claude -p` subprocess invocations from bot.js. CronCreate jobs would never fire in the
current PAP architecture because there's no persistent REPL process to host them.

### 5. Rate limits on invocation frequency?
**Option A (cloud):** Subject to claude.ai API rate limits (not published).
Steward at 6h intervals would be within any reasonable limit.

**Option B (local CronCreate):** No PAP-specific rate limits. Bound by Mac Mini resources.

### 6. Auth mechanism for posting to Discord?
**Option A (cloud):** Bot token would need to be hardcoded in the Routine payload or passed
via environment — neither is supported by PAP Vault. Not viable.

**Option B (local CronCreate):** Reads `DISCORD_BOT_TOKEN` from `~/marvin-bot/.env` as normal.

---

## Why launchd outperforms both options for PAP's use case

PAP's current architecture: `launchd plist → trigger script → writes trigger.json → bot.js reads file → spawns claude -p`

This architecture:
- Fires reliably without a persistent REPL
- Has full filesystem and credential access
- Integrates with bot.js channel state, ACK/UPDATE/DELIVER protocol, concurrency locks
- Is testable (check plist, check trigger file, check marvin.log)
- Has a VPS fallback via Tailscale SSH (already built — pap-fallback-trigger.sh)

CronCreate (Option B) would require:
- Keeping a Claude Code REPL open permanently on Mac Mini
- Managing the 7-day auto-expiry of recurring jobs
- Losing the bot.js channel state integration
- Losing the ACK/UPDATE/DELIVER protocol for scheduled agents

---

## Verdict: NOT FEASIBLE

**RemoteTrigger (cloud):** Blocked on filesystem access and credential injection.
Architecturally incompatible with PAP's state-file-based design.

**CronCreate (local):** Requires persistent REPL that PAP doesn't maintain.
Even if one were kept open, the 7-day expiry creates maintenance overhead.

**Recommendation:** Close PL-03. The current launchd → trigger file → bot.js chain is
more robust than either Routines option for PAP's specific requirements. The VPS fallback
cron (pap-fallback-trigger.sh) already addresses the only real gap (Mac Mini launchd failure).

**One narrow valid use case for CronCreate:** In an active engineer session, CronCreate
could schedule a wakeup check (already served by ScheduleWakeup). Not a replacement for
persistent scheduled jobs.

---

## Files referenced during research
- CronCreate tool schema (session context) — fires in active REPL
- RemoteTrigger tool schema (session context) — cloud API, no filesystem access
- Live RemoteTrigger list call — confirmed 0 existing triggers on {{USER_JERRY}}'s account
- ~/marvin-bot/engineer-nightly.sh — current launchd trigger pattern
- ~/marvin-bot/pap-fallback-trigger.sh — existing VPS fallback mechanism
