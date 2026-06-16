#!/usr/bin/env bash
# discord-channel-cleanup.sh
# Removes automated sweep/engineer messages from #pap-improvements.
# Keeps: user messages, [CONFIRM:]/[BUTTON:]/[SELECT:] proposals, B-09 deliveries.
# Deletes: PM sweep summaries, engineer queue announcements, T1 framework DELIVERs.
#
# Usage: bash ~/marvin-bot/discord-channel-cleanup.sh [--dry-run] [--limit N]
# --dry-run: print what would be deleted, don't actually delete
# --limit N: check last N messages (default: 500)
#
# Rate limit: Discord allows ~5 deletes/5s per channel. Script sleeps 1.2s between deletes.

set -euo pipefail

export $(grep DISCORD_BOT_TOKEN ~/marvin-bot/.env)

CHANNEL_ID="{{USER_CHANNEL_HELM_IMPROVEMENTS}}"  # #pap-improvements
BOT_ID="1498824219633647789"       # Marvin bot user ID
DRY_RUN=false
LIMIT=500

i=1
while [ "$i" -le "$#" ]; do
  arg="${!i}"
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --limit) i=$((i+1)); LIMIT="${!i:-500}" ;;
  esac
  i=$((i+1))
done

echo "🧹 Discord channel cleanup — #pap-improvements"
echo "   Mode: $([ "$DRY_RUN" = true ] && echo 'DRY RUN' || echo 'LIVE DELETE')"
echo "   Checking last $LIMIT messages"
echo ""

# Fetch messages in batches of 100, paginating backwards
python3 - <<PYEOF
import urllib.request, urllib.error, json, time, os, sys

TOKEN = os.environ['DISCORD_BOT_TOKEN']
CHANNEL = "$CHANNEL_ID"
BOT_ID = "$BOT_ID"
DRY_RUN = "$DRY_RUN" == "true"
LIMIT = int("$LIMIT")

def api(method, path, data=None):
    url = f"https://discord.com/api/v10{path}"
    req = urllib.request.Request(url, method=method)
    req.add_header("Authorization", f"Bot {TOKEN}")
    req.add_header("Content-Type", "application/json")
    req.add_header("User-Agent", "DiscordBot (https://github.com/{{USER_GITHUB}}/pap-config, 1.0)")
    if data:
        req.data = json.dumps(data).encode()
    try:
        with urllib.request.urlopen(req) as r:
            if r.status == 204:
                return None
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        if e.code == 429:
            retry = json.loads(body).get('retry_after', 2)
            print(f"  Rate limited — sleeping {retry}s")
            time.sleep(float(retry) + 0.5)
            return api(method, path, data)
        elif e.code == 404:
            return None  # message already deleted
        raise

def is_automated(msg):
    """Returns True if message should be deleted."""
    author_id = msg.get('author', {}).get('id', '')
    if author_id != BOT_ID:
        return False  # never delete user messages

    embeds = msg.get('embeds', [])
    content = (msg.get('content', '') or '').lower()
    embed_text = ' '.join([
        (e.get('description', '') or '') + ' ' + (e.get('title', '') or '')
        for e in embeds
    ]).lower()
    full_text = content + ' ' + embed_text

    # Always keep messages with UI sentinels or key decision markers
    keep_patterns = ['[confirm:', '[button:', '[select:', '[embed:', 'l4+', 'level 4', 'level 5']
    if any(p in full_text for p in keep_patterns):
        return False

    # Clear noise: engineer run announcements (not actual DELIVERs)
    noise_prefixes = [
        '🔧 engineer run starting',
        '🔧 engineer run complete',
        '🔧 engineer triggered',
        '[automated pm trigger',
    ]
    if any(full_text.startswith(p) for p in noise_prefixes):
        return True

    # PM sweep summaries (pure operational noise)
    pm_sweep_patterns = [
        'pm scheduled sweep — complete',
        'pm sweep — complete',
        '⏳ pm sweep resuming',
        'tier 1 framework complete',
        't1-a through t1-f',
        'batch 2a reads',
        'batch 2b reads',
        'no stalled agents',
    ]
    if any(p in full_text for p in pm_sweep_patterns):
        return True

    return False

# Paginate through messages
all_messages = []
before = None
fetched = 0

while fetched < LIMIT:
    batch_size = min(100, LIMIT - fetched)
    path = f"/channels/{CHANNEL}/messages?limit={batch_size}"
    if before:
        path += f"&before={before}"

    batch = api("GET", path)
    if not batch:
        break

    all_messages.extend(batch)
    fetched += len(batch)

    if len(batch) < batch_size:
        break  # no more messages

    before = batch[-1]['id']
    time.sleep(0.5)

print(f"Fetched {len(all_messages)} messages")
print()

# Identify deletions
to_delete = [m for m in all_messages if is_automated(m)]
to_keep = len(all_messages) - len(to_delete)

print(f"Would delete: {len(to_delete)} automated messages")
print(f"Would keep: {to_keep} messages")
print()

if not to_delete:
    print("Nothing to delete.")
    sys.exit(0)

# Show preview
print("Preview (first 10 to delete):")
for m in to_delete[:10]:
    embeds = m.get('embeds', [])
    preview = (embeds[0].get('description', '') if embeds else m.get('content', ''))[:80]
    print(f"  [{m['id']}] {repr(preview)}")
print()

if DRY_RUN:
    print("DRY RUN — no deletions made. Run without --dry-run to execute.")
    sys.exit(0)

# Delete
print(f"Deleting {len(to_delete)} messages (1.2s between each)...")
deleted = 0
failed = 0

for i, m in enumerate(to_delete):
    result = api("DELETE", f"/channels/{CHANNEL}/messages/{m['id']}")
    if result is None:  # 204 = success, 404 = already gone
        deleted += 1
    else:
        failed += 1

    if (i + 1) % 10 == 0:
        print(f"  Progress: {i+1}/{len(to_delete)}")

    time.sleep(1.2)  # stay under 5/5s rate limit

print()
print(f"Done: {deleted} deleted, {failed} failed")
PYEOF
