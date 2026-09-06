# ACS-005: Verify, document, and close the simplification

Status: pending

Depends on: ACS-001, ACS-002, ACS-003, ACS-004

Source: [Task index](../tasks.md)

## Outcome

Confirm a behavior-preserving simplification and document the actual resulting
boundaries before marking the proposal complete.

## Acceptance checklist

- [ ] Audit the implementation diff for less duplicated orchestration and
      simpler group fakes, without unnecessary forwarding layers.
- [ ] Confirm command/output/exit contracts, domain policies, rollback,
      deletion safeguards, and installation layout remain unchanged.
- [ ] Confirm no classes, general container, mocking framework, or deferred
      remote-formatting/build-loading work entered the implementation.
- [ ] Keep useful nested traversal functions and invocation-scoped closures.
- [ ] Update relevant AGENTS.md files to reflect final ownership and test
      guidance. Keep all READMEs usage-only; avoid claiming unimplemented
      designs as current behavior.
- [ ] Run complete verification and record results and tool limitations.
- [ ] Mark tasks and spec completed only after their acceptance criteria pass;
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
