#!/usr/bin/env python3
"""
second-brain-discord-ingest-raw.py — Loop B: Discord backfill for PAP second brain (Route B).

Architecture: Discord REST API → Raw markdown files → QMD indexing
Run as-needed for backfill or weekly for maintenance.
Idempotent: checkpoint file skips already-processed batches.

This version skips Claude distillation (Route B) to avoid API costs.
Messages are written raw to markdown, fully searchable via QMD FTS5.

Usage:
  python3 ~/marvin-bot/second-brain-discord-ingest-raw.py
"""

import json
import os
import re
import subprocess
import time
from datetime import datetime, timezone, timedelta
from pathlib import Path
import requests

# ─── Paths ────────────────────────────────────────────────────────────────────
MARVIN_ENV      = Path.home() / "marvin-bot" / ".env"
CHANNEL_REGISTRY = Path.home() / "pap-workspace" / "channel-registry.json"
SECOND_BRAIN_DIR = Path.home() / "pap-workspace" / "second-brain"
PROGRESS_FILE   = Path.home() / "pap-workspace" / "second-brain-progress.json"

# ─── Config ───────────────────────────────────────────────────────────────────
BATCH_SIZE       = 500         # messages per markdown file (larger, since no Claude call)
DISCORD_FETCH    = 100         # Discord API max per request
DAYS_BACK        = 3650        # 10 years — cover all history
PAP_AUDIT_CH     = "{{USER_CHANNEL_HELM_AUDIT}}"

# All channels to ingest (core PAP channels + workspaces from registry)
CORE_CHANNELS = [
    {"id": "1498823989324419094", "name": "general"},
    {"id": "1499287733007421611", "name": "capture"},
    {"id": "{{USER_CHANNEL_HELM_IMPROVEMENTS}}", "name": "helm-improvements"},
    {"id": "1501656066340032776", "name": "helm-improvements-archived"},
    {"id": "1500203712692486326", "name": "helm-help"},
    {"id": "{{USER_CHANNEL_HELM_AUDIT}}", "name": "helm-audit"},
    {"id": "{{USER_CHANNEL_HELM_STATUS}}", "name": "helm-status"},
    {"id": "1515113850695844050", "name": "preferences"},
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
    return {"completed_channels": [], "total_messages": 0, "files_written": []}


def save_progress(progress):
    PROGRESS_FILE.write_text(json.dumps(progress, indent=2))


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


def fetch_guild_active_threads(bot_token, channel_id_for_guild):
    """Fetch ALL active threads guild-wide, keyed by parent channel id.

    /channels/{id}/threads/active was removed from the Discord API (404) —
    active threads are only available via /guilds/{guild_id}/threads/active.
    """
    chan = discord_get(f"/channels/{channel_id_for_guild}", bot_token)
    guild_id = (chan or {}).get("guild_id")
    if not guild_id:
        print("  [warn] could not resolve guild_id — active threads unavailable")
        return {}
    active = discord_get(f"/guilds/{guild_id}/threads/active", bot_token)
    by_parent = {}
    if isinstance(active, dict):
        for t in active.get("threads", []):
            by_parent.setdefault(t.get("parent_id"), []).append(t)
    return by_parent


def fetch_channel_threads(channel_id, bot_token, active_by_parent=None):
    """Fetch active (from guild-wide prefetch) and archived threads for a channel."""
    threads = list((active_by_parent or {}).get(channel_id, []))
    seen = {t["id"] for t in threads}
    archived = discord_get(f"/channels/{channel_id}/threads/archived/public", bot_token)
    if isinstance(archived, dict) and "threads" in archived:
        threads.extend(t for t in archived["threads"] if t["id"] not in seen)
    return threads


def _thread_last_activity(thread):
    """Best-effort last-activity timestamp from the thread's last_message_id snowflake."""
    last_id = thread.get("last_message_id")
    if not last_id:
        return None
    try:
        ms = (int(last_id) >> 22) + 1420070400000
        return datetime.fromtimestamp(ms / 1000, tz=timezone.utc)
    except (ValueError, TypeError):
        return None


def fetch_all_messages(channel_id, bot_token, days_back=3650):
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


# ─── Write raw messages to markdown ────────────────────────────────────────────
def _slugify(text, max_len=60):
    """Convert text to a filename-safe slug."""
    s = text.lower()
    s = re.sub(r'[^a-z0-9]+', '-', s)
    s = s.strip('-')
    return s[:max_len]


def _write_messages_to_file(filepath, title, messages):
    """Write a list of messages to a markdown file. Returns filename."""
    lines = [
        f"# {title}",
        f"## Generated: {datetime.now().strftime('%Y-%m-%d')}",
        f"## Message count: {len(messages)}",
        "",
        "---",
        "",
    ]
    for m in messages:
        content = (m.get("content") or "").strip()
        if not content:
            continue
        ts = (m.get("timestamp") or "")[:19].replace("T", " ")
        author = (m.get("author") or {}).get("username", "?")
        content_escaped = content.replace("`", "\\`")
        lines.append(f"- [{ts}] **{author}**: {content_escaped}")
    filepath.write_text("\n".join(lines) + "\n")
    return filepath.name


def write_thread_messages(channel_name, thread_name, messages):
    """Write a single thread's messages to its own named file."""
    if not messages:
        return None
    slug = _slugify(thread_name)
    filename = f"discord-{channel_name}-thread-{slug}.md"
    filepath = SECOND_BRAIN_DIR / filename
    title = f"Discord #{channel_name} — Thread: {thread_name}"
    return _write_messages_to_file(filepath, title, messages)


def write_raw_messages(channel_name, channel_id, messages):
    """Write non-thread channel messages to a named file (searchable, no distillation)."""
    if not messages:
        return None
    filename = f"discord-{channel_name}-main.md"
    filepath = SECOND_BRAIN_DIR / filename
    title = f"Discord #{channel_name} — Main Channel"
    return _write_messages_to_file(filepath, title, messages)


def write_daily_messages(channel_name, messages):
    """Write incremental main-channel messages as per-day files.

    The old single rolling main.md was overwritten with only the fetch window,
    silently dropping anything older. Per-day files are stable: re-running the
    same window rewrites the same day files with the same content.
    Returns list of filenames written.
    """
    by_day = {}
    for m in messages:
        day = (m.get("timestamp") or "")[:10]
        if day:
            by_day.setdefault(day, []).append(m)
    written = []
    for day, msgs in sorted(by_day.items()):
        filename = f"discord-{channel_name}-{day}.md"
        filepath = SECOND_BRAIN_DIR / filename
        title = f"Discord #{channel_name} — {day}"
        if _write_messages_to_file(filepath, title, msgs):
            written.append(filename)
    return written


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
    print("PAP Second Brain — Discord Backfill (Route B: Raw)")
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

    # Incremental mode: set INCREMENTAL_DAYS env var to only fetch recent messages
    incremental_days = int(os.environ.get("INCREMENTAL_DAYS", "0"))
    days_to_fetch = incremental_days if incremental_days > 0 else DAYS_BACK

    total_messages_processed = progress.get("total_messages", 0)
    files_written = progress.get("files_written", [])
    completed_channels = progress.get("completed_channels", [])

    # Guild-wide active-thread prefetch (channel-level endpoint is dead — 404)
    active_by_parent = fetch_guild_active_threads(bot_token, all_channels[0]["id"])
    print(f"Active threads guild-wide: {sum(len(v) for v in active_by_parent.values())}")

    for channel in all_channels:
        channel_id   = channel["id"]
        channel_name = channel["name"]

        # In incremental mode, always re-process all channels (don't skip completed)
        if incremental_days == 0 and channel_id in completed_channels:
            print(f"\n── #{channel_name} ({channel_id}) [already processed] ──")
            continue

        print(f"\n── #{channel_name} ({channel_id}) ──")

        # Fetch messages
        print(f"  Fetching message history (last {days_to_fetch} days)...")
        messages = fetch_all_messages(channel_id, bot_token, days_back=days_to_fetch)
        if not messages:
            print("  No messages found or no access — skipping")
            completed_channels.append(channel_id)
            save_progress({
                "completed_channels": completed_channels,
                "total_messages": total_messages_processed,
                "files_written": files_written,
            })
            continue
        print(f"  Found {len(messages)} messages")

        # Fetch and write threads as separate per-topic files.
        # Threads ALWAYS fetch full history — thread files are complete snapshots,
        # so a windowed fetch here would overwrite the file and erase older content.
        print(f"  Fetching threads...")
        threads = fetch_channel_threads(channel_id, bot_token, active_by_parent)
        for thread in threads:
            t_name = thread.get("name", "thread")
            if incremental_days > 0:
                last_msg_ts = _thread_last_activity(thread)
                if last_msg_ts and last_msg_ts < datetime.now(timezone.utc) - timedelta(days=days_to_fetch):
                    continue  # no recent activity — existing snapshot is current
            thread_msgs = fetch_all_messages(thread["id"], bot_token, days_back=DAYS_BACK)
            if thread_msgs:
                fname = write_thread_messages(channel_name, t_name, thread_msgs)
                if fname:
                    files_written.append(fname)
                    total_messages_processed += len(thread_msgs)
                    print(f"  + thread '{t_name}': {len(thread_msgs)} msgs → {fname}")
            time.sleep(0.3)

        # Write main-channel (non-thread) messages
        print(f"  Writing {len(messages)} main-channel messages...")
        if incremental_days > 0:
            day_files = write_daily_messages(channel_name, messages)
            files_written.extend(day_files)
            print(f"  Written: {len(day_files)} per-day files")
        else:
            fname = write_raw_messages(channel_name, channel_id, messages)
            if fname:
                files_written.append(fname)
                print(f"  Written: {fname}")

        total_messages_processed += len(messages)
        completed_channels.append(channel_id)

        # Checkpoint after each channel
        progress_state = {
            "completed_channels": completed_channels,
            "total_messages": total_messages_processed,
            "files_written": files_written,
        }
        save_progress(progress_state)
        time.sleep(1)

    print(f"\n{'=' * 60}")
    print(f"Backfill complete.")
    print(f"  Messages processed:  {total_messages_processed}")
    print(f"  Files written:       {len(files_written)}")
    print(f"  Channels completed:  {len(completed_channels)}/{len(all_channels)}")

    # Re-index QMD
    print("\nRe-indexing QMD...")
    qmd_path = Path.home() / ".bun" / "bin" / "qmd"
    qmd_result = subprocess.run(
        [str(qmd_path), "update"],
        capture_output=True, text=True, timeout=120,
        cwd=str(Path.home() / "pap-workspace"),
        env={**os.environ, "HOME": str(Path.home())}
    )
    if qmd_result.returncode == 0:
        print("  QMD update: OK")
    else:
        print(f"  QMD update error: {qmd_result.stderr[:200]}")

    # Write summary to ingest-status.log (PM reads this during sweeps — no Discord noise)
    status_line = (
        f"{datetime.now().strftime('%Y-%m-%dT%H:%M:%SZ')} | OK | "
        f"{total_messages_processed} msgs from {len(all_channels)} channels, "
        f"{len(files_written)} files written"
    )
    status_log = Path.home() / "pap-workspace" / "ingest-status.log"
    try:
        with open(status_log, "a") as f:
            f.write(status_line + "\n")
        print(f"\n[ingest-status] {status_line}")
    except Exception as e:
        print(f"[ingest-status write failed] {e}")

    mark_ingest_health("discord")
    return 0


def mark_ingest_health(source):
    """Record per-source last-success time — the freshness watchdog reads this."""
    health_file = SECOND_BRAIN_DIR / ".ingest-health.json"
    try:
        health = json.loads(health_file.read_text()) if health_file.exists() else {}
    except Exception:
        health = {}
    health[source] = {"last_success": datetime.now(timezone.utc).isoformat()}
    health_file.write_text(json.dumps(health, indent=2))


if __name__ == "__main__":
    import sys
    sys.exit(main())
