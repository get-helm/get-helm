# P4.1 New User Onboarding — Design Spec
## PM-authored, 2026-05-23

### Problem
When a new user joins the PAP Discord and sends their first message, they get treated like {{USER_JERRY}} — full capabilities assumed. There's no structured onboarding: no intro to what PAP can do, no preference capture, no first workspace recommendation.

Current state: new user types a message → bot.js routes to help agent → help agent answers the question → done. No profile, no preferences, no follow-up.

### What a good onboarding accomplishes
1. User understands what PAP is and isn't (sets expectations)
2. PAP captures: name, timezone, primary use case (automation? tracking? second brain?)
3. PAP captures: pushback preference (how much challenge do they want from Marvin?)
4. PAP creates a user profile file (~/.pap-profiles/<user-id>.json)
5. PAP recommends a first workspace based on use case
6. End state: user feels like PAP understood them in 5 min

### Proposed flow (10-15 min conversation)

Step 1 — Trigger: First message from a user with no profile file.
Step 2 — Greeting: "Hi, I'm Marvin. I help automate your life. Before we start, I have 5 quick questions — takes about 5 min."
Step 3 — Name + timezone: "What should I call you? And what timezone are you in?"
Step 4 — Primary use case (button selection):
  - 🔁 Automate repetitive tasks
  - 📊 Track markets / finances
  - 🧠 Second brain / knowledge base
  - 🤖 Build something custom
Step 5 — Pushback preference (button selection):
  - 💪 Challenge me hard — I want the real answer, not a comfortable one
  - ⚖️ Balanced — push back when it matters, agree when it's reasonable
  - 😌 Gentle — I know my goals, help me execute
Step 6 — First recommendation: Based on answers, suggest a workspace + first action.
Step 7 — Write profile to disk: ~/.pap-profiles/<user-id>.json

### Profile format
```json
{
  "userId": "...",
  "displayName": "...",
  "timezone": "America/Los_Angeles",
  "useCase": "track_finances",
  "pushbackPreference": "balanced",
  "onboardedAt": "2026-05-23T..."
}
```

### Engineering scope
- Level 3: new onboarding agent + profile storage. No bot.js routing change if we route "no profile" → onboarding in help agent.
- Alternative (Level 4): bot.js detects new users and routes to onboarding before any other agent.
- Estimated: 3-4 hours engineering.

### Dependency
- Requires bot.js restart only for the Level 4 routing approach
- Help agent can handle onboarding detection (Level 3, no restart)

### What PM needs from {{USER_JERRY}}
1. Should multi-user support be built now or deferred? (Currently PAP = {{USER_JERRY}} only)
2. If deferred: should onboarding just capture {{USER_JERRY}}'s preferences more formally?
3. Pushback preference — is 3 options right, or simpler (just "high/low")?
