# Archon CLI test pruning

Status: proposed

Created: 2026-09-06

Implementation plan: [Tasks](./tasks.md)

## Purpose

Reduce maintenance cost by removing tests of test machinery, duplicated
assertions, repeated command transcripts, and checks of incidental behavior.
This follows the user's request for a pruning-only pass after the previous
test-reliability work. It does not reopen the reverted installation extraction.

## Hard constraints

- Do not change production code under any circumstances. This includes
  `setup.sh`, runtime modules, executables, managed home files, installation
  scripts, and configuration.
- Do not add new tests, test cases, scenarios, or test files.
- Permitted implementation work is deletion, cleanup, and simplification of
  existing tests and their now-unused support code.
- Do not compensate for removed tests with new abstractions, dependencies,
  fixture frameworks, or production test hooks.
- Existing assertions may be simplified within retained cases; do not expand
  their behavioral scope.
- Limit documentation changes to keeping the test README and this planning
  record accurate.
- Preserve unrelated changes. Never run full workstation setup, use the real
  tmux server, or operate on real user repositories as a test.

## Pruning decisions

1. Remove `git-environment.test.mjs`. Its synthetic hooks, signing tool,
   configuration, decoy repository, nested test runs, and helper-only assertions
   are disproportionate to this suite. Keep Git isolation helpers and existing
   real Git workflow tests.
2. Remove the simulated managed-library replacement case from the installation
   tests. It removes the directory itself and therefore does not verify setup's
   replacement implementation. Keep the repeated-install layout case.
3. Remove the adapter case that directly tests fake tmux target validation.
   Keep that validation in the fake and retain real CLI attachment cases.
4. Remove individual adapter session assertions already implied by exact
   session-set equality, and delete the resulting unused assertion helpers.
5. Reduce editor-command transcripts repeated across flashcards, jslibs, and
   miscellaneous-project group tests. Keep distinctive group behavior and
   detailed shared-helper coverage.
6. Trim overlapping help/alias combinations while retaining success and
   forwarding checks. Preserve separately implemented parser validation and
   operational failure coverage.
7. Remove the library inventory case that pins empty names and undefined flags.
   Keep normal parsing and invalid-input rejection.

## Coverage to retain

Keep existing deletion safeguards, partial-session rollback, repeat-safe
operations, repository discovery, dependency ordering/cycles, error propagation,
and actual terminal attachment checks. Do not remove these merely to reduce a
test count.

A passing reduced suite does not prove that deleted coverage was redundant.
The decisions above explicitly accept the listed coverage reductions. The
review must establish what remains protected and what is intentionally omitted.

## Execution

Follow the task index. Two closely related adapter recommendations share one
task; each other pruning area has its own task. Use one commit per task, keeping
production files out of every commit. Do not modify archived earlier proposals
to make them appear to have originally specified these reductions.

## Verification and completion

Use only existing test commands and validation tools. Run relevant existing
tests after each pruning checkpoint, then the complete
`tests/archon-cli/run.sh` suite with and without terminal stdin at the final
checkpoint. The complete runner includes the component suite and syntax checks.
Run ShellCheck when available and explicitly record an unavailable tool.

Audit the final diff against the starting commit: all code changes must be in
test paths, no production changes or added tests may be present, and test code
must have a net reduction. Record the actual reduction without a numerical
target. Update test documentation, record verification results and limitations,
and mark this plan completed only after implementation and checks finish.
