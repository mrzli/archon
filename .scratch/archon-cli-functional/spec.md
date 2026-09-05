# Archon CLI functional improvements

Status: provisional

## Context

Archon CLI already provides the intended core command surface for personal
repositories, JavaScript libraries, and tmux workspaces. This specification
defines focused user-visible improvements to reliability, empty-state
behavior, and command conventions.

Behavior-preserving preparatory work is specified separately in
[`../archon-cli-internal/spec.md`](../archon-cli-internal/spec.md). Completing
that work first is the preferred implementation sequence because it gives
these functional changes focused module boundaries and tests. The functional
requirements do not, however, depend on a particular internal file layout.

## Goals

- Make workspace startup recover from partially completed tmux setup.
- Treat absent managed roots as normal empty or bootstrap states.
- Use consistent exit statuses for usage and operational failures.
- Preserve existing destructive-operation safeguards.

## Non-goals

- Internal module extraction or dependency-injection design.
- A plugin system or dynamic command registry.
- User-configurable project roots, workspace definitions, or GitHub policies.
- A daemon, persistent state database, or background synchronization.
- Adding npm dependencies, TypeScript, or a build step.
- Changing repository synchronization, build, graph, prune, or deletion
  semantics except where this specification says otherwise.
- Implementing optional new commands as part of the required baseline.

## Recoverable workspace creation

Creating a tmux workspace consists of creating a session and then adding and
configuring its windows. A failure after session creation can currently leave
an incomplete session that subsequent starts skip because it already exists.

Workspace creation must be failure-atomic at the session level:

1. If `new-session` fails, report failure and do not attempt cleanup.
2. If any later setup operation fails, attempt to kill the session created by
   the current invocation.
3. Report the original setup failure even if cleanup succeeds.
4. If cleanup also fails, report that failure and return nonzero.
5. A later `start` must be able to create the complete session normally.
6. Cleanup must never kill a session that existed before the invocation.

Reconciling individual windows inside an existing session is not required.
Rollback is the intended minimal behavior.

All workspace groups must continue attempting their remaining sessions after
one session fails. Aggregate workspace operations must continue attempting
their remaining groups.

### Workspace acceptance cases

Tests must cover:

- failure of `new-session` without cleanup;
- failure of each subsequent session-setup stage;
- successful cleanup after a partial failure;
- cleanup failure reporting;
- successful retry after a partial failure;
- preservation of a session that existed before the invocation;
- continued processing of later sessions and groups.

Tests must use fake tmux state and must not contact the user's real tmux
server.

## Missing managed roots

An absent fixed root is a valid state, not an unexpected exception.

Commands must behave as follows:

| Command | Required behavior when its root is absent |
| --- | --- |
| `projects status` | Report that no local repositories exist and succeed. |
| `projects delete` | Report that no local repositories exist and succeed. |
| `projects prune` | Report that no obsolete local repositories exist and succeed. |
| `projects sync` | Create the projects root as needed and continue with remote inventory and cloning. |
| `libs status` | Report that no local repositories exist and succeed. |
| `libs delete` | Report that no local repositories exist and succeed. |
| `libs prune` | Report that no obsolete local repositories exist and succeed. |
| `libs graph` | Report that no local repositories exist and succeed. |
| `libs build` | Report that no local repositories exist and succeed. |
| `libs sync` | Create the libraries root as needed and continue with remote inventory and cloning. |

Root creation must be recursive and repeat-safe. Read-only and destructive
commands must not create missing roots as a side effect.

A path that exists but cannot be read, or is not a directory, remains an
operational error. Commands must distinguish this case from an absent path.

Prune may still acquire remote inventory before concluding that there are no
local repositories if its safety model requires that ordering. It must not
create the missing root.

### Missing-root acceptance cases

Tests must cover every command category above with an absent root and verify:

- the exit status;
- the expected concise message;
- whether the root remains absent or is created;
- absence of unintended Git, GitHub, Bun, or removal operations;
- successful cloning during sync after repeat-safe root creation.

## Exit statuses

Archon CLI must use these categories consistently:

```text
0  command completed successfully
1  operational failure
2  invalid command syntax or unsupported option
```

This applies at the root dispatcher and within projects, libraries, and
workspaces.

Help requests are successful. Missing commands, unknown commands, unexpected
operands, and invalid options are usage errors. Git, GitHub, Bun, tmux,
filesystem, validation, and partial-operation failures are operational errors.

Changing existing projects and libraries usage failures from `1` to `2` is an
intentional public command-contract change. Update integration tests and any
durable documentation that describes exit statuses.

Signal termination behavior is not standardized by the current implementation.
If changed, the chosen behavior must be documented in the implementation task
and tested. The CLI must not both terminate itself from a lower-level helper
and claim that the helper returns an ordinary status result.

## Required implementation order

After the behavior-preserving internal work, implement the functional changes
as separate checkpoints:

1. Add transactional workspace rollback and retry coverage.
2. Add missing-root behavior one command domain at a time.
3. Standardize usage-error exit statuses.
4. Run the complete focused suite after every checkpoint.

The workspace fix may be implemented before the repository empty-state work;
the two behaviors are independent. Do not combine optional commands with the
required baseline.

## Optional follow-up: workspace status

A later specification may add:

```text
archon workspaces status
archon workspaces status --group <group>
```

The command would report each managed session, whether it exists, and whether
its configured directory exists. It must be read-only and must not create,
kill, attach to, or switch tmux sessions.

Dynamic JavaScript-library sessions require an explicit status policy. The
command should distinguish configured repositories without sessions from
orphaned `jslib-*` sessions without repositories.

This feature is not part of the required acceptance criteria.

## Optional follow-up: synchronization planning

A later specification may add:

```text
archon projects sync --dry-run
archon libs sync --dry-run
```

The command would obtain remote inventory and report which repositories would
be cloned, updated, or refused. A dry run must not fetch, merge, clone, create
directories, or modify remote-tracking refs.

The plan cannot guarantee that a later real sync produces the same outcome;
remote and local state may change between invocations.

This feature is not part of the required acceptance criteria.

## Documentation

When implemented:

- Update the root Archon CLI README with exit-status conventions.
- Update projects and libraries READMEs with missing-root behavior.
- Update workspace documentation with rollback behavior only if it is useful
  operational knowledge; internal cleanup mechanics need not be exposed.
- If an optional command is later implemented, update its command help and
  relevant README in the same change.

When all required work is complete, move enduring operational knowledge into
the tool READMEs and archive or remove this proposal according to the
repository's scratch-document policy.

## Verification

- Run the canonical Archon CLI suite established by the internal spec.
- Run `node --check` on every changed executable and `.mjs` file.
- Run `bash -n` on every changed Bash script.
- Run ShellCheck when available.
- Run `git diff --check`.
- Test with temporary homes, repositories, fake GitHub commands, and fake tmux
  state.
- Do not execute the complete setup script against the real home directory.
- Do not contact the user's real GitHub account or tmux server.

## Acceptance criteria

The required functional work is complete when:

- A failure after tmux session creation cannot leave an unrecoverable managed
  workspace.
- Repeating workspace start after an injected partial failure creates the full
  expected session.
- Every projects and libraries command has defined and tested absent-root
  behavior.
- Only sync creates missing managed roots.
- Usage errors consistently exit `2`; operational failures exit `1`.
- Existing destructive confirmations and inventory revalidation remain.
- Existing repository and workspace operations continue processing remaining
  independent targets after individual failures.
- Runtime installation still excludes development instructions, READMEs, and
  tests.
- The dedicated Archon CLI migration remains repeat-safe.
- `setup.sh` remains convergent and repeat-safe.
- Node and Bash syntax checks pass.
- ShellCheck passes when available.
- `git diff --check` passes.
