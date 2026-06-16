# HELM Preferences

HELM adapts to how you like to communicate and work. You can change any preference anytime by asking HELM.

---

## How to Change a Preference

In any channel:
```
@HELM set [setting] to [value]
@HELM change my [setting] to [value]
```

Examples:
```
@HELM set tone to professional
@HELM change my verbosity to detailed
@HELM set pushback_volume to occasionally
```

HELM confirms the change and updates your preferences panel in #preferences.

---

## Available Settings

### Communication Style

**tone** — how HELM talks to you
- `casual` — conversational, like texting (default)
- `professional` — formal, structured responses

**verbosity** — how much detail you want
- `brief` — key points only, ask for more if needed (default)
- `detailed` — full context, reasoning, implementation details

**pushback_volume** — how much HELM challenges your ideas
- `often` — HELM frequently stress-tests assumptions (default)
- `occasionally` — challenges only when something seems clearly wrong
- `never` — HELM agrees without pushback

**activity_reporting** — how HELM reports completed tasks
- `brief` — one sentence confirmation (default)
- `detailed` — full breakdown of what was done
- `silent` — no status messages unless you ask

---

### Profile

**role** — your title or role (helps HELM suggest relevant automations)
- Free text. Example: `@HELM set role to Product Manager`

**timezone** — your timezone for scheduled automations
- Standard timezone name. Example: `@HELM set timezone to America/Los_Angeles`

---

### Display

**display_mode** — Discord theme preference
- `dark` — dark mode (default)
- `light` — light mode

---

## Viewing Your Preferences

Your current preferences are always visible in the #preferences channel — look for the pinned message.

Or ask HELM:
```
@HELM show my preferences
```

---

## Preferences and Workspaces

Preferences apply to all your HELM workspaces unless overridden in a specific workspace. If you want a workspace to behave differently (e.g. more technical detail for a coding workspace), you can ask HELM directly in that workspace:

```
@HELM in this workspace, give me detailed responses
```

---

## First-Time Setup

When you first install HELM, it asks 5 questions to set up your preferences:

1. What do you want to automate first?
2. How formal do you like responses? (casual / professional)
3. How much detail do you want? (brief / detailed)
4. How much should I challenge your ideas? (often / occasionally / never)
5. What's your timezone?

Your answers become your default settings. You can change any of them anytime.
