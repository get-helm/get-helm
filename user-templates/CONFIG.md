# HELM Configuration

<!-- System preferences and behavior settings. -->
<!-- You can change these anytime — HELM reads this file each session. -->

## Daily briefing
<!-- When should HELM send your daily summary? -->
<!-- Example: 7:30am PT weekdays -->
time: 7:30am

## Notification level
<!-- How often should HELM proactively reach out? -->
<!-- Options: minimal / normal / frequent -->
level: normal

## Financial data access
<!-- Should HELM be able to read your account balances and transactions? -->
<!-- Options: yes / no / ask-each-time -->
financial_data: ask-each-time

## Email access
<!-- Should HELM be able to read and draft emails? -->
<!-- Options: read-only / read-and-draft / no -->
email_access: read-only

## Calendar access
<!-- Should HELM be able to read your calendar? -->
<!-- Options: yes / no -->
calendar_access: yes

## Workspace channels
<!-- Which topics do you want dedicated channels for? -->
<!-- HELM creates a private channel per workspace. Delete ones you don't need. -->
workspaces:
  - finance      # Account balances, investments, net worth
  - tasks        # Daily to-do list and task tracking
  # - writing    # Drafting emails, documents, summaries (uncomment to enable)
  # - research   # Deep dives on topics you care about (uncomment to enable)
