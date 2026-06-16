# Marvin Pre-DELIVER Checklist

Before posting a DELIVER message, verify these conditions. This prevents false DELIVER claims (e.g., claiming a fix was applied to the wrong channel).

**Check BEFORE writing DELIVER:**

1. **Channel context match** 
   - [ ] The channel_id I'm responding to matches the channel where work was actually done
   - [ ] If I claim "updated #channel-name CLAUDE.md," verify that file exists: `ls /Users/{{USER_HOME}}/pap-workspace/channel-name/CLAUDE.md`
   - [ ] If the work was in a workspace, verify the workspace folder exists and matches the channel I'm talking to

2. **File changes match the claim**
   - [ ] Every file I name in "Files changed:" was actually edited by me this session
   - [ ] No file appears in DELIVER that I didn't touch
   - [ ] If I claim to have cleared a backlog, verify the file is actually empty: `wc -l ~/pap-workspace/backlog-file.md`

3. **Scope match**
   - [ ] The problem I'm solving is the problem the user actually asked about
   - [ ] If the user asked about #general, I'm not describing fixes to #etf-tracker
   - [ ] If the user asked about "timing issues," I'm not talking about "PM dispatch" — different problem

4. **Verification method is honest**
   - [ ] The "Verification:" section describes something that actually confirms the fix works
   - [ ] Not just "logs show it worked" — actually test or show output
   - [ ] Not vague like "should be good now" — specific

5. **Self-review: Am I guessing?**
   - [ ] Do I actually know the work is done, or am I assuming?
   - [ ] Did I verify the output, or just assume it succeeded?
   - [ ] If I'm saying "should work," that's a hypothesis, not a DELIVER

---

## Red flags (don't post DELIVER if any are true)

- ❌ "I updated [file] in [workspace]" but I never actually read or edited that file
- ❌ "The fix is applied to [channel]" but I'm not sure which channel I'm in
- ❌ "Verification: logs should show X" without actually checking logs
- ❌ Claiming multiple channels were fixed when only one was involved
- ❌ Using outdated channel names or folder paths

---

## If you catch yourself making a mistake

Stop. Don't post the false DELIVER. Instead:

1. Acknowledge what went wrong (2-3 sentences)
2. State what actually happened (what you really did/didn't do)
3. Clarify next steps (what needs to happen to actually fix this)
4. Post a corrected version if appropriate

Example:
"Wait — I realize I claimed to update #etf-tracker CLAUDE.md, but I actually edited the scaffolder template in ~/.claude/agents/. Wrong file. Let me re-examine what the user actually asked for and solve the right problem."

---

## Applied to this session

**Friction-log entry 2026-05-09 07:00:00** describes a false DELIVER:
- Agent claimed: "updated workspace instructions for #general about expense ratios"
- Reality: #general has no workspace folder. Fix was applied to #etf-tracker. Different problem.
- Root cause: Agent confused two concurrent conversations

**This checklist prevents that class of error.**
