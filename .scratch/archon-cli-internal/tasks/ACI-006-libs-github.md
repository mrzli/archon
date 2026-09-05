# ACI-006: Extract libraries GitHub inventory logic

Status: completed

Completed: 2026-09-05

Area: Libraries architecture

Depends on: ACI-005

Source: [Archon CLI internal improvement tasks](../tasks.md)

## Outcome

Separate libraries GitHub inventory response validation from command routing
without generalizing it together with projects policy.

## Acceptance checklist

- [x] Extract parsing, array validation, required fields, and normalization of
      `gh repo list` output.
- [x] Expose pure validation functions needed by focused tests without adding a
      CLI API.
- [x] Keep `gh repo list` and `gh repo clone` execution in libraries
      orchestration.
- [x] Preserve the fixed `mrzli-jslib` owner and the current 1000-repository
      truncation safeguard.
- [x] Preserve visibility and archive formatting.
- [x] Preserve clone, remote, sync, prune, errors, output, and exit statuses.
- [x] Do not introduce a shared GitHub client or service object.

## Verification

- Run focused pure response validation and normalization tests.
- Run remote, sync, prune, and clone integration contracts with fake `gh`.
- Run `tests/archon-cli/run.sh`.
- Run `node --check` on changed modules.
- Run `git diff --check`.

Completed by moving JSON parsing, array validation, required repository-name
validation, and inventory record normalization into
`libs/src/github-inventory.mjs`. `libs.mjs` retains `gh repo list` and
`gh repo clone` execution, fixed-owner policy, truncation protection, output
formatting, and command orchestration. Four focused tests cover normalization,
invalid JSON and top-level values, missing name fields, and the current handling
of other fields. All 59 Node tests and all 15 shell-suite checks pass. Node and
Bash syntax checks and `git diff --check` pass; ShellCheck is unavailable.
