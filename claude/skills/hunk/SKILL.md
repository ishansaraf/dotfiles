---
name: hunk
description: Open a Hunk diff review in a Rex pane beside this Claude Code session and attach to it. Use when the user types /hunk or asks to open their changes in Hunk side by side.
argument-hint: "[range like main...HEAD | show <ref> | log | gh pr]"
allowed-tools: Bash(hunk-pane:*), Bash(hunk session:*), Bash(hunk skill show:*)
---

The Hunk pane was opened beside this session:

!`hunk-pane $ARGUMENTS`

You are now attached to that review. Follow these rules:

1. Run `hunk skill show hunk-review` once and follow those instructions for every `hunk session` command.
2. Always target the session by the ID printed above (`hunk session <command> <session-id> ...`), never `--repo`, so you never act on another Hunk window in the same repository. If no ID was printed, find it as the output says, then use it.
3. Never run `hunk diff`, `hunk show`, or another interactive Hunk command yourself. The pane is the user's.
4. Tell the user in one line that the pane is open, what it shows, and that you can navigate the review, add notes beside the code (they press `a` to see them), or read and address their own notes.
5. Do not add review notes unless the user asks. When they say their comments are ready, read them with `hunk session comment list <session-id> --type user --json` and address each one.
