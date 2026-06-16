#!/bin/bash
# qmd-smoke-test.sh — Validate QMD second-brain search quality
# Runs pre-set test queries against the second-brain collection
# Results posted to pap-audit and printed to stdout
#
# Usage: bash ~/marvin-bot/qmd-smoke-test.sh
#
# Test definitions live in ~/.local/share/qmd/smoke-tests.json
# {{USER_JERRY}} can add curveball queries there without touching this script.

set -euo pipefail

PAP_AUDIT_CH="{{USER_CHANNEL_HELM_AUDIT}}"
TEST_FILE="${HOME}/.local/share/qmd/smoke-tests.json"
ENV_FILE="${HOME}/marvin-bot/.env"

# Load Discord token for pap-audit posting
DISCORD_BOT_TOKEN=$(grep '^DISCORD_BOT_TOKEN=' "$ENV_FILE" 2>/dev/null | cut -d= -f2- || echo "")

post_to_audit() {
  local msg="$1"
  # Write to helm-audit.log (helm-audit channel retired per channel-consolidation directive)
  local _ts
  _ts=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  printf '[%s] [qmd-smoke-test] %s\n\n' "$_ts" "$msg" >> ~/helm-workspace/system/helm-audit.log 2>/dev/null || true
}

# Create default test file if it doesn't exist
SMOKE_DIR=$(dirname "$TEST_FILE")
mkdir -p "$SMOKE_DIR"
if [ ! -f "$TEST_FILE" ]; then
  cat > "$TEST_FILE" << 'EOF'
{
  "tests": [
    {"query": "PAP bot restart Discord", "expect": "bot|marvin|restart|discord", "description": "Core PAP infrastructure content"},
    {"query": "ETF tracker expense ratio", "expect": "etf|tracker|expense|fund", "description": "ETF tracker workspace content"},
    {"query": "options helper scanner roll", "expect": "option|scanner|roll|position", "description": "Options helper workspace content"},
    {"query": "BML loop assumption test", "expect": "loop|assumption|test|build|measure|learn", "description": "BML methodology content"},
    {"query": "workspace channel curiosity scaffolder", "expect": "workspace|channel|scaffold|agent", "description": "PAP agent architecture content"},
    {"query": "financial review Monarch balance", "expect": "monarch|balance|account|financial", "description": "Financial review workspace content"},
    {"query": "Japan trip travel planning", "expect": "japan|travel|trip|itinerary|hotel", "description": "Japan workspace content"},
    {"query": "second brain QMD search index", "expect": "second.brain|qmd|search|index|knowledge", "description": "Second brain system content"},
    {"query": "pap-audit channel logging decisions", "expect": "audit|log|decision|channel", "description": "Audit trail content"},
    {"query": "Claude API haiku sonnet model", "expect": "claude|haiku|sonnet|model|api|anthropic", "description": "Claude API content"}
  ]
}
EOF
  echo "[smoke-test] Created default test file at $TEST_FILE"
fi

echo "═══════════════════════════════════════════════════════════"
echo "QMD Second Brain — Smoke Test"
echo "Started: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "Test file: $TEST_FILE"
echo "═══════════════════════════════════════════════════════════"

# Load tests
TESTS=$(python3 -c "import json,sys; d=json.load(open('$TEST_FILE')); print(json.dumps(d.get('tests',[])))" 2>/dev/null)
if [ -z "$TESTS" ] || [ "$TESTS" = "null" ] || [ "$TESTS" = "[]" ]; then
  echo "ERROR: No tests found in $TEST_FILE"
  post_to_audit "❌ qmd-smoke-test: No tests found in $TEST_FILE"
  exit 1
fi

TEST_COUNT=$(python3 -c "import json,sys; print(len(json.loads(sys.argv[1])))" "$TESTS")
echo "Running $TEST_COUNT tests..."
echo ""

PASS=0
FAIL=0
RESULTS=""

python3 << PYEOF
import json, subprocess, re, sys

tests = json.loads('''$TESTS''')
pass_count = 0
fail_count = 0
results = []

for i, t in enumerate(tests, 1):
    query = t.get("query", "")
    expect_pat = t.get("expect", "")
    desc = t.get("description", "")

    print(f"Test {i}/{len(tests)}: {desc}")
    print(f"  Query: {query!r}")

    try:
        r = subprocess.run(
            ["qmd", "search", query, "--collection", "second-brain"],
            capture_output=True, text=True, timeout=30
        )
        output = r.stdout.strip()

        if not output or "No results found" in output:
            status = "FAIL"
            reason = "No results returned"
            fail_count += 1
        else:
            # Check if any expected pattern matches the output (case insensitive)
            patterns = expect_pat.split("|")
            matched = [p for p in patterns if re.search(p, output, re.IGNORECASE)]
            if matched:
                status = "PASS"
                reason = f"Matched: {matched[0]!r}"
                pass_count += 1
                # Show first line of result
                first_result_line = output.split("Title:")[-1][:80].strip() if "Title:" in output else output[:80].strip()
                reason += f" — '{first_result_line}...'"
            else:
                status = "FAIL"
                reason = f"Output missing expected patterns: {expect_pat}"
                fail_count += 1
    except subprocess.TimeoutExpired:
        status = "FAIL"
        reason = "Search timed out (>30s)"
        fail_count += 1
    except Exception as e:
        status = "FAIL"
        reason = f"Error: {e}"
        fail_count += 1

    indicator = "✅" if status == "PASS" else "❌"
    print(f"  {indicator} {status}: {reason}")
    results.append({"test": i, "status": status, "query": query, "reason": reason})

print()
print("─" * 60)
print(f"Results: {pass_count}/{len(tests)} PASS")
print(f"         {fail_count}/{len(tests)} FAIL")

# Write summary for bash to pick up
with open("/tmp/qmd-smoke-results.json", "w") as f:
    json.dump({"pass": pass_count, "fail": fail_count, "total": len(tests), "results": results}, f)

PYEOF

# Read results
SUMMARY=$(python3 -c "
import json
d=json.load(open('/tmp/qmd-smoke-results.json'))
p=d['pass']; fa=d['fail']; t=d['total']
status='✅' if fa==0 else ('⚠️' if p>=t//2 else '❌')
print(f'{status} qmd-smoke-test: {p}/{t} PASS — second-brain collection')
" 2>/dev/null || echo "⚠️ qmd-smoke-test: results unavailable")

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "$SUMMARY"
echo "═══════════════════════════════════════════════════════════"

# Post to pap-audit
post_to_audit "$SUMMARY"

echo ""
echo "Full test file for {{USER_JERRY}}'s custom queries: $TEST_FILE"
echo "Add entries with: {\"query\": \"your query\", \"expect\": \"pattern\", \"description\": \"what it tests\"}"
