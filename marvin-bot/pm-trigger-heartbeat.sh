#!/bin/bash
# Writes pm-trigger.json for the 2AM daily heartbeat.
# Called by com.pap.pm.heartbeat launchd job.
echo "{\"trigger\":\"heartbeat\",\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" > /Users/{{USER_HOME}}/helm-workspace/pm-trigger.json
