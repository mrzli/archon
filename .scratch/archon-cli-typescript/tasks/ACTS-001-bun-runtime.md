# ACTS-001: Switch JavaScript execution to Bun

Status: planned

Depends on: none

Source: [Task index](../tasks.md) and [specification](../spec.md)

## Outcome

Move runtime and test execution to Bun before changing the source language.

## Scope

Launcher, package scripts, build script, component and root runners, workspace adapter, setup build invocation, applicable instructions and usage documentation.

## Acceptance checklist

- [ ] Change the executable shebang and every build invocation to Bun; preserve the named build function and complete artifact layout.
- [ ] Adapt test imports and runner configuration to Bun while retaining assertions, fixtures, and environment restoration. Explicitly preserve serialization where needed.
- [ ] Keep existing node:* APIs unless a reproducible incompatibility requires a focused replacement; record any such change.
- [ ] Update component instructions to permit Bun and forthcoming development-only packages; replace Node-specific verification requirements with suitable Bun checks.
- [ ] Confirm suite discovery and exercise the built executable, arc alias, subprocess statuses/output, local Git, and terminal attachment behavior.
- [ ] Keep source in JavaScript and introduce no compiler or runtime packages in this checkpoint.

## Verification

Run the shared checkpoint checks. Compare discovered behavioral coverage with the pre-change suite; runner counts alone are not proof of equivalence. Verify both commands after copying into a temporary prefix.

## Completion record

Not started. Record changes, commands/results, compatibility findings, and any
remaining limitations here when completing the task.
