#!/usr/bin/env python3
"""
DECISION-EXTRACT-BACKFILL-001
Extract named decisions from second-brain files and write decision-[slug].md files.
Targets: discord-pap-improvements batches, discord-helm-improvements batches, session files.
Processes in batches of 5 with checkpoints.
"""
import os
import re
import sys
import json
import time
from pathlib import Path

SECOND_BRAIN = Path.home() / "pap-workspace/second-brain"
CHECKPOINT_FILE = SECOND_BRAIN / "decision-extract-progress.json"


def slugify(title):
    s = title.lower()
    s = re.sub(r'[^\w\s-]', '', s)
    s = re.sub(r'[\s_]+', '-', s)
    s = re.sub(r'-+', '-', s)
    s = s.strip('-')
    return s[:60]


def extract_date_from_filename(fname):
    m = re.match(r'^(\d{4}-\d{2}-\d{2})', fname)
    return m.group(1) if m else "unknown"


def extract_channel_from_filename(fname):
    if 'helm-improvements' in fname or 'pap-improvements' in fname:
        return 'helm-improvements'
    if 'pap-chat' in fname:
        return 'pap-chat'
    if 'general' in fname:
        return 'general'
    return 'unknown'


def extract_decisions_from_batch(filepath):
    """
    Extract decisions from pre-processed batch files.
    Format: bold headers (**Title**) followed by paragraph content.
    """
    text = filepath.read_text(encoding='utf-8', errors='ignore')
    decisions = []

    # Split on bold headers — each is a decision
    # Pattern: ** followed by content at paragraph start
    parts = re.split(r'\n(?=\*\*[^*]+\*\*:?\s)', text)

    # Parse each part
    for part in parts[1:]:  # skip file header
        m = re.match(r'\*\*([^*]+)\*\*:?\s*([\s\S]*?)(?=\n\*\*|\Z)', part.strip())
        if not m:
            continue
        title = m.group(1).strip()
        body = m.group(2).strip()
        if len(body) < 20:  # skip empty/stub entries
            continue
        # Skip if title looks like metadata
        if re.match(r'^(Source|Date|Period|Batch|Channel|Generated)$', title):
            continue
        decisions.append({'title': title, 'body': body})

    return decisions


def extract_decisions_from_session(filepath):
    """
    Extract decisions from session/vision files.
    Look for ## headers as decision sections.
    """
    text = filepath.read_text(encoding='utf-8', errors='ignore')
    decisions = []

    parts = re.split(r'\n(?=## )', text)
    for part in parts[1:]:
        lines = part.strip().split('\n')
        if not lines:
            continue
        title = lines[0].lstrip('#').strip()
        body = '\n'.join(lines[1:]).strip()
        if len(body) < 40:
            continue
        # Skip non-decision headers
        if re.match(r'^(What This Is|How the Conversation|Table of Contents|Summary|Overview|Background|Context|Raw|Full)', title, re.I):
            continue
        decisions.append({'title': title, 'body': body[:800]})  # cap at 800 chars

    return decisions


def write_decision_file(title, body, source_file, date, channel, existing_slugs):
    """Write a decision-[slug].md file. Returns slug used."""
    base_slug = slugify(title)
    slug = base_slug
    counter = 1
    while slug in existing_slugs:
        slug = f"{base_slug}-{counter}"
        counter += 1

    outpath = SECOND_BRAIN / f"decision-{slug}.md"
    content = f"""---
title: {title}
source: {source_file}
date: {date}
channel: {channel}
---

{body}
"""
    outpath.write_text(content, encoding='utf-8')
    existing_slugs.add(slug)
    return slug


def load_checkpoint():
    if CHECKPOINT_FILE.exists():
        return json.loads(CHECKPOINT_FILE.read_text())
    return {'processed': [], 'decisions_written': 0}


def save_checkpoint(cp):
    CHECKPOINT_FILE.write_text(json.dumps(cp, indent=2))


def get_target_files():
    files = []
    # Priority 1: discourse-pap/helm improvements batches (pre-extracted decisions)
    for f in sorted(SECOND_BRAIN.glob("*discord-pap-improvements*.md")):
        files.append(('batch', f))
    for f in sorted(SECOND_BRAIN.glob("*discord-helm-improvements*.md")):
        files.append(('batch', f))
    # Priority 2: session/vision files
    for f in sorted(SECOND_BRAIN.glob("*session*.md")):
        files.append(('session', f))
    for f in sorted(SECOND_BRAIN.glob("*vision*.md")):
        files.append(('session', f))
    # Priority 3: any thread-dump files
    for f in sorted(SECOND_BRAIN.glob("*thread*.md")):
        if 'decision' not in f.name:
            files.append(('session', f))
    return files


def main():
    cp = load_checkpoint()
    processed_set = set(cp['processed'])
    decisions_written = cp['decisions_written']

    # Collect existing slugs to avoid collisions
    existing_slugs = set()
    for f in SECOND_BRAIN.glob("decision-*.md"):
        slug = f.stem.replace('decision-', '', 1)
        existing_slugs.add(slug)

    target_files = get_target_files()
    remaining = [(mode, f) for mode, f in target_files if str(f) not in processed_set]

    print(f"[extract-decisions] Target files: {len(target_files)}, remaining: {len(remaining)}, decisions written so far: {decisions_written}")

    BATCH_SIZE = 5
    batch_num = 0

    for i in range(0, len(remaining), BATCH_SIZE):
        batch = remaining[i:i + BATCH_SIZE]
        batch_num += 1
        batch_decisions = 0

        for mode, filepath in batch:
            try:
                if mode == 'batch':
                    decisions = extract_decisions_from_batch(filepath)
                else:
                    decisions = extract_decisions_from_session(filepath)

                date = extract_date_from_filename(filepath.name)
                channel = extract_channel_from_filename(filepath.name)

                for d in decisions:
                    try:
                        slug = write_decision_file(
                            d['title'], d['body'],
                            filepath.name, date, channel,
                            existing_slugs
                        )
                        batch_decisions += 1
                        decisions_written += 1
                    except Exception as e:
                        print(f"  [skip] {d['title'][:40]}: {e}", file=sys.stderr)

                cp['processed'].append(str(filepath))
                processed_set.add(str(filepath))

            except Exception as e:
                print(f"[error] {filepath.name}: {e}", file=sys.stderr)

        cp['decisions_written'] = decisions_written
        save_checkpoint(cp)
        print(f"[batch {batch_num}] +{batch_decisions} decisions (total: {decisions_written}) — checkpoint saved")

    print(f"[extract-decisions] DONE — {decisions_written} decision files written")
    return decisions_written


if __name__ == '__main__':
    main()
