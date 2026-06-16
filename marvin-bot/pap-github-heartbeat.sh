#!/usr/bin/env bash
# Posts a repository_dispatch heartbeat to GitHub every 10 min.
# GitHub Actions health-check.yml monitors for silence and alerts Discord.
GITHUB_PAT=$(grep GITHUB_PAT /Users/{{USER_HOME}}/marvin-bot/.env | cut -d= -f2)
result=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST \
  -H "Authorization: token $GITHUB_PAT" \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Content-Type: application/json" \
  -d '{"event_type": "mac-mini-heartbeat"}' \
  "https://api.github.com/repos/{{USER_GITHUB}}/pap-config/dispatches")
echo "$result [$(date -u +%Y-%m-%dT%H:%M:%SZ)]" >> /Users/{{USER_HOME}}/marvin-bot/github-heartbeat.log
