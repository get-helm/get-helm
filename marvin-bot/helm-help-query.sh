#!/bin/bash
# helm-help-query.sh — search HELM docs and return relevant section
# Usage: helm-help-query.sh "topic or question"
# Outputs: relevant doc excerpt + link
# Falls back to inline answer if docs can't be fetched

set -euo pipefail

TOPIC="$*"
if [[ -z "$TOPIC" ]]; then
  echo "Usage: helm-help-query.sh 'topic or question'" >&2
  exit 1
fi

DOCS_BASE="https://raw.githubusercontent.com/{{USER_GITHUB}}/helm-docs/main"
DOCS_URL="https://github.com/{{USER_GITHUB}}/helm-docs/blob/main"

# Topic → file + section mapping
python3 - "$TOPIC" "$DOCS_BASE" "$DOCS_URL" << 'PYEOF'
import sys, re, urllib.request, urllib.error

topic = sys.argv[1].lower().strip()
docs_base = sys.argv[2]
docs_url = sys.argv[3]

# Routing table: keywords → (file, section_header, display_title)
ROUTES = [
    (["phase", "planning", "building", "testing", "refining", "live", "validate", "optimize", "graduate"], "GUIDE.md", "Phases", "phases"),
    (["proposal", "propose", "approve", "yes no", "design"], "GUIDE.md", "Proposals", "proposals"),
    (["workspace", "channel", "create", "new workspace", "automation"], "GUIDE.md", "Workspaces", "workspaces"),
    (["command", "how do i", "syntax", "@helm"], "GUIDE.md", "Commands", "commands"),
    (["troubleshoot", "broken", "stuck", "not responding", "stopped", "error", "issue", "bug", "wrong"], "GUIDE.md", "Troubleshooting", "troubleshooting"),
    (["faq", "frequently", "common question"], "FAQ.md", None, "faq"),
    (["preference", "set tone", "set verbosity", "pushback", "change setting", "formality", "setting"], "PREFERENCES.md", None, "preferences"),
    (["install", "setup", "set up", "getting started", "download"], "INSTALL.md", None, "install"),
    (["security", "data", "privacy", "credential", "password", "store", "send"], "REFERENCE.md", "Security", "security"),
    (["what is helm", "what does helm", "helm do", "quickstart", "quick start", "first", "intro"], "QUICKSTART.md", None, "quickstart"),
]

# Find best match
matched_file = None
matched_section = None
matched_display = None
matched_score = 0

for keywords, doc_file, section, display in ROUTES:
    score = sum(1 for kw in keywords if kw in topic)
    if score > matched_score:
        matched_score = score
        matched_file = doc_file
        matched_section = section
        matched_display = display

if not matched_file:
    # Default to GUIDE.md FAQ section
    matched_file = "FAQ.md"
    matched_section = None
    matched_display = "general"

# Fetch the doc
try:
    url = f"{docs_base}/{matched_file}"
    with urllib.request.urlopen(url, timeout=5) as r:
        content = r.read().decode('utf-8')
except (urllib.error.URLError, Exception) as e:
    print(f"Docs unavailable. Just ask your question in any channel — HELM will answer.\n\nFull docs: https://github.com/{{USER_GITHUB}}/helm-docs")
    sys.exit(0)

# Extract relevant section if specified
lines = content.split('\n')
excerpt = []

if matched_section:
    in_section = False
    section_depth = 2  # ## level
    for i, line in enumerate(lines):
        # Find section header (## or ###)
        if re.match(r'^#{1,3}\s+' + re.escape(matched_section), line, re.IGNORECASE):
            in_section = True
            excerpt.append(line)
            continue
        if in_section:
            # Stop at next same-level or higher heading
            m = re.match(r'^(#{1,3})\s+', line)
            if m and len(m.group(1)) <= section_depth:
                break
            excerpt.append(line)
            if len(excerpt) > 30:  # cap at ~30 lines
                break
    if not excerpt:
        excerpt = lines[:25]
else:
    excerpt = lines[:30]

# Clean up and truncate
text = '\n'.join(l for l in excerpt if l.strip()).strip()
if len(text) > 1500:
    text = text[:1500] + '\n...'

doc_link = f"{docs_url}/{matched_file}"
if matched_section:
    anchor = matched_section.lower().replace(' ', '-').replace('&', '')
    doc_link = f"{docs_url}/{matched_file}#{anchor}"

print(f"📖 **{matched_section or matched_file.replace('.md','')}** (from HELM docs)\n\n{text}\n\n→ Full docs: {doc_link}")
PYEOF
