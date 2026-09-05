# ACI-005: Extract projects GitHub inventory logic

Status: completed

Completed: 2026-09-05

Area: Projects architecture

Depends on: ACI-004

Source: [Archon CLI internal improvement tasks](../tasks.md)

## Outcome

Separate projects GitHub inventory policy and pure response validation from
CLI routing while retaining the existing `gh`-based orchestration.

## Acceptance checklist

- [x] Extract GitHub repository row parsing and normalization.
- [x] Extract organization and canonical repository blacklist validation.
- [x] Extract case-insensitive repository keys, deduplication, and inventory
      filtering where they form part of the same domain unit.
- [x] Keep `gh` execution, progress output, and endpoint sequencing in explicit
      effectful orchestration.
- [x] Preserve authenticated-user and owned-organization discovery.
- [x] Preserve complete pagination and all current endpoints and query fields.
- [x] Preserve case-insensitive blacklist semantics and strict validation.
- [x] Preserve remote listing, sync, prune, errors, output, and exit statuses.
- [x] Do not share this policy with libraries merely because both use GitHub.

## Verification

- Run focused pure parsing, validation, deduplication, and filtering tests.
- Run remote, sync, and prune integration contracts with fake `gh`.
- Run `tests/archon-cli/run.sh`.
- Run `node --check` on changed modules.
- Run `git diff --check`.

Completed by moving projects-specific GitHub row parsing, case-insensitive
keys and comparison, deduplication, local exclusion policy, and blacklist
validation into `projects/src/github-inventory.mjs`. `projects.mjs` retains all
`gh` execution, progress output, endpoint ordering, pagination, and inventory
orchestration. Six focused tests cover valid and invalid rows, keys, ordering,
deduplication, filtering, lookup planning, canonical repositories, and the
complete blacklist error contract. All 55 Node tests and all 15 shell-suite
checks pass. Node and Bash syntax checks and `git diff --check` pass;
ShellCheck is unavailable.
