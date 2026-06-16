#!/bin/bash
# Grilling loop utility — shared checkpoint/output logic for Grill Me pattern
# Not executed directly by agents (agents are LLM-driven). This is a reference
# specification and a standalone runner for testing the checkpoint format.
#
# Domains: discovery (curiosity.md Phase 2.5), pm_backlog (pm-jobs.md T2-B),
#          workspace_phase_a (workspace CLAUDE.md PRE-PHASE-A gate)
#
# Usage (testing): bash grilling-loop.sh <domain> <context> <channel_id>

DOMAIN="${1:-discovery}"
CONTEXT="${2:-test-topic}"
CHANNEL_ID="${3:-0}"
CHANNEL_STATE_DIR="$HOME/pap-workspace/channel-state"
BRAINSTORMS_DIR="$HOME/pap-workspace/brainstorms"
SPECS_DIR="$HOME/helm-workspace/specs"

# --- Checkpoint read/write ---

checkpoint_read() {
    local file="$CHANNEL_STATE_DIR/${CHANNEL_ID}.json"
    if [[ -f "$file" ]]; then
        python3 -c "
import json, sys
d = json.load(open('$file'))
gm = d.get('grill_me_checkpoint', {})
print(json.dumps(gm))
"
    else
        echo "{}"
    fi
}

checkpoint_write() {
    local domain="$1" context="$2" q_answered="$3" total="$4" answers_json="$5"
    local file="$CHANNEL_STATE_DIR/${CHANNEL_ID}.json"
    python3 -c "
import json, time, os
f = '$file'
d = json.load(open(f)) if os.path.exists(f) else {'channelId': '$CHANNEL_ID'}
d['grill_me_checkpoint'] = {
    'domain': '$domain',
    'context': '$context',
    'questions_answered': $q_answered,
    'total_questions': $total,
    'answers': $answers_json,
    'ts_last_updated': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
}
open(f, 'w').write(json.dumps(d, indent=2))
print('checkpoint written: Q%d/%d' % ($q_answered, $total))
"
}

checkpoint_clear() {
    local file="$CHANNEL_STATE_DIR/${CHANNEL_ID}.json"
    python3 -c "
import json, os
f = '$file'
if os.path.exists(f):
    d = json.load(open(f))
    d.pop('grill_me_checkpoint', None)
    open(f, 'w').write(json.dumps(d, indent=2))
    print('checkpoint cleared')
"
}

# --- Output builders ---

build_brainstorm_output() {
    local topic="$1" answers_json="$2"
    local slug=$(echo "$topic" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')
    local outfile="$BRAINSTORMS_DIR/${slug}.md"
    mkdir -p "$BRAINSTORMS_DIR"
    python3 -c "
import json, time, sys
answers = $answers_json
slug = '$slug'
topic = '$topic'
ts = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
out = '''---
topic: {topic}
created_at: {ts}
discovery_phase: complete
---

## Problem Statement
{q1}

## Desired Outcome
{q2}

## Constraints & Timeline
{q3}

## Success Criteria
{q4}

## Edge Cases & Out-of-Scope
{q5}

## Key Highlights
[Extract 3-5 key insights from the above answers]
'''.format(
    topic=topic, ts=ts,
    q1=answers.get('q1_workflow', '[not answered]'),
    q2=answers.get('q2_success', '[not answered]'),
    q3=answers.get('q3_constraints', '[not answered]'),
    q4=answers.get('q4_integration', '[not answered]'),
    q5=answers.get('q5_stakes', '[not answered]')
)
open('$outfile', 'w').write(out)
print('brainstorm written: $outfile')
"
}

build_spec_output() {
    local item_id="$1" answers_json="$2"
    local outfile="$SPECS_DIR/${item_id}-grilled-spec.md"
    python3 -c "
import json, time
answers = $answers_json
ts = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
out = '''---
item_id: $item_id
grilled_at: {ts}
---

## Workflow Context
{q1}

## Success Signal
{q2}

## Constraints
{q3}

## Integration Points
{q4}

## Stakes & Timeline
{q5}
'''.format(
    ts=ts,
    q1=answers.get('q1_workflow', '[not answered]'),
    q2=answers.get('q2_success', '[not answered]'),
    q3=answers.get('q3_constraints', '[not answered]'),
    q4=answers.get('q4_integration', '[not answered]'),
    q5=answers.get('q5_stakes', '[not answered]')
)
open('$outfile', 'w').write(out)
print('spec written: $outfile')
"
}

# --- Status report ---

echo "Grilling loop utility — domain=$DOMAIN context=$CONTEXT channel=$CHANNEL_ID"
echo "Checkpoint: $(checkpoint_read)"
echo ""
echo "Output directories:"
echo "  brainstorms: $BRAINSTORMS_DIR"
echo "  specs: $SPECS_DIR"
echo ""
echo "Functions available: checkpoint_read, checkpoint_write, checkpoint_clear,"
echo "  build_brainstorm_output, build_spec_output"
