#!/usr/bin/env bash
# deferred-items.sh — Read/write deferred setup items
# Usage: deferred-items.sh list | deferred-items.sh mark-done <key>
DEFERRED="${HOME}/helm-workspace/.deferred-items.json"
[ ! -f "$DEFERRED" ] && echo '{}' > "$DEFERRED"
case "${1:-list}" in
  list)
    python3 -c "
import json, sys
d = json.load(open('$DEFERRED'))
pending = [(k,v) for k,v in d.items() if v]
if not pending:
    print('No deferred items.')
else:
    print(f'{len(pending)} deferred item(s):')
    for k,v in pending:
        print(f'  • {k}')
"
    ;;
  mark-done)
    key="$2"
    [ -z "$key" ] && echo "Usage: deferred-items.sh mark-done <key>" && exit 1
    python3 -c "
import json
d = json.load(open('$DEFERRED'))
d['$key'] = False
open('$DEFERRED', 'w').write(json.dumps(d, indent=2))
print('Marked $key as done.')
"
    ;;
esac
