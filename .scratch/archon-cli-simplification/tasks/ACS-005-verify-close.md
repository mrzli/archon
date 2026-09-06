# ACS-005: Verify, document, and close the simplification

Status: completed

Completed: 2026-09-06

Depends on: ACS-001, ACS-002, ACS-003, ACS-004

Source: [Task index](../tasks.md)

## Outcome

Confirm a behavior-preserving simplification and document the actual resulting
boundaries before marking the proposal complete.

## Acceptance checklist

- [x] Audit the implementation diff for less duplicated orchestration and
      simpler group fakes, without unnecessary forwarding layers.
- [x] Confirm command/output/exit contracts, domain policies, rollback,
      deletion safeguards, and installation behavior remain unchanged apart from
      the user-approved nested command layout.
- [x] Confirm no classes, general container, mocking framework, or deferred
      remote-formatting/build-loading work entered the implementation.
- [x] Keep useful nested traversal functions and invocation-scoped closures.
- [x] Confirm AGENTS.md files contain general patterns only and READMEs remain
      usage-only. Record specific implementation findings in these planning
      records; avoid claiming unimplemented designs as current behavior.
- [x] Run complete verification and record results and tool limitations.
- [x] Mark tasks and spec completed only after their acceptance criteria pass;
      retain the planning records as an archive or mark them archived.

## Verification

```bash
components/archon-cli/test.sh
bash tests/archon-cli/run.sh
bash tests/archon-cli/run.sh < /dev/null
git diff --check
```

Ensure one complete-run invocation uses terminal stdin and the other does not.
The full runner includes installation/migration and syntax checks. Run
`node --check` on changed executable/modules and report ShellCheck availability.
Do not run complete workstation setup or interact with real tmux sessions.

## Final audit

Compared the completed implementation at `4defdf1` with the pre-refactor
checkpoint `687ee62`. Runtime `.mjs` files decreased from 3,270 to 3,201 lines
(net -69), including the new barrels and shared workflows. Duplicated status
and editor-session orchestration is replaced by small shared functions;
workspace group fakes use named operations rather than command-array parsers.

Verified by source comparison:

- Projects/libs bodies are unchanged outside entry names, imports, and the
  extracted argument/status handlers.
- Build and inventory policy is unchanged apart from imports; nested graph
  traversal and invocation-scoped closures remain.
- Repository inspection and low-level shared utilities are unchanged.
  Sync/deletion changes only replace the identical help predicate with an import.
- Original tmux operations, including rollback, are unchanged. The operations
  factory binds their dependencies and preserves command construction for
  shell creation, listing, direct killing, and exact attachment.
- The root dispatcher body and executable are unchanged. Relative runtime
  imports resolve without same-directory barrel imports. Command barrels expose
  only the three entry functions; shared exports have no collisions.
- No classes, general service container, mocking framework, runtime dependency,
  or deferred remote-formatting/build-loading work was introduced.

The user approved the nested `commands/` layout and named entry functions after
this plan was created. Installation and migration prerequisite assertions now
use those paths. Setup, installation roots, Markdown exclusion, and migration
deletion targets are unchanged. This is the explicit exception to the original
requirement to preserve the internal installation layout.

READMEs contain usage documentation. AGENTS.md files contain general patterns
and reusable rules; specific architecture findings are retained here in keeping
with the user's later documentation instruction.

## Final verification

Both complete-run invocations passed on 2026-09-06:

- Terminal stdin, explicitly checked with `test -t 0` before the runner.
- Non-terminal stdin via `/dev/null`.

Each ran 129 Node tests, five workspace adapter cases, one installation-layout
case, and two migration cases with no failures. The runner also completed all
Node/Bash syntax and whitespace checks. ShellCheck was unavailable.

The suite uses isolated homes, local Git repositories, and fake external tools.
It ran outside the sandbox to permit Git subprocesses and terminal checks.
No real workstation setup or tmux sessions were used. Installation fixtures
verify copied runtime layout and repeated copying; they do not exercise full
setup's managed-directory replacement behavior. The verification does not
claim otherwise.

All planned tasks are complete. Remote formatting and build-loading separation
remain deferred. This closing documentation is uncommitted.
