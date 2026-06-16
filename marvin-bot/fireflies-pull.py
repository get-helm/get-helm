#!/usr/bin/env python3
"""Fireflies.ai transcript pull — saves new meeting transcripts to second brain
and posts a summary + transcript link to #capture.

Runs as step 4 of second-brain-continuous-ingest.sh (hourly cron).
State: ~/helm-workspace/second-brain/.fireflies-seen.json (ingested transcript IDs)
"""

import json
import re
import subprocess
import sys
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

SECOND_BRAIN_DIR = Path.home() / "helm-workspace" / "second-brain"
STATE_FILE = SECOND_BRAIN_DIR / ".fireflies-seen.json"
CAPTURE_CHANNEL = "1499287733007421611"
DISCORD_POST = Path.home() / "marvin-bot" / "discord-post.sh"
CLAUDE_BIN = "/opt/homebrew/bin/claude"
API_URL = "https://api.fireflies.ai/graphql"

QUERY = """{
  transcripts(limit: 25) {
    id
    title
    date
    duration
    transcript_url
    summary { overview action_items keywords }
    sentences { text speaker_name }
  }
}"""


def log(msg):
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    print(f"[{ts}] [fireflies-pull] {msg}")


def get_api_key():
    result = subprocess.run(
        ["op", "item", "get", "Fireflies.ai API", "--vault", "HELM Vault",
         "--fields", "password", "--reveal"],
        capture_output=True, text=True, timeout=30,
    )
    key = result.stdout.strip()
    if not key:
        log(f"ERROR: vault read failed: {result.stderr.strip()[:200]}")
        sys.exit(1)
    return key


def fetch_transcripts(api_key):
    payload = json.dumps({"query": QUERY}).encode()
    req = urllib.request.Request(
        API_URL, data=payload,
        headers={"Content-Type": "application/json",
                 "Authorization": f"Bearer {api_key}"},
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        data = json.loads(resp.read())
    if "errors" in data:
        log(f"ERROR: API returned errors: {json.dumps(data['errors'])[:300]}")
        sys.exit(1)
    return data["data"]["transcripts"] or []


def parse_date(raw):
    try:
        if isinstance(raw, (int, float)):
            return datetime.fromtimestamp(raw / 1000)
        return datetime.fromisoformat(str(raw).replace("Z", "+00:00"))
    except (ValueError, OSError):
        return datetime.now()


def slugify(title):
    slug = re.sub(r"[^a-z0-9]+", "-", (title or "meeting").lower()).strip("-")
    return slug[:60] or "meeting"


def haiku_summary(transcript_text):
    """Fallback when Fireflies doesn't provide an AI summary (free-tier cap)."""
    prompt = (
        "Summarize this meeting transcript in 4-6 sentences: key topics, "
        "decisions, and action items. Plain text, no preamble.\n\n"
        + transcript_text[:24000]
    )
    try:
        result = subprocess.run(
            [CLAUDE_BIN, "--model", "haiku", "-p", prompt],
            capture_output=True, text=True, timeout=120,
        )
        out = result.stdout.strip()
        return out if out else None
    except (subprocess.TimeoutExpired, OSError):
        return None


def post_discord(message):
    subprocess.run(["bash", str(DISCORD_POST), CAPTURE_CHANNEL, message],
                   capture_output=True, text=True, timeout=30)


def mark_ingest_health(source):
    health_file = SECOND_BRAIN_DIR / ".ingest-health.json"
    try:
        health = json.loads(health_file.read_text()) if health_file.exists() else {}
    except Exception:
        health = {}
    health[source] = {"last_success": datetime.now(timezone.utc).isoformat()}
    health_file.write_text(json.dumps(health, indent=2))


def main():
    seen = set()
    if STATE_FILE.exists():
        seen = set(json.loads(STATE_FILE.read_text()))

    api_key = get_api_key()
    transcripts = fetch_transcripts(api_key)
    new = [t for t in transcripts if t["id"] not in seen]
    log(f"Fetched {len(transcripts)} transcripts, {len(new)} new")

    for t in new:
        dt = parse_date(t.get("date"))
        date_str = dt.strftime("%Y-%m-%d")
        title = t.get("title") or "Untitled meeting"
        duration = round(t.get("duration") or 0)
        url = t.get("transcript_url") or ""

        summary = t.get("summary") or {}
        overview = (summary.get("overview") or "").strip()
        action_items = (summary.get("action_items") or "").strip()
        keywords = summary.get("keywords") or []
        if isinstance(keywords, str):
            keywords = [keywords]

        lines = [f"{s.get('speaker_name') or 'Unknown'}: {s.get('text', '')}"
                 for s in (t.get("sentences") or [])]
        transcript_text = "\n".join(lines)

        summary_source = "fireflies"
        if not overview and transcript_text:
            overview = haiku_summary(transcript_text) or ""
            summary_source = "haiku-fallback" if overview else "none"

        filename = f"{date_str}-meeting-{slugify(title)}.md"
        filepath = SECOND_BRAIN_DIR / filename
        n = 2
        while filepath.exists():
            filepath = SECOND_BRAIN_DIR / f"{date_str}-meeting-{slugify(title)}-{n}.md"
            n += 1

        md = [
            "---",
            f"title: Meeting — {title}",
            f"date: {date_str}",
            "source: fireflies",
            "type: meeting-transcript",
            f"tags: [meeting, {', '.join(keywords[:5])}]" if keywords else "tags: [meeting]",
            "---",
            "",
            f"# {title}",
            "",
            f"Date: {dt.strftime('%B %d, %Y %I:%M %p')}",
            f"Duration: {duration} min",
            f"Transcript link: {url}",
            f"Summary source: {summary_source}",
            "",
            "## Summary",
            overview or "(no summary available)",
            "",
        ]
        if action_items:
            md += ["## Action Items", action_items, ""]
        md += ["## Full Transcript", "", transcript_text or "(no transcript text)"]

        filepath.write_text("\n".join(md))
        log(f"Saved {filepath.name} ({len(transcript_text)} chars, summary={summary_source})")

        msg_parts = [
            f"📝 **Meeting captured: {title}**",
            f"{dt.strftime('%b %d, %I:%M %p')} · {duration} min",
            "",
            overview[:600] if overview else "_Summary pending — full transcript saved._",
        ]
        if action_items:
            msg_parts += ["", f"**Action items:** {action_items[:300]}"]
        if url:
            msg_parts += ["", f"Full transcript: {url}"]
        msg_parts += ["", "Saved to 2nd brain ✓"]
        post_discord("\n".join(msg_parts))

        seen.add(t["id"])

    STATE_FILE.write_text(json.dumps(sorted(seen)))
    mark_ingest_health("fireflies")
    log(f"Done. State: {len(seen)} transcripts tracked")


if __name__ == "__main__":
    main()
