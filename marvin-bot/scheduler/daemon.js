#!/usr/bin/env node
// daemon.js — HELM unified cross-platform scheduler
// Reads jobs.yaml, spawns each enabled job as a child process, restarts on exit.
// Usage: node scheduler/daemon.js
//
// Signal handling:
//   SIGTERM → graceful shutdown of all child processes, then exit

'use strict';

const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const yaml = require('js-yaml');

// ─── Paths ───────────────────────────────────────────────────────────────────
const JOBS_YAML = path.join(__dirname, 'jobs.yaml');
const WORKSPACE_SYSTEM = path.join(process.env.HOME, 'helm-workspace', 'system');
const PID_FILE = path.join(WORKSPACE_SYSTEM, 'scheduler.pid');
const LOG_FILE = path.join(WORKSPACE_SYSTEM, 'scheduler.log');

// ─── Backoff config ──────────────────────────────────────────────────────────
const BACKOFF_STEPS = [5000, 10000, 30000, 60000]; // ms

// ─── State ───────────────────────────────────────────────────────────────────
/** @type {Map<string, {proc: import('child_process').ChildProcess, backoffIdx: number, timer: NodeJS.Timeout|null}>} */
const running = new Map();
let shuttingDown = false;
let jobs = [];

// ─── Logging ─────────────────────────────────────────────────────────────────
function log(jobName, action, extra) {
  const ts = new Date().toISOString();
  const suffix = extra ? ` ${extra}` : '';
  const line = `[${ts}] [scheduler] job=${jobName} action=${action}${suffix}\n`;
  process.stdout.write(line);
  try {
    fs.appendFileSync(LOG_FILE, line);
  } catch (_) {
    // best-effort — if log dir isn't ready yet, don't crash
  }
}

// ─── Ensure system dir + write PID ───────────────────────────────────────────
function initPidFile() {
  try {
    fs.mkdirSync(WORKSPACE_SYSTEM, { recursive: true });
  } catch (e) {
    console.error(`[scheduler] Failed to create system dir: ${e.message}`);
    process.exit(1);
  }
  try {
    fs.writeFileSync(PID_FILE, String(process.pid), { mode: 0o644 });
  } catch (e) {
    console.error(`[scheduler] Failed to write PID file: ${e.message}`);
    process.exit(1);
  }
}

function removePidFile() {
  try { fs.unlinkSync(PID_FILE); } catch (_) {}
}

// ─── Load jobs.yaml ──────────────────────────────────────────────────────────
function loadJobs() {
  try {
    const raw = fs.readFileSync(JOBS_YAML, 'utf8');
    const doc = yaml.load(raw);
    if (!doc || !Array.isArray(doc.jobs)) {
      console.error('[scheduler] jobs.yaml must have a top-level "jobs" array');
      return [];
    }
    return doc.jobs;
  } catch (e) {
    console.error(`[scheduler] Failed to load jobs.yaml: ${e.message}`);
    return [];
  }
}

// ─── Spawn a single job ──────────────────────────────────────────────────────
function spawnJob(job) {
  if (shuttingDown) return;
  if (!job.enabled) {
    log(job.name, 'skipped', 'enabled=false');
    return;
  }

  const proc = spawn('/bin/sh', ['-c', job.command], {
    stdio: 'inherit',
    detached: false,
  });

  const state = running.get(job.name) || { proc: null, backoffIdx: 0, timer: null };
  state.proc = proc;
  state.timer = null;
  running.set(job.name, state);

  log(job.name, 'started', `pid=${proc.pid}`);

  proc.on('error', (err) => {
    log(job.name, 'error', err.message);
    scheduleRestart(job);
  });

  proc.on('exit', (code, signal) => {
    if (shuttingDown) return;
    log(job.name, 'stopped', `code=${code} signal=${signal}`);
    scheduleRestart(job);
  });
}

// ─── Schedule restart with exponential backoff ────────────────────────────────
function scheduleRestart(job) {
  if (shuttingDown) return;
  if (job.restart === 'never') {
    log(job.name, 'stopped', 'restart=never — not restarting');
    running.delete(job.name);
    return;
  }

  const state = running.get(job.name);
  if (!state) return;

  const backoffMs = BACKOFF_STEPS[Math.min(state.backoffIdx, BACKOFF_STEPS.length - 1)];
  state.backoffIdx = Math.min(state.backoffIdx + 1, BACKOFF_STEPS.length - 1);
  state.proc = null;

  log(job.name, 'restarted', `backoff=${backoffMs}ms attempt=${state.backoffIdx}`);

  state.timer = setTimeout(() => {
    if (shuttingDown) return;
    spawnJob(job);
  }, backoffMs);
}

// ─── Start all enabled jobs ───────────────────────────────────────────────────
function startJobs(newJobs) {
  // Track names for cleanup
  const newNames = new Set(newJobs.filter(j => j.enabled).map(j => j.name));

  // Stop jobs that are no longer in the config or are now disabled
  for (const [name, state] of running.entries()) {
    if (!newNames.has(name)) {
      log(name, 'stopped', 'removed from jobs.yaml or disabled');
      if (state.timer) clearTimeout(state.timer);
      if (state.proc) {
        try { state.proc.kill('SIGTERM'); } catch (_) {}
      }
      running.delete(name);
    }
  }

  // Start or continue jobs
  for (const job of newJobs) {
    if (!job.enabled) continue;
    if (!running.has(job.name) || !running.get(job.name).proc) {
      // Not currently running — spawn it (reset backoff on intentional reload)
      if (!running.has(job.name)) {
        running.set(job.name, { proc: null, backoffIdx: 0, timer: null });
      }
      spawnJob(job);
    }
    // If already running, leave it alone
  }
}

// ─── Watch jobs.yaml for changes ─────────────────────────────────────────────
let reloadTimer = null;

function watchJobsFile() {
  try {
    fs.watch(JOBS_YAML, { persistent: false }, (eventType) => {
      if (eventType !== 'change' && eventType !== 'rename') return;
      // Debounce: reload at most once per 2s, within 60s window
      if (reloadTimer) return;
      reloadTimer = setTimeout(() => {
        reloadTimer = null;
        log('scheduler', 'reload', 'jobs.yaml changed — reloading');
        jobs = loadJobs();
        startJobs(jobs);
      }, 2000);
    });
    log('scheduler', 'started', `watching ${JOBS_YAML}`);
  } catch (e) {
    console.error(`[scheduler] Could not watch jobs.yaml: ${e.message}`);
  }
}

// ─── Graceful shutdown ────────────────────────────────────────────────────────
function shutdown(signal) {
  if (shuttingDown) return;
  shuttingDown = true;
  log('scheduler', 'stopped', `signal=${signal} — shutting down all jobs`);

  for (const [name, state] of running.entries()) {
    if (state.timer) clearTimeout(state.timer);
    if (state.proc) {
      log(name, 'stopped', 'SIGTERM from scheduler shutdown');
      try { state.proc.kill('SIGTERM'); } catch (_) {}
    }
  }

  // Give children 5s to exit, then hard exit
  setTimeout(() => {
    removePidFile();
    process.exit(0);
  }, 5000);
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT',  () => shutdown('SIGINT'));

// ─── Main ─────────────────────────────────────────────────────────────────────
(function main() {
  initPidFile();
  log('scheduler', 'started', `pid=${process.pid} jobs=${JOBS_YAML}`);

  jobs = loadJobs();
  if (jobs.length === 0) {
    console.error('[scheduler] No jobs loaded — check jobs.yaml');
  }

  startJobs(jobs);
  watchJobsFile();
})();
