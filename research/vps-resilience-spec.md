# VPS Resilience — Architecture Decision
## PM-authored spec, 2026-05-23

### Problem
The Mac Mini is PAP's sole host. If it goes offline (power outage, hardware failure, OS freeze), PAP goes dark — no Discord responses, no cron jobs, no data fetching. There's no alerting, no failover, no recovery path.

Current single points of failure:
- Bot process crashes → watchdog restarts it (mitigated)
- Mac Mini loses power → nothing → 100% outage
- Mac Mini OS freeze → nothing → 100% outage
- Internet connectivity drops → nothing → 100% outage

### Option A: Hot standby Mac Mini
A second Mac Mini (or existing hardware) mirrors the bot.js + LaunchAgents config. When primary goes down, secondary is manually started.

- Cost: one-time hardware (~$500-600 refurb) + time to set up
- Recovery: manual ({{USER_JERRY}} starts secondary, ~5 min)
- Resilience: protects against power/OS failures but not if {{USER_JERRY}} is unavailable
- Verdict: Higher reliability than today, but not truly autonomous

### {{USER_JERRY}} design signal (2026-05-23T23:34Z)
In thread 1507037880269279432: "i thought the plan was that the mac mini was the backup."
This signals {{USER_JERRY}} may prefer VPS-as-primary (B1) with Mac Mini as backup — opposite of B2. Needs clarification from the workspace agent's thread response before spec is finalized.

### Option B: VPS as primary or secondary
Run bot.js on a Linux VPS (Hetzner CX21 ~$6/mo, Vultr, DigitalOcean). Either:
- B1: VPS as PRIMARY — move everything off Mac Mini
- B2: VPS as FAILOVER — VPS monitors Mac Mini heartbeat, takes over if silent >5 min

B1 pros: always-on, ~99.9% uptime SLA, no local hardware dependency
B1 cons: no access to local Mac Mini resources (1Password, Mac-only CLIs, file system)
B2 pros: keeps Mac Mini as primary (local resources), VPS as safety net
B2 cons: failover complexity, credentials must be on both, partial PAP capability on VPS

- Cost: ~$6-12/mo ongoing
- Recovery: automatic (B2) or hosted-service SLA (B1)
- Verdict: B2 is the right architecture — Mac Mini for capability, VPS for uptime

### Option C: ntfy + watchdog only (cheapest)
Already implemented. ntfy pings {{USER_JERRY}}'s phone if bot goes silent. {{USER_JERRY}} manually restarts.

- Cost: $0
- Recovery: manual ({{USER_JERRY}} restarts Mac Mini or SSH)
- Resilience: {{USER_JERRY}} must be reachable; no autonomous recovery
- Verdict: current state — acceptable for now, not enterprise-grade

### Recommendation
**Start with Option C (already live) + add VPS heartbeat monitor (B2 partial).**

Concrete next step: set up a $6/mo VPS that runs a simple health-check script. If the Mac Mini bot doesn't heartbeat for 10 min, the VPS sends an ntfy push to {{USER_JERRY}} AND posts a pap-improvements Discord message. This is read-only monitoring, not failover — but it closes the "PAP is down and no one knows" gap.

Full B2 failover (VPS takes over bot.js) is a Level 4 build — credentials, bot token, and all LaunchAgent logic must move or replicate to VPS. Estimated 4-6 hours engineering. Worth it only after the monitoring step proves the failure mode is real (i.e., the Mac Mini goes silent often enough to justify it).

### Decision needed from {{USER_JERRY}}
1. Is current ntfy alerting sufficient, or do you need autonomous failover?
2. If VPS monitoring: Hetzner, Vultr, or DigitalOcean preference?
3. Full B2 failover: is this worth 4-6 hours engineering now or defer to Phase 3?

### Level
- VPS monitoring: Level 2-3 (reversible, ~2 hours)
- Full B2 failover: Level 4 (new infrastructure, hard to reverse if misconfigured)
