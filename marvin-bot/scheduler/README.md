# HELM Scheduler

A cross-platform Node.js daemon that reads `jobs.yaml` and manages long-running HELM processes.

## Start the daemon

```bash
node /Users/{{USER_HOME}}/marvin-bot/scheduler/daemon.js
```

PID is written to `~/helm-workspace/system/scheduler.pid`.
Logs go to `~/helm-workspace/system/scheduler.log`.

## Stop the daemon

```bash
kill $(cat ~/helm-workspace/system/scheduler.pid)
```

## Add a job

Edit `jobs.yaml` and add an entry. The daemon reloads within 60 seconds.

```yaml
- name: my-job
  command: "bash /Users/{{USER_HOME}}/marvin-bot/my-script.sh"
  restart: always   # always | on-failure | never
  enabled: true
```

## Remove / disable a job

Set `enabled: false` or delete the entry. The daemon stops the process on next reload.

## Check logs

```bash
tail -f ~/helm-workspace/system/scheduler.log
```
