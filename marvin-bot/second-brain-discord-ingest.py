#!/usr/bin/env python3
"""
second-brain-discord-ingest.py — Loop B: Discord backfill for PAP second brain.

Architecture: Discord REST API → Claude Haiku (claude CLI) → QMD second-brain collection
Run weekly (not daily — Discord history doesn't change fast enough).
Idempotent: checkpoint file skips already-processed batches.

MCP independence: This script uses Discord REST API directly (bot token) — NOT Discord MCP.
It is NOT affected by Discord MCP outages and does not require checking MCP availability.

Usage:
  python3 ~/marvin-bot/second-brain-discord-ingest.py
"""

import json
import os
import subprocess
import time
import hashlib
import requests
from datetime import datetime, timezone, timedelta
from pathlib import Path

# ─── Paths ────────────────────────────────────────────────────────────────────
MARVIN_ENV      = Path.home() / "marvin-bot" / ".env"
CHANNEL_REGISTRY = Path.home() / "pap-workspace" / "channel-registry.json"
SECOND_BRAIN_DIR = Path.home() / "pap-workspace" / "second-brain"
PROGRESS_FILE   = Path.home() / "pap-workspace" / "second-brain-progress.json"

# ─── Config ───────────────────────────────────────────────────────────────────
BATCH_SIZE       = 50          # messages per Claude distillation call
DISCORD_FETCH    = 100         # Discord API max per request
DAYS_BACK        = 60          # how far back to fetch (covers entire server history)
PAP_AUDIT_CH     = "{{USER_CHANNEL_HELM_AUDIT}}"

# All channels to ingest (core PAP channels + workspaces from registry)
CORE_CHANNELS = [
    {"id": "1498823989324419094", "name": "general"},
    {"id": "1499287733007421611", "name": "capture"},
    {"id": "{{USER_CHANNEL_HELM_IMPROVEMENTS}}", "name": "pap-improvements"},
    {"id": "1501656066340032776", "name": "pap-improvements-archived"},
]


# ─── Env loading ──────────────────────────────────────────────────────────────
def load_env(path):
    env = {}
    try:
        with open(path) as f:
            for line in f:
                line = line.strip()
                if "=" in line and not line.startswith("#"):
                    k, v = line.split("=", 1)
                    env[k.strip()] = v.strip()
    except FileNotFoundError:
        pass
    return env


# ─── Checkpoint ───────────────────────────────────────────────────────────────
def load_progress():
    if PROGRESS_FILE.exists():
        try:
            return json.loads(PROGRESS_FILE.read_text())
        except Exception:
            pass
    return {"completed_batches": [], "total_messages": 0, "files_written": []}


def save_progress(progress):
    PROGRESS_FILE.write_text(json.dumps(progress, indent=2))


def batch_key(channel_id, batch_idx):
    return f"{channel_id}:{batch_idx}"


# ─── Discord REST API ─────────────────────────────────────────────────────────
def discord_get(path, bot_token, params=None):
    url = f"https://discord.com/api/v10{path}"
    headers = {"Authorization": f"Bot {bot_token}"}
    try:
        resp = requests.get(url, headers=headers, params=params, timeout=15)
        if resp.status_code == 200:
            return resp.json()
        if resp.status_code == 403:
            return None  # no access — skip silently
        if resp.status_code == 429:
            retry_after = float(resp.headers.get("Retry-After", "5"))
            print(f"  [rate-limit] sleeping {retry_after}s")
            time.sleep(retry_after + 0.5)
            return discord_get(path, bot_token, params)
        print(f"  [http-error] {resp.status_code} {path}")
        return None
    except Exception as e:
        print(f"  [error] {e}")
        return None


def fetch_channel_threads(channel_id, bot_token):
    """Fetch active and archived threads for a channel."""
    threads = []
    # Active threads
    active = discord_get(f"/channels/{channel_id}/threads/active", bot_token)
    if isinstance(active, dict) and "threads" in active:
        threads.extend(active["threads"])
    # Archived threads
    archived = discord_get(f"/channels/{channel_id}/threads/archived/public", bot_token)
    if isinstance(archived, dict) and "threads" in archived:
        threads.extend(archived["threads"])
    return threads


def fetch_all_messages(channel_id, bot_token, days_back=60):
    """Fetch all messages from a channel going back `days_back` days, oldest-first."""
    cutoff_ts = datetime.now(timezone.utc) - timedelta(days=days_back)
    messages = []
    before = None

    while True:
        params = {"limit": DISCORD_FETCH}
        if before:
            params["before"] = before
        batch = discord_get(f"/channels/{channel_id}/messages", bot_token, params)
        if not isinstance(batch, list) or len(batch) == 0:
            break
        messages.extend(batch)
        # Check oldest message in batch
        oldest_ts_str = batch[-1].get("timestamp", "")
        if oldest_ts_str:
            # Handle both 'Z' suffix and explicit timezone formats
            ts_clean = oldest_ts_str.rstrip("Z")
            if "+" not in ts_clean and ts_clean.count("-") < 3:
                ts_clean += "+00:00"
            oldest_ts = datetime.fromisoformat(ts_clean)
            if oldest_ts < cutoff_ts:
                break
        before = batch[-1]["id"]
        time.sleep(0.5)  # rate limit courtesy

    # Filter to cutoff and reverse to chronological order
    def parse_ts(ts_str):
        ts_str = ts_str.rstrip("Z")
        if "+" not in ts_str and ts_str.count("-") < 3:
            ts_str += "+00:00"
        return datetime.fromisoformat(ts_str)

    messages = [
        m for m in messages
        if parse_ts(m.get("timestamp", "2020-01-01T00:00:00")) >= cutoff_ts
    ]
    messages.reverse()
    return messages


# ─── Claude distillation ──────────────────────────────────────────────────────
def distill_messages(messages, channel_name):
    """
    Distill a batch of messages via claude CLI.
    Returns (title, summary_text, cache_creation_tokens, cache_read_tokens).
    Title is a 5-8 word topic slug for QMD searchability.
    """
    lines = []
    for m in messages:
        content = (m.get("content") or "").strip()
        if not content:
            continue
        ts = (m.get("timestamp") or "")[:10]
        author = (m.get("author") or {}).get("username", "?")
        # Skip pure bot embed messages (no content)
        lines.append(f"[{ts}] {author}: {content[:400]}")

    if not lines:
        return None, None, 0, 0

    batch_text = "\n".join(lines[:BATCH_SIZE])
    prompt = (
        f"You are distilling Discord conversation history into a searchable personal knowledge base.\n"
        f"Channel: #{channel_name}\n\n"
        f"First, output a TITLE line: a 4-7 word descriptive title capturing the main topics (e.g. 'ETF tracker column layout decisions', 'PM autonomy behavior compliance audit', 'priority stack CPO role discussion'). Use plain English, no special chars.\n"
        f"Format: TITLE: <title here>\n\n"
        f"Then output the SUMMARY — extract KEY INFORMATION:\n"
        f"- Decisions made and their rationale\n"
        f"- Problems discussed and how they were resolved\n"
        f"- Plans, goals, or ideas mentioned\n"
        f"- Technical tools, approaches, or integrations discussed\n"
        f"- Important context about ongoing projects\n\n"
        f"Be specific and factual. 3-5 paragraphs. Omit greetings and trivial chat.\n\n"
        f"MESSAGES:\n{batch_text}\n\nTITLE:"
    )

    result = subprocess.run(
        ["claude", "-p", "--model", "claude-haiku-4-5-20251001", "--output-format", "json"],
        input=prompt,
        capture_output=True,
        text=True,
        timeout=90,
    )

    if result.returncode != 0:
        print(f"  [claude-error] {result.stderr[:200]}")
        return None, None, 0, 0

    try:
        data = json.loads(result.stdout)
        usage = data.get("usage", {})
        cache_create = usage.get("cache_creation_input_tokens", 0)
        cache_read   = usage.get("cache_read_input_tokens", 0)
        raw = data.get("result", "").strip()
    except Exception as e:
        print(f"  [parse-error] {e}")
        raw = result.stdout.strip()
        cache_create, cache_read = 0, 0

    # Parse TITLE: line from start of response
    title = None
    summary_lines = []
    parsing_title = True
    for line in raw.splitlines():
        if parsing_title and line.upper().startswith("TITLE:"):
            title = line[6:].strip()
            parsing_title = False
        else:
            parsing_title = False
            summary_lines.append(line)
    summary = "\n".join(summary_lines).strip()

    if not title:
        title = f"{channel_name} conversation"

    return title, summary, cache_create, cache_read


# ─── Decision extraction ──────────────────────────────────────────────────────
def extract_decisions(summary_text, channel_name, topic_title, date_start, date_end):
    """
    Given a batch summary, ask Haiku to extract 3-5 named decisions as separate files.
    Returns list of (decision_title, decision_body) tuples.
    Skips channels that are mostly link dumps (capture, daily-brief).
    """
    if channel_name in ("capture", "daily-brief"):
        return []

    prompt = (
        f"You are indexing decisions from a Discord conversation for a personal knowledge base.\n"
        f"Channel: #{channel_name}  Topic: {topic_title}  Period: {date_start} to {date_end}\n\n"
        f"Below is a summary of the conversation. Extract the 2-4 most important NAMED DECISIONS — "
        f"specific choices, conclusions, or resolved questions. Skip procedural steps and in-progress items.\n\n"
        f"For each decision, output:\n"
        f"DECISION: <5-8 word title, snake_case, specific — e.g. 'pm_sweep_fires_every_5_min', 'research_mandate_required_before_answer'>\n"
        f"BODY: <1-2 sentence explanation of what was decided and why>\n\n"
        f"Only output decisions with 'DECISION:' and 'BODY:' prefixes. If no clear decisions, output NONE.\n\n"
        f"SUMMARY:\n{summary_text[:1500]}\n"
    )

    result = subprocess.run(
        ["claude", "-p", "--model", "claude-haiku-4-5-20251001", "--output-format", "json"],
        input=prompt,
        capture_output=True,
        text=True,
        timeout=60,
    )

    if result.returncode != 0:
        return []

    try:
        data = json.loads(result.stdout)
        raw = data.get("result", "").strip()
    except Exception:
        return []

    if not raw or raw.strip().upper() == "NONE":
        return []

    decisions = []
    current_title = None
    current_body = []
    for line in raw.splitlines():
        line = line.strip()
        if line.upper().startswith("DECISION:"):
            if current_title and current_body:
                decisions.append((current_title, " ".join(current_body)))
            current_title = line[9:].strip().lower()
            current_body = []
        elif line.upper().startswith("BODY:") and current_title:
            current_body.append(line[5:].strip())
        elif line and current_title:
            current_body.append(line)

    if current_title and current_body:
        decisions.append((current_title, " ".join(current_body)))

    return decisions[:4]


def write_decisions(decisions, channel_name, topic_title, date_start):
    """Write each extracted decision as a separate second-brain file."""
    import re
    today = datetime.now().strftime("%Y-%m-%d")
    written = []
    for dec_title, dec_body in decisions:
        slug = re.sub(r"[^a-z0-9]+", "-", dec_title.lower()).strip("-")[:60]
        filename = f"{today}-decision-{channel_name}-{slug}.md"
        filepath = SECOND_BRAIN_DIR / filename
        if filepath.exists():
            continue
        md = (
            f"# Decision: {dec_title.replace('_', ' ').title()}\n"
            f"## Source: discord:{channel_name}\n"
            f"## Topic: {topic_title}\n"
            f"## Period: {date_start}\n"
            f"## Date: {today}\n"
            f"## Type: decision\n\n"
            f"---\n\n"
            f"{dec_body}\n"
        )
        filepath.write_text(md)
        written.append(filename)
    return written


# ─── Write to second-brain ────────────────────────────────────────────────────
def write_summary(channel_name, channel_id, date_start, date_end, batch_idx, content, topic_title=None):
    today = datetime.now().strftime("%Y-%m-%d")
    # Use topic title in slug so QMD can surface by content, not just channel+date
    if topic_title:
        import re
        title_slug = re.sub(r"[^a-z0-9]+", "-", topic_title.lower()).strip("-")[:60]
    else:
        title_slug = f"{channel_name}-{date_start}"
    slug = f"discord-{channel_name}-{title_slug}"
    filename = f"{today}-{slug}.md"
    filepath = SECOND_BRAIN_DIR / filename

    display_title = topic_title or f"Discord #{channel_name} — {date_start} to {date_end}"
    md = (
        f"# {display_title}\n"
        f"## Source: discord:{channel_id}\n"
        f"## Channel: {channel_name}\n"
        f"## Date: {today}\n"
        f"## Period: {date_start} to {date_end}\n"
        f"## Batch: {batch_idx}\n\n"
        f"---\n\n"
        f"{content}\n"
    )
    filepath.write_text(md)
    return filename


# ─── Post to pap-audit ────────────────────────────────────────────────────────
def post_to_pap_audit(message, bot_token):
    url = f"https://discord.com/api/v10/channels/{PAP_AUDIT_CH}/messages"
    headers = {"Authorization": f"Bot {bot_token}", "Content-Type": "application/json"}
    try:
        resp = requests.post(url, json={"content": message}, headers=headers, timeout=10)
        if resp.status_code not in (200, 201):
            print(f"[pap-audit post failed] {resp.status_code}: {resp.text[:100]}")
    except Exception as e:
        print(f"[pap-audit post failed] {e}")


# ─── Main ─────────────────────────────────────────────────────────────────────
def main():
    print("=" * 60)
    print("PAP Second Brain — Loop B: Discord Backfill")
    print(f"Started: {datetime.now().isoformat()}")
    print("=" * 60)

    env = load_env(MARVIN_ENV)
    bot_token = env.get("DISCORD_BOT_TOKEN", "")
    if not bot_token:
        print("[FATAL] DISCORD_BOT_TOKEN not found in .env")
        return 1

    # Load workspace channels from registry
    workspace_channels = []
    if CHANNEL_REGISTRY.exists():
        try:
            reg = json.loads(CHANNEL_REGISTRY.read_text())
            for c in reg.get("workspace_channels", []):
                workspace_channels.append({"id": c["channel_id"], "name": c["name"]})
        except Exception as e:
            print(f"[warn] Could not load channel-registry: {e}")

    all_channels = CORE_CHANNELS + workspace_channels
    print(f"Channels to process: {len(all_channels)}")

    SECOND_BRAIN_DIR.mkdir(parents=True, exist_ok=True)
    progress = load_progress()

    total_messages_processed = progress.get("total_messages", 0)
    files_written = progress.get("files_written", [])
    cache_create_total = 0
    cache_read_total   = 0

    for channel in all_channels:
        channel_id   = channel["id"]
        channel_name = channel["name"]
        print(f"\n── #{channel_name} ({channel_id}) ──")

        # Fetch messages
        print(f"  Fetching message history (last {DAYS_BACK} days)...")
        messages = fetch_all_messages(channel_id, bot_token, days_back=DAYS_BACK)
        if not messages:
            print("  No messages found or no access — skipping")
            continue
        print(f"  Found {len(messages)} messages")

        # Also fetch threads for this channel
        print(f"  Fetching threads...")
        threads = fetch_channel_threads(channel_id, bot_token)
        for thread in threads:
            thread_msgs = fetch_all_messages(thread["id"], bot_token, days_back=DAYS_BACK)
            if thread_msgs:
                # Prepend thread name to messages for context
                for m in thread_msgs:
                    m["_thread"] = thread.get("name", "thread")
                messages.extend(thread_msgs)
                print(f"  + thread '{thread.get('name','?')}': {len(thread_msgs)} messages")
            time.sleep(0.3)

        # Determine date range for first/last message
        timestamps = [m.get("timestamp", "") for m in messages if m.get("timestamp")]
        date_start = timestamps[0][:10] if timestamps else "unknown"
        date_end   = timestamps[-1][:10] if timestamps else "unknown"

        # Batch and distill
        batches = [messages[i:i+BATCH_SIZE] for i in range(0, len(messages), BATCH_SIZE)]
        print(f"  Processing {len(batches)} batches of up to {BATCH_SIZE} messages...")

        for batch_idx, batch in enumerate(batches):
            key = batch_key(channel_id, batch_idx)
            if key in progress.get("completed_batches", []):
                print(f"  [skip] batch {batch_idx} already processed")
                continue

            print(f"  Distilling batch {batch_idx+1}/{len(batches)} ({len(batch)} msgs)...", end=" ")
            title, summary, cc, cr = distill_messages(batch, channel_name)
            cache_create_total += cc
            cache_read_total   += cr
            print(f"title='{title}' cache_create={cc} cache_read={cr}")

            if summary:
                fname = write_summary(channel_name, channel_id, date_start, date_end, batch_idx, summary, topic_title=title)
                files_written.append(fname)
                print(f"  Written: {fname}")

                # Extract and write individual decisions
                decisions = extract_decisions(summary, channel_name, title or channel_name, date_start, date_end)
                if decisions:
                    dec_files = write_decisions(decisions, channel_name, title or channel_name, date_start)
                    files_written.extend(dec_files)
                    print(f"  Decisions extracted: {len(dec_files)} files")

            total_messages_processed += len(batch)

            # Checkpoint after each batch
            progress["completed_batches"] = progress.get("completed_batches", []) + [key]
            progress["total_messages"]    = total_messages_processed
            progress["files_written"]     = files_written
            save_progress(progress)
            time.sleep(1)  # gentle rate limiting between Claude calls

    print(f"\n{'=' * 60}")
    print(f"Ingestion complete.")
    print(f"  Messages processed:  {total_messages_processed}")
    print(f"  Files written:       {len(files_written)}")
    print(f"  Cache create tokens: {cache_create_total}")
    print(f"  Cache read tokens:   {cache_read_total}")

    # Re-index QMD
    print("\nRe-indexing QMD...")
    qmd_result = subprocess.run(
        ["qmd", "update"],
        capture_output=True, text=True, timeout=120,
        env={**os.environ, "HOME": str(Path.home())}
    )
    if qmd_result.returncode == 0:
        print("  QMD update: OK")
    else:
        print(f"  QMD update error: {qmd_result.stderr[:200]}")

    # Post summary to pap-audit
    summary_msg = (
        f"✅ second-brain-discord-ingest.py complete — "
        f"{total_messages_processed} messages from {len(all_channels)} channels, "
        f"{len(files_written)} distillation files written. "
        f"Cache: create={cache_create_total} read={cache_read_total}"
    )
    post_to_pap_audit(summary_msg, bot_token)
    print(f"\n[pap-audit] {summary_msg}")

    return 0


if __name__ == "__main__":
    import sys
    sys.exit(main())
