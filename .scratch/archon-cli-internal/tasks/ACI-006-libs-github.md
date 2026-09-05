# ACI-006: Extract libraries GitHub inventory logic

Status: pending

Area: Libraries architecture

Depends on: ACI-005

Source: [Archon CLI internal improvement tasks](../tasks.md)

## Outcome

Separate libraries GitHub inventory response validation from command routing
without generalizing it together with projects policy.

## Acceptance checklist

- [ ] Extract parsing, array validation, required fields, and normalization of
      `gh repo list` output.
- [ ] Expose pure validation functions needed by focused tests without adding a
      CLI API.
- [ ] Keep `gh repo list` and `gh repo clone` execution in libraries
      orchestration.
- [ ] Preserve the fixed `mrzli-jslib` owner and the current 1000-repository
      truncation safeguard.
- [ ] Preserve visibility and archive formatting.
- [ ] Preserve clone, remote, sync, prune, errors, output, and exit statuses.
- [ ] Do not introduce a shared GitHub client or service object.

## Verification

- Run focused pure response validation and normalization tests.
- Run remote, sync, prune, and clone integration contracts with fake `gh`.
- Run `tests/archon-cli/run.sh`.
- Run `node --check` on changed modules.
- Run `git diff --check`.
