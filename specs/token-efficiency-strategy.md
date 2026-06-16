# Token Efficiency Strategy — 2026-06-09

## Baseline (from fable-usage-baseline.md, 2026-06-09)
- 474 sessions / 24h, 9.17M output tokens, 94.4% cache hit
- Bulk of burn: engineer agent — 336 background sessions (overnight queue)
- Output tokens are the cost center: ~5x input price, never cached
- Input is mostly cached (94.4%) — context-size cuts matter less than session count and output volume

## The 4 levers (ranked by impact)

### 1. Batch engineer sessions (biggest lever)
Current: one spawn per queue item → 336 sessions overnight, each paying full
injection cost (system prompt + CLAUDE.md + turn-protocol + memory ≈ 50-80K tokens).
Fix: one session processes 3-5 queue items before exiting. Est. ~70% cut in
fixed startup cost per item (unverified — needs per-session token split measurement).

### 2. Output discipline
- Edits over rewrites (Edit tool, not Write-whole-file)
- Compact checkpoints and logs (partially done — brevity rule, log rotation queued)
- DELIVER bodies: quality over length (already in protocol)

### 3. Cache preservation
- 94.4% hit rate is strong. Protect it: avoid editing always-injected files
  (CLAUDE.md, turn-protocol.md, behaviors.md, MEMORY.md) mid-day — every edit
  invalidates cache for all subsequent sessions until re-cached.
- Batch instruction-file changes; deploy at the 2am window with bot.js changes.

### 4. Tiered instruction injection
Routing/status agents (Haiku) currently load the same ~28K turn-protocol as
judgment agents. A slim protocol variant (~4K: phase markers, no-internal-paths,
checkpoint rules) for routing/validation/status agents saves ~20K × hundreds
of sessions/day. Full protocol stays for any agent that produces DELIVERs or
writes files.

## Fable policy
- Evidence: 8% of weekly cap burned in ~2h as all-channel default (2026-06-09).
- Policy: Fable via /fable only, for decisions that are expensive to get wrong:
  architecture/design sessions, post-mortems, strategy deep-dives.
- Never Fable for: routing, status checks, queue execution, validation, log writes.
- Routing remains: Haiku (routing/validation/status) → Sonnet (default work) →
  Fable (explicit /fable, judgment-heavy only).

## Multi-user application
- Ship as default config, not retrofit: model routing table, log rotation crons,
  engineer batching, tiered injection — all in the scaffold for new installs.
- Usage monitoring already multi-user-ready (OAuth usage API, per-machine login).
- Per-user budgets: reuse the existing 80%-threshold alert; thresholds in users.json.
- Each user's burn is dominated by their own background agents, not chat —
  the batching + tiering defaults are what keep a new user's weekly cap healthy.

## Quality protection rule
Cut input bloat (history, logs, duplicate context) ruthlessly.
Never cut: reasoning depth, verification gates (read-backs), claim evidence.
Measurement: friction-log violation rate per week, before/after each cut.
If violations rise after a cut → roll it back. Efficiency that raises the
violation rate is a net loss (re-work costs more than the savings).

## Value-cut candidates (beyond the 4 queued 2026-06-09)
1. Engineer one-spawn-per-item pattern (lever #1 above)
2. Full turn-protocol injection for simple agents (lever #4 above)
3. Quiet-when-normal status posts — hourly status fires 24/7 regardless of
   change; post only on state change or threshold crossing
