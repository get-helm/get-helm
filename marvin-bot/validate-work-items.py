#!/usr/bin/env python3
"""WI-011: work-items.json validation script.

Enforces:
  - verified_by required (non-empty) when status=done
  - pre_queue_check required (non-empty) when status=queued

Usage:
  validate-work-items.py                      # validate default work-items.json
  validate-work-items.py /path/to/file.json  # validate specific file
  validate-work-items.py --check-item WI-042 # validate one item (PM pre-write gate)
  validate-work-items.py --status done --id WI-042 --verified_by "grep:line:42"  # pre-write gate

Exit codes:
  0 = all clean
  1 = violations found
  2 = file not found or invalid JSON
"""
import sys
import json
import os

WORK_ITEMS_PATH = os.path.join(os.environ.get('HOME', '/Users/{{USER_HOME}}'), 'helm-workspace', 'work-items.json')
FRICTION_LOG = os.path.join(os.environ.get('HOME', '/Users/{{USER_HOME}}'), 'helm-workspace', 'system', 'friction-log.md')


def validate_file(path):
    try:
        with open(path) as f:
            data = json.load(f)
    except FileNotFoundError:
        print(f'ERROR: {path} not found')
        return 2, []
    except json.JSONDecodeError as e:
        print(f'ERROR: invalid JSON — {e}')
        return 2, []

    items = data.get('items', [])
    violations = []

    for item in items:
        item_id = item.get('id', '(no id)')
        status = item.get('status', '')
        title = item.get('title', '')[:60]

        if status == 'done':
            vb = item.get('verified_by', '')
            if not vb or not vb.strip() or vb.strip().lower() in ('null', 'none', 'n/a', ''):
                violations.append({
                    'id': item_id,
                    'title': title,
                    'rule': 'verified_by_required',
                    'detail': f'status=done but verified_by is empty/missing',
                })

        if status == 'queued':
            pq = item.get('pre_queue_check', '')
            if not pq or not pq.strip() or pq.strip().lower() in ('null', 'none', ''):
                violations.append({
                    'id': item_id,
                    'title': title,
                    'rule': 'pre_queue_check_required',
                    'detail': f'status=queued but pre_queue_check is empty/missing',
                })

    return 0 if not violations else 1, violations


def check_pre_write(args):
    """Called as pre-write gate: validate a single item's proposed new state before writing.
    Returns 0 if OK, 1 if blocked."""
    item_id = None
    status = None
    verified_by = None
    pre_queue_check = None

    i = 0
    while i < len(args):
        if args[i] == '--id' and i + 1 < len(args):
            item_id = args[i + 1]; i += 2
        elif args[i] == '--status' and i + 1 < len(args):
            status = args[i + 1]; i += 2
        elif args[i] == '--verified_by' and i + 1 < len(args):
            verified_by = args[i + 1]; i += 2
        elif args[i] == '--pre_queue_check' and i + 1 < len(args):
            pre_queue_check = args[i + 1]; i += 2
        else:
            i += 1

    if status == 'done':
        if not verified_by or not verified_by.strip():
            print(f'BLOCKED: Cannot mark {item_id} as done — verified_by is required.')
            print('  Set verified_by to: grep output with file:line, test result, or confirmed live behavior.')
            log_friction(f'WI-011-BLOCK: {item_id} → done rejected (no verified_by)')
            return 1

    if status == 'queued':
        if not pre_queue_check or not pre_queue_check.strip():
            print(f'BLOCKED: Cannot mark {item_id} as queued — pre_queue_check is required.')
            print('  Set pre_queue_check to show: DONE-ARCHIVE search + bot.js grep (if applicable) was run.')
            log_friction(f'WI-011-BLOCK: {item_id} → queued rejected (no pre_queue_check)')
            return 1

    print(f'OK: {item_id} → {status} is valid')
    return 0


def log_friction(msg):
    try:
        from datetime import datetime, timezone
        ts = datetime.now(timezone.utc).isoformat()
        with open(FRICTION_LOG, 'a') as f:
            f.write(f'\n[{ts}] {msg}\n')
    except Exception:
        pass


def main():
    args = sys.argv[1:]

    # Pre-write gate mode
    if '--status' in args or '--id' in args:
        sys.exit(check_pre_write(args))

    # File validation mode
    path = args[0] if args and not args[0].startswith('--') else WORK_ITEMS_PATH
    code, violations = validate_file(path)

    if not violations:
        print(f'work-items.json OK — no violations')
        sys.exit(0)

    print(f'VIOLATIONS ({len(violations)}):')
    for v in violations:
        print(f'  [{v["id"]}] {v["rule"]}: {v["detail"]}')
        print(f'    Title: {v["title"]}')

    # Log to friction-log
    log_friction(f'WI-011-VIOLATIONS: {len(violations)} found — {", ".join(v["id"] for v in violations)}')
    sys.exit(1)


if __name__ == '__main__':
    main()
