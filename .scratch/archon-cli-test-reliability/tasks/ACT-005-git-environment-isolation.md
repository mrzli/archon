# ACT-005: Isolate real Git test operations

Status: pending

Area: Git fixtures and test environment

Depends on: ACT-004

Source: [Task index](../tasks.md) · [Specification](../spec.md)

## Outcome

Make real Git tests independent of personal Git configuration and inherited repository settings.

## Expected files

`components/archon-cli/tests/test-helpers.mjs`, `repository-status.test.mjs`, `sync-workflow.test.mjs`, and other real-Git test callers identified during implementation.

## Acceptance checklist

- [ ] Create a small shared helper for a controlled Git test environment using temporary configuration locations.
- [ ] Disable system/global configuration, hooks, and signing; set explicit fixture identity.
- [ ] Remove inherited Git repository and configuration overrides while retaining intentionally supplied test settings.
- [ ] Apply the environment to fixture initialization and commands executed by code under test, including in-process workflows.
- [ ] Preserve required executable lookup and avoid changing real user configuration.
- [ ] Use scoped restoration or a controlled test-process environment for in-process tests; add no production CLI options for testing.
- [ ] Verify synthetic external signing and hook settings cannot affect commits, and a sentinel hook is never executed.
- [ ] Verify inherited repository overrides cannot redirect commands to another repository.
- [ ] Verify restoration and fixture cleanup after failures.
- [ ] Use only temporary local repositories, without network access or personal credentials.

## Verification

- Run repository-status and synchronization tests under normal and synthetic conflicting environments.
- Verify both fixture creation and code under test receive the controlled environment.
- Run the canonical suite, changed-module syntax checks, and whitespace checks.

