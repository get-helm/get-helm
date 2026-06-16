# Agent-Sleep Vulnerability Scan — 2026-06-09

Deep scan of bot.js (6,556 lines) + 19 watchdog/lifecycle scripts for remaining
vulnerability classes that make an agent appear to "fall asleep" (silence, stuck
turn, false-dead alert, duplicate spawn). Excludes the 3 already-fixed root causes
(staged-file re-post, false 2-min watchdog kill, ✅-prefix detection) and the
queued items (pre-spawn hard gate, orchestrate.sh + step ledger, one-live-agent guard).

## VERIFIED FINDINGS (code read-back confirmed)

### V1 — HIGH: Watchdog restart storm (selfheal + failover overlap)
- helm-selfheal.sh and helm-failover.sh BOTH run every 30s via launchd, BOTH fire
  at 60s heartbeat staleness, with SEPARATE cooldown files
  (/tmp/helm-selfheal-last-trigger vs /tmp/helm-failover-last-trigger) and
  different cooldown windows (600s vs 120s).
- Failure: one frozen-heartbeat event → both fire safe-restart concurrently →
  double kill → launchd respawn races → working agents killed, duplicate spawns.
  Failover can re-fire at +120s while selfheal still cooling → 3rd restart.
- Fix: single shared cooldown/lock file (flock) across ALL restart-capable
  watchdogs (selfheal, failover, auto-unstick, mac-local-watchdog), one restart
  per 120s max system-wide. Decide which script owns the 60s threshold and
  demote the other to alert-only.

### V2 — HIGH: pm-agent-trigger.json overwrite loses stalled channels
- agent-resumption.sh:69-79 loops over stalled channels and writes the SAME
  trigger file (~/helm-workspace/pm-agent-trigger.json) once per channel,
  overwriting. 3 stalled channels → only the last is resumed; the first two
  stay silent forever (the purest "fell asleep" symptom).
- Fix: append-only trigger queue (one JSON line per channel) or per-channel
  trigger files; bot.js consumes all entries.

### V3 — HIGH: VPS recovery command kills live agents with --force
- recovery-command-poll.sh:55 executes `safe-restart.sh --force` on a remote
  "restart" command. --force bypasses the in-flight-agent check AND the 90s
  grace warning. An agent mid-task is killed with no checkpoint opportunity →
  silent loss or duplicate after auto-resume.
- Fix: even under --force, if an in-flight agent has a fresh checkpoint, give a
  60s grace + checkpoint flush before kill. Reserve true-immediate kill for a
  separate --emergency flag.

### V4 — MED: extendCount cap kills live agents (bot.js:1594-1615)
- PID-alive extension (Part 2 fix) caps at 3 × 1-min extensions. An agent in one
  long blocking tool call (build, transcription, big API batch — no posts, no
  checkpoint writes) is killed at hard-ceiling + 3 min EVEN THOUGH the PID is
  alive and working. Auto-resume then redoes work → duplicate or restart-from-
  scratch appearance.
- Fix: when PID is alive, check process CPU time delta between ticks. If CPU is
  advancing, keep extending (cap ~10) and post one "long task running" notice.
  Kill only when PID alive but CPU flat for 2 consecutive ticks (true hang).

### V5 — MED: lastDeliverAt dedup state is RAM-only (bot.js:330, 4083, 6012)
- The 30s DELIVER dedup map dies on restart. Restart mid-dispatch → dedup window
  lost → duplicate DELIVER possible right after any restart (exactly when
  duplicates already cluster).
- Fix: persist lastDeliverAt into channel-state JSON (already read/written per
  message), restore on startup.

### V6 — MED: header-match dedup can suppress a legitimate new DELIVER
- discord-post.sh dedup gate: same first-100-chars within 10 min = suppressed.
  Two similar tasks back-to-back (common: "Another example" follow-ups) with
  template-style openings → second real answer silently dropped → channel looks
  asleep.
- Fix: include the triggering user-message ID (or checkpoint requestText hash)
  in the dedup key so only true re-posts of the SAME turn are suppressed.

### V7 — MED: non-atomic channel-state writes → JSON corruption → channel invisible to recovery
- discord-post.sh and several scripts do multiple sequential inline-python writes
  to channel-state/*.json with errors suppressed (2>/dev/null). A kill mid-write
  leaves partial JSON. auto-unstick.sh and agent-resumption.sh silently skip
  unparseable files → that channel is never recovered, stuck forever.
- Fix: atomic writes everywhere (write .tmp then mv), plus recovery scanners
  should LOG + quarantine corrupt state files instead of skipping silently.

## UNVERIFIED (from scan agents — engineer should confirm before fixing)

- U1 (MED) bot.js post-exit watchdog can enqueue auto-resume while a fresh user
  message is also spawning → concurrent agents on same channel. (Partially
  mitigated by activeChannelAgents check at bot.js:1625 — verify the post-exit
  path uses the same guard.)
- U2 (MED) nightly-restart.sh marks its done-flag BEFORE safe-restart succeeds —
  a failed 2am restart isn't retried for 24h.
- U3 (LOW) pmTriggerProcessing boolean can wedge true forever if a PM spawn
  hangs → PM never fires again until restart.
- U4 (LOW) recentMessageIds dedup map is RAM-only → re-sent user message right
  after restart can double-spawn.
- U5 (LOW) startup recovery doesn't scan post-queue/ for staged-but-undispatched
  DELIVERs → work completed pre-restart can be lost.

## FALSE CLAIMS CAUGHT DURING VERIFICATION (do not build)
- "agent-resumption.sh has no deliver-phase check" — FALSE (lines 52-55 skip
  deliver/block).
- "bot.js only writes heartbeat on agent spawn" — FALSE (every 15s, line 2539).
- "silence watchdog has no PID-alive check" — FALSE (line 1597, shipped as
  Part 2). The real residual gap is the extension cap (V4).

## QUEUED
- AGENT-SLEEP-HARDENING-001 (HIGH): V1, V2, V3 + verify/fix U1, U2.
- AGENT-SLEEP-HARDENING-002 (MED): V4, V5, V6, V7 + verify U3-U5.
