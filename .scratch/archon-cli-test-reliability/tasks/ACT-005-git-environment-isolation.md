# ACT-005: Isolate real Git test operations

Status: completed

Area: Git fixtures and test environment

Depends on: ACT-004

Source: [Task index](../tasks.md) · [Specification](../spec.md)

## Outcome

Make real Git tests independent of personal Git configuration and inherited repository settings.

## Expected files

`components/archon-cli/tests/test-helpers.mjs`, `repository-status.test.mjs`, `sync-workflow.test.mjs`, and other real-Git test callers identified during implementation.

## Acceptance checklist

- [x] Create a small shared helper for a controlled Git test environment using temporary configuration locations.
- [x] Disable system/global configuration, hooks, and signing; set explicit fixture identity.
- [x] Remove inherited Git repository and configuration overrides while retaining intentionally supplied test settings.
- [x] Apply the environment to fixture initialization and commands executed by code under test, including in-process workflows.
- [x] Preserve required executable lookup and avoid changing real user configuration.
- [x] Use scoped restoration or a controlled test-process environment for in-process tests; add no production CLI options for testing.
- [x] Verify synthetic external signing and hook settings cannot affect commits, and a sentinel hook is never executed.
- [x] Verify inherited repository overrides cannot redirect commands to another repository.
- [x] Verify restoration and fixture cleanup after failures.
- [x] Use only temporary local repositories, without network access or personal credentials.

## Verification

- Run repository-status and synchronization tests under normal and synthetic conflicting environments.
- Verify both fixture creation and code under test receive the controlled environment.
- Run the canonical suite, changed-module syntax checks, and whitespace checks.

Completed: 2026-09-06. Shared Git environments now sanitize inherited Git
variables, disable external configuration/signing/hooks, and provide fixture
identity. Scoped real-Git fixtures restore the environment and remove temporary
files even on failure. Repository-status and sync tests passed both normally
and under synthetic signing, hook, configuration, index, and repository
overrides; no sentinel hook/signer ran or decoy index was created. The canonical
suite and Node/Bash checks passed. ShellCheck was unavailable.
