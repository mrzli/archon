# ACTS-001: Switch JavaScript execution to Bun

Status: completed

Completed: 2026-09-06

Depends on: none

Source: [Task index](../tasks.md) and [specification](../spec.md)

## Outcome

Move runtime and test execution to Bun before changing the source language.

## Scope

Launcher, package scripts, build script, component and root runners, workspace adapter, setup build invocation, applicable instructions and usage documentation.

## Acceptance checklist

- [x] Change the executable shebang and every build invocation to Bun; preserve the named build function and complete artifact layout.
- [x] Adapt test imports and runner configuration to Bun while retaining assertions, fixtures, and environment restoration. Explicitly preserve serialization where needed.
- [x] Keep existing node:* APIs unless a reproducible incompatibility requires a focused replacement; record any such change.
- [x] Update component instructions to permit Bun and forthcoming development-only packages; replace Node-specific verification requirements with suitable Bun checks.
- [x] Confirm suite discovery and exercise the built executable, arc alias, subprocess statuses/output, local Git, and terminal attachment behavior.
- [x] Keep source in JavaScript and introduce no compiler or runtime packages in this checkpoint.

## Verification

Run the shared checkpoint checks. Compare discovered behavioral coverage with the pre-change suite; runner counts alone are not proof of equivalence. Verify both commands after copying into a temporary prefix.

## Completion record

Implemented on branch `archon-cli-bun-typescript`, after planning commit
`944bce1`. Verified with Bun 1.4.1. The launcher, package build script, setup,
component runner, workspace adapter, and installation checks now invoke Bun.
Only the executable launcher has a shebang; internal command modules do not. Runtime modules and build logic
remain JavaScript; no packages, compiler, or runtime abstractions were added.

All 18 test files now import `test` from `bun:test`; their bodies and assertions
are unchanged. The runner enumerates the same files and executes each in a
separate sequential Bun process, preserving the previous process isolation and
avoiding concurrency around environment/console mutation. Node assertion and
runtime APIs worked without replacement.

CLI fixtures launch the artifact with `process.execPath` so fake `bun` commands
on fixture PATH continue to stand in for library package operations rather than
intercepting the CLI interpreter. Workspace and temporary-installation checks
still execute the real launcher and alias through their Bun shebang.

Bun's `build --no-bundle --target=bun` parses each JavaScript file with output
discarded, replacing Node syntax checks without executing imported modules or
changing deployment output. Contributor instructions and usage/prerequisite
READMEs now reflect Bun and permit development-only tooling dependencies.

Verification:

- Baseline root suite passed: 129 Node tests, five workspace cases, and two
  build/install cases. Baseline Git subprocesses required execution outside the
  sandbox, consistent with prior verification.
- `bash tests/archon-cli/run.sh < /dev/null` passed under Bun in the sandbox.
- `bash tests/archon-cli/run.sh` with terminal stdin also passed in the sandbox.
- Both Bun runs covered 129 tests across all 18 files, five workspace cases, and
  two build/install cases. Comparing source against the planning commit confirmed
  every test body and assertion was preserved.
- `bun run --cwd components/archon-cli build` passed.
- Built and copied `archon`/`arc` passed help equivalence checks. Repeated builds,
  stale artifact removal, isolated home-overlay installation, and unrelated-file
  preservation passed through the existing installation suite.
- Bun parsing, individual Bash syntax checks (including setup), and
  `git diff --check` passed. ShellCheck was unavailable.

The installation checks simulate the scoped copy operations in temporary homes;
full setup was not executed. Node provisioning for other workstation tools was
left unchanged. ACTS-002 through ACTS-007 remain planned.

Reference: [Bun test runner](https://bun.com/docs/test) documents `.mjs` discovery,
explicit file execution, and sequential test behavior. Installed CLI help was
also checked before selecting runner and parsing flags.
