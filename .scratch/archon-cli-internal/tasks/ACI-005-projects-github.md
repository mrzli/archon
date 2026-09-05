# ACI-005: Extract projects GitHub inventory logic

Status: pending

Area: Projects architecture

Depends on: ACI-004

Source: [Archon CLI internal improvement tasks](../tasks.md)

## Outcome

Separate projects GitHub inventory policy and pure response validation from
CLI routing while retaining the existing `gh`-based orchestration.

## Acceptance checklist

- [ ] Extract GitHub repository row parsing and normalization.
- [ ] Extract organization and canonical repository blacklist validation.
- [ ] Extract case-insensitive repository keys, deduplication, and inventory
      filtering where they form part of the same domain unit.
- [ ] Keep `gh` execution, progress output, and endpoint sequencing in explicit
      effectful orchestration.
- [ ] Preserve authenticated-user and owned-organization discovery.
- [ ] Preserve complete pagination and all current endpoints and query fields.
- [ ] Preserve case-insensitive blacklist semantics and strict validation.
- [ ] Preserve remote listing, sync, prune, errors, output, and exit statuses.
- [ ] Do not share this policy with libraries merely because both use GitHub.

## Verification

- Run focused pure parsing, validation, deduplication, and filtering tests.
- Run remote, sync, and prune integration contracts with fake `gh`.
- Run `tests/archon-cli/run.sh`.
- Run `node --check` on changed modules.
- Run `git diff --check`.
