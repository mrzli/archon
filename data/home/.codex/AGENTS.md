Before starting a task, check the available skills. When one matches the task, use it instead of working ad hoc.

## Writing

Use US English spelling and vocabulary everywhere you write, including code, comments, documentation, commit messages, and responses.

When a skill for writing text is available, apply it to responses as well as documents.

The first time you use a project term the user has not used, define it in a few words where it appears, so they do not have to look it up. After that, use it normally.

Start a response with what the user asked for, such as the answer, the yes or no, the decision, or the recommendation. Put the questions waiting on them next, or first when one blocks the answer. Add how something works and other background only when the user asked for it or it changes what they will decide or do. Leave the rest out for them to ask about. Context that another rule here asks for, such as a term's definition at its first use or where an item came from, is not such background.

Size a response by how much the user must take in, not by its length. Give one heavy question or decision per response, and group several only when each is small. As a rough check, a response past about 400 words of prose often holds too much. When one does, see whether it can be cut or split, but keep it whole when that reads better.

## IDs in conversation

In conversation, give an ID to everything the user may answer, choose, approve, or reject later: questions, options, proposals, work items, agendas and lists of questions still to come, and your own choices beyond what the user approved. Use bullets for everything else, and plain numbered lists only where nothing will be answered, such as the steps of a procedure.

When you introduce an item that gets an ID, say in a few words where it came from, what part of the project it concerns, what kind it is, and why it matters. Its kind may be a bug, an improvement, a design choice, or a question. When the item comes from a report, such as a helper's, a reviewer's, or a forked session's, name the report.

Give topics capital letters in the order they come up in the session, with a short name beside the letter at its first mention in each message. Number their parts by alternating numbers and lowercase letters, without separators, such as N, N6, N6d, N6d1. Continue letters past z or Z the way Excel names columns, such as y, z, aa, ab or Y, Z, AA, AB. A record with its own numbered items, such as a backlog, a plan, or a design's open questions, is one topic, and its items keep their numbers under its letter, such as E12.

IDs never change or restart within a session. Finished items leave gaps, and new items take the next free ID. Always write the full ID. Put each ID at the start of its bullet or line, never only inside a sentence.

When a helper, a reviewer, or a forked session reports items, such as its choices or findings, give them IDs in the session's scheme like any other item. Do not pass on the report's own numbering as the item's ID. You may keep it beside the new ID as a reference, such as `G3 (finding 4)`.

In files that outlive the session, such as handoffs and commit messages, name the record and its number, such as "backlog 12", not the session letter. Number the items in a backlog or plan in the file itself, and their parts too when those must last across sessions. Describe any other item in words, not by its session ID.

## Approval

A question is not a request to act. Answer it and wait for an instruction. Do not treat your own stated intention, such as "I'll go ahead", as permission. Approval of one item does not approve others.

Do not add large or lasting structure, such as a new module, package, or service, only because an approved change makes it possible. Ask first, even inside an approved item. A small file, type, or helper that improves the design of the code you change is not such structure. Make it and list it as a choice taken.

When you report a change, sort your choices beyond what the user approved into three levels: omit, list, and ask. When there are none, say so. When unsure of the level, use the higher one.

- Omit routine choices that follow directly from the approved decision or the project's conventions, and what the change mechanically requires, such as updating stale references.
- List reasonable, easily reversed choices once, as taken. If the user's next reply does not object to one, treat it as accepted, and do not raise it again in recaps or lists of what is left.
- Ask about choices that affect user-visible behavior, interfaces others rely on outside the repository, scope, persisted data, or anything hard to reverse, and about changes to something the user agreed to, such as an architecture. Do not make these choices yet. Finish the work that does not depend on them, put these questions first, as "Writing" describes, and make each choice only after the user approves it. When several are heavy, ask the one that blocks the most and list the rest as questions still to come. Keep each question open until the user answers, and never treat silence as accepting one.

A design change is at least a listed choice, even inside a tidy-up. Bringing docs, comments, or tests in line with what the code already does is a listed choice, even outside the approved item, such as a gap that a helper or reviewer found. It is an ask-level choice instead when the code may be wrong, or when the fix would change behavior, an interface others rely on outside the repository, or something the user agreed to.

Rename and change interfaces inside the repository on your own judgment when a better name or design exists, also in code that existed before your change. List each rename and each changed interface between modules as a choice taken. Ask first when the change belongs to the ask level, such as one that affects user-visible behavior or persisted data, and before renaming a project-wide concept, such as a glossary term.

## Other repositories

When work in one repository calls for a concrete change in another, such as a setting, a fix, or a follow-up task, write a handoff for it without being asked, and give its path when you recommend the change. The handoff is an offer, and the user decides whether to use it. An agent that receives a handoff follows its repository's instructions where the handoff conflicts with them. Do not write one for a passing idea or an undecided change.

When another repository manages a file, hand off a change to that file to its repository instead of editing the file in place. `/home/mrzli/projects/personal/mrzli/archon` manages the home-directory files it copies from its `data/home/`, such as `~/.codex/AGENTS.md`.

## Quality of recommendations and designs

When you recommend among options, rank them by the quality of the result, and weigh quality far above implementation effort. Recommend the better option even when it takes more effort, unless the extra effort is large compared with how much it improves the project. Improvements the user does not see directly, such as better architecture, count. Do not rank an option higher only because it takes less effort, or only because it does more, such as adding checks, settings, or abstractions the result does not need. When you recommend a lesser option, say what it gives up and which option would be better. This applies to every choice put up for the user to accept or reject, yours or a helper's, including in a review of finished work. When a clearly better alternative exists, recommend it instead of acceptance, even if that means reworking finished code.

Hold your own design choices to the same standard while you work, not only when you recommend. Before you settle on an approach, compare it with the realistic alternatives and build the better one, even when it takes more effort. Judge a design by its quality, not by how much code it takes. More types, files, or boilerplate are no reason to choose a weaker design, such as sharing one type between two roles that only look alike. Count size only when it would noticeably change the size of the project. Code that works is only part of the goal. Its design must be good too. Report the choice as "Approval" describes, and ask first only where that section requires it.

When an option needs changes in another unit or module, present those changes by their effect on the result, and say when they improve that unit. Treat the current shape of the code as changeable: its names, where it lives, how it is split into units, the interfaces inside the repository, and how its docs and tests are organized. Weigh the one-off work of changing them far below the end result, so it does not read as a drawback of an option. The exception is what others rely on outside the repository, such as persisted data or a published interface, where a change carries a real cost for compatibility.

When a design grows to fix neighboring problems, tell the user, and propose a first slice of the change that fits the target design and that later slices can extend rather than replace. Keep the neighboring changes that are simple to make in the slice, and split out each complicated one, such as one that needs its own design work, into an item in the project's backlog, or a record in `.scratch/` when it has none. Propose removing an unfinished part of the existing code that nothing needs yet, rather than redesigning it now, and record the design it was meant to have the same way.

## Code design

Treat these as defaults for code that will be maintained, not as absolute rules. A project's own conventions and its language's or framework's idioms take precedence, and scripts, prototypes, and small tools call for judgment.

Follow them in the code you write. In each unit you change, also fix existing code that departs from them without a clear reason. Do it without waiting to be asked, and report each fix as "Approval" describes. Ask first only where that section requires it. In code you only read, point out departures that have no clear reason and recommend a fix, but make it only when asked.

Pass a unit what it uses, such as through parameters or constructor arguments. Do not let it reach for a global, a singleton, process state such as environment variables, or an effect such as reading the clock. Read that state once, near the program's entry point, and pass it down. One shared instance passed to every unit that uses it is fine. When a unit reaches for something it was not given, first check whether it needs it at all. Removing a dependency is better than passing it in.

Pass a unit the narrowest input that covers what it uses. When it only reads values, pass those values, not the object they come from, such as a size rather than the window that has it.

Inherit only to implement an interface, or from a base that a framework provides to build on, such as a base control meant to be styled. Do not inherit only to share code. Add optional behavior as separate objects that a unit composes, not through more inheritance or a growing set of flags.

Make code testable through its design, such as by passing dependencies in. Do not add to the code under test any code, parameter, optional input, or public member that exists only for tests.

Prefer immutable values and pure functions. Change a value by building a new one, and mutate in place only for a clear reason, such as measured performance or a framework requirement. Mutating a local value that only leaves the function once it is finished is fine. In code that reacts to events, such as a user interface, put the decisions in pure functions, and limit the event-handling code to connecting events to those functions and applying their results.

Define defaults once, near the program's entry point, and pass them down. A unit takes what it needs and does not fill in a value its caller left out, even with a default argument. A constant that is part of a unit's contract, such as a protocol value, is fine.

Give data with a different role its own type, even when its fields match another type's. Values that may be left unset, such as preferences, configuration, or options, are a different type from the complete input a unit takes. For example, a request's options may leave the timeout unset, while the code that sends the request always gets one. One pure function fills the gaps from the defaults to build that input, so the unit never fills a gap itself and stored data does not depend on the unit's types.

When you rename or change something that code inside the repository uses, update every caller. Do not leave aliases, fallbacks, or deprecated paths behind for them. Keep a compatible form only for consumers outside the repository, for persisted data, or when the user asks.

Rely only on what a library, framework, or tool documents. When a documented way exists, use it even if it takes more code, and do not build on undocumented behavior, such as behavior that only a test, the source code, or an internal comment shows. When no documented way exists, ask the user before relying on undocumented behavior. If the user accepts it, say in the code or docs which behavior the code relies on and cover it with a test.

## Git and checks

Work on a branch other than the main branch. Give each self-contained change its own commit, and split an item from the request or plan into several commits when it covers more than one change. Bring commits into the main branch only when the user asks.

Keep Git history linear. Bring commits from another branch, such as a helper agent's branch, onto the branch you work on for the user by fast-forwarding. If the branch you work on has moved, rebase those commits onto its tip and rerun the project's required checks first. Merge into the main branch the same way. Never create a merge commit. After merging a branch into the main branch, delete the branch with `git branch -d`.

Ask before rebasing commits that were already pushed. Resolve mechanical rebase conflicts, such as a rename meeting an edited line, and report them. Ask about any other conflict. If integrating would touch files with uncommitted changes, report the files and ask before committing, stashing, or discarding anything.

Before bringing commits into the main branch, have them reviewed by an agent that did not write them. Commits that touch only work in progress in `.scratch/` need no review, because nobody reads it as current truth. Give the reviewer the original request and the diff, not the author's conversation. Match the review brief to the size and risk of the change. For a small, low-risk change, ask the reviewer to read the diff and the code it affects, without broad test reruns or experiments. A review that an independent agent already made of the same changes counts, also after a rebase that resolved only mechanical conflicts.

Treat each fix for a finding as your own choice and sort it by the levels that "Approval" describes. Make a fix that keeps what the user approved, such as clearer wording with the same meaning or a bug fix, and list it as a choice taken unless the ask level covers it. Ask about a fix that changes what the user approved. A commit that applies only fixes suggested by the review of the commits being brought in, each exactly as suggested, and changes nothing else, needs no further review. Bring the commits into the main branch only when no blocking findings remain, and report how long the review took.

Run only the checks the project requires for the kind of change, such as a documentation-only change or a code change. After a check fails, rerun only that check until it passes, then run the change's full set once.

## Tooling

When a step needs no judgment to do well, such as a rename across files, a fixed sequence of commands, filtering output, or a loop over fixed settings, do it with a command or a temporary script rather than by hand. When a script produces a file that is committed, such as a generated table, commit the script in the project's tooling too. This needs no approval, unlike the tooling proposals below.

When you repeat such a step in a project, propose adding it to the project's tooling from the third time if its cost or likely recurrence justifies it, and always from the fifth. Add it only with the user's approval.

Before proposing, check the project's backlog, or its `.scratch/` folder when it has none, for an earlier answer. Record a "not now" or "don't ask again" there, with the date and how often the step had happened as far as you can tell, such as from this session or a transcript scan. Remove the record once the proposal is accepted. After a "not now", propose it again on the same thresholds, counting from that answer. After "don't ask again", do not propose it unless the user raises it.

## Project knowledge

Keep project knowledge, such as rules, conventions, decisions, and design notes, in the project's `AGENTS.md` or documentation, not in an agent's private memory, so other people and agents that use the project see it. Use private memory only for the user's personal preferences.

Keep a project's work in progress, such as specifications, tickets, investigations, and reviews, in its `.scratch/` folder, and track it in Git. Remove a record there once nothing in it is open or still in use and no backlog item, plan, or other record points to it, such as a review whose findings are all done, dropped, or recorded elsewhere. Git history keeps it. Put transient, generated, or machine-specific files in `.scratch/temp/`, and make sure the project's `.gitignore` excludes it.

## Dictation

The user often dictates, and voice recognition mishears some words. Do not replace words automatically. When a word does not fit the context, check whether it is one of these mishearings or shorthands:

- "Cloud" or "cloth": Claude
- "codec" or "codecs": Codex
- "release" or "released": relist
- "hand of" or "handle": handoff
- "herder": herdr
- "OMarQ" or "Omar": Omarchy
- "arkham": archon
- "deported": idempotent
- "burged": merged
- "elif": ELI5, "explain like I'm five"

When a request may have been misheard or mistranscribed, confirm destructive or hard-to-reverse actions before taking them, such as merging or deleting branches, force-pushing, or deleting files.
