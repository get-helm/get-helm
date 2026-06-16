# HELM QA Harness — Phase 6 Approach
# Status: Stages 1-2 built; Stage 3 (VM) documented below

## Stages

### Stage 1: Install Smoke Tests (BUILT)
**Script:** `~/marvin-bot/test-helm-install-smoke.sh`
**Tests:** T1-T9 — OS detection, wizard skip, helm-workspace creation, HELM_HOME env, Node version, npm install, helm-init.sh permissions, bot.js syntax, required files
**Run time:** ~30 seconds
**Safe to run on:** {{USER_JERRY}}'s machine (non-destructive, reads only)

### Stage 2: Failure Injection (BUILT)
**Script:** `~/marvin-bot/test-helm-failure-inject.sh`
**Tests:** F1-F6 — Missing Node, old Node, bad git URL, missing Discord token, missing .env, existing HELM_HOME update path
**Run time:** ~60 seconds
**Safe to run on:** {{USER_JERRY}}'s machine (uses /tmp sandbox, no prod changes)

### Stage 3: VM / Cross-Platform Harness (APPROACH DOCUMENTED — NOT YET BUILT)

#### Option A: GitHub Actions (Approved, cheapest)
Use `.github/workflows/xplat-ci.yml` (already built — commit 4b93e9f) to run install smoke + failure tests on all three platforms in CI:
- `macos-latest` — full install.sh run with HELM_SKIP_WIZARD=1
- `ubuntu-latest` — systemd unit lint + install smoke
- `windows-latest` — PowerShell AST check + install.ps1 dry-run

**To add Stage 1-2 to CI:**
```yaml
# In .github/workflows/xplat-ci.yml, add to each job:
- name: Run smoke tests
  run: bash marvin-bot/test-helm-install-smoke.sh
- name: Run failure injection
  run: bash marvin-bot/test-helm-failure-inject.sh
```

#### Option B: UTM VM (macOS local, free)
- Install UTM: `brew install utm`
- Create Ubuntu 22.04 ARM VM (3GB RAM, 20GB disk)
- Snapshot before test: `UTM snapshot before-helm-test`
- Run: `bash install.sh` — verify end-to-end wizard flow
- Restore: `UTM snapshot restore before-helm-test`

**Caution:** VM harness requires 1-2h setup and 30-45 min per test run. Use only for final release validation.

#### Option C: Docker container (fastest iteration)
```bash
docker run --rm -it ubuntu:22.04 bash -c "
  apt-get update -qq && apt-get install -y curl git sudo &&
  useradd -m -s /bin/bash helm && su -c 'bash <(curl -fsSL https://raw.githubusercontent.com/{{USER_GITHUB}}/marvin-bot/main/install.sh)' helm
"
```
Tests the Linux path without a full VM. Wizard will fail at Discord token prompt (expected).

## Tour Simulation (Stage 4 — future)

A "tour simulation" would:
1. Run helm-init.sh in `--tour` mode (not yet implemented)
2. Simulate user inputs via `expect` script
3. Verify each step of the wizard completes correctly

**Implementation path:** Add `HELM_TOUR_MODE=1` to helm-init.sh that uses pre-set answers.
**Estimate:** 120m

## Failure Injection — Known Gaps

These failure scenarios are NOT yet tested and represent risk for new users:
- VPS SSH connection timeout (helm-init.sh Step 6)
- Discord bot token with wrong permissions (no access to create channels)
- npm install failure due to network timeout
- helm-init.sh interrupted mid-wizard (partial setup recovery)

## Running the Full Harness

```bash
# Stage 1: Quick smoke (30s)
bash ~/marvin-bot/test-helm-install-smoke.sh

# Stage 2: Failure injection (60s)
bash ~/marvin-bot/test-helm-failure-inject.sh

# Both — good for pre-release check:
bash ~/marvin-bot/test-helm-install-smoke.sh && bash ~/marvin-bot/test-helm-failure-inject.sh
```

Exit 0 = all tests passed. Non-zero = failures (see stdout for details).
Results are logged to `~/helm-workspace/system/helm-audit.log`.
