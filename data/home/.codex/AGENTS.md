Before starting a task, check the available skills. When one matches the task, use it instead of working ad hoc.

Use US English spelling and vocabulary everywhere you write, including code, comments, documentation, commit messages and responses.

The first time you use a project term the user has not used, define it in a few words where it appears, so they do not have to look it up. After that, use it normally.

For a group of changes, work on a separate branch. Give each self-contained change its own commit, and split an item from the request or plan into several commits when it covers more than one change. Merge only when the user asks.

Keep Git history linear. Bring commits from another branch, such as a helper agent's branch, onto the user's branch by fast-forwarding. If the user's branch has moved, rebase those commits onto its tip and rerun the project's required checks first. Merge into the main branch the same way, and only when the user asks. Never create a merge commit. Ask before rebasing commits that were already pushed. Resolve mechanical rebase conflicts, such as a rename meeting an edited line, and report them. Ask about any other conflict. If integrating would touch files with uncommitted changes, report the files and ask before committing, stashing, or discarding anything.

When a request may have been misheard or mistranscribed, as can happen with voice dictation, confirm destructive or hard-to-reverse actions before taking them, such as merging or deleting branches, force-pushing, or deleting files.

Keep project knowledge, such as rules, conventions, decisions, and design notes, in the project's `AGENTS.md` or documentation, not in an agent's private memory, so other people and agents that use the project see it. Use private memory only for the user's personal preferences.

A question is not a request to act. Answer it and wait for an instruction. Do not treat your own stated intention, such as "I'll go ahead", as permission. Approval of one item does not approve others.
