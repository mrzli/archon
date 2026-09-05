
# General AI Guidelines

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:

- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:

- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:

- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:

- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:

```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

# Project-Specific Instructions

## Purpose

Archon provisions and maintains the desired state of an Omarchy/Arch Linux workstation.

- `setup.sh` is the main provisioning entry point.
- `data/home/` mirrors files that are copied into the user's home directory.
- Files present under `data/home/` are managed by this repository and may overwrite the corresponding destination files.
- Do not delete or overwrite other home-directory files unless explicitly requested.

## Repository Knowledge

Before planning or implementing a change, search `docs/` and `.scratch/` for
relevant context when those directories exist. Include hidden paths when
searching so `.scratch/` is not skipped.

- `docs/` contains durable documentation for the system's current behavior.
  Keep it consistent with implemented changes.
- `.scratch/` contains active proposals, specifications, investigations, and
  implementation tickets. Its contents may describe work that has not been
  implemented and must not be treated as current behavior without checking the
  code.
- When planned work is completed, move any enduring operational knowledge into
  `docs/` or the relevant README. Then mark the scratch document completed,
  archive it, or remove it as appropriate for the task.

## Setup Invariants

Keep `setup.sh` focused on provisioning and maintaining the current desired
state. Do not add one-time migration or cleanup steps for superseded
configurations, names, or paths. Put those operations in a separate migration
script or provide explicit manual commands instead.

`setup.sh` must remain convergent and repeat-safe.

Running it repeatedly on an already-configured machine must:

- Succeed without requiring manual cleanup.
- Converge on the same intended configuration.
- Avoid duplicate lines, entries, applications, packages, or resources.
- Tolerate resources that are already present or already absent.
- Preserve user data outside explicitly managed paths.

Exact filesystem or package state does not need to remain byte-for-byte identical. The following incidental changes are acceptable:

- Package, plugin, or tool versions may be updated.
- Package metadata and caches may be refreshed.
- Timestamps and generated metadata may change.
- Configurations or services may be reloaded.
- Equivalent output may be regenerated.

These exceptions must not cause configuration drift or accumulate duplicate state.

When adding setup operations:

- Prefer naturally idempotent package-manager and configuration commands.
- Otherwise, inspect the current state before making a change.
- Make append operations conditional.
- Give destructive operations explicit, narrowly scoped targets.
- Ensure deletion succeeds safely when the target is already absent.
- Do not generate new credentials, keys, tokens, or other identities on every run.
- Document any intentionally non-repeatable operation and obtain user approval before adding it.

## Managed Home Files

Treat `data/home/` as an overlay, not a complete home-directory replacement.

- Preserve its directory structure when adding files.
- Do not add secrets, machine-specific credentials, or private keys.
- Prefer declarative configuration files over imperative setup logic.
- If a managed file may replace an existing user file, call that out explicitly.

## Scope and Style

- Target Bash and the current Omarchy/Arch Linux environment; do not add unsupported cross-platform abstractions.
- Match the existing `setup.sh` logging and naming conventions.
- Keep changes small and directly related to the requested workstation state.
- Do not refactor unrelated provisioning steps.

## Verification

For changes to `setup.sh`:

- Run `bash -n setup.sh`.
- Run `shellcheck setup.sh` when ShellCheck is available.
- Run `git diff --check`.
- Do not execute the complete setup script merely as a test because it mutates the workstation.
- Verify individual operations with safe, focused checks where practical.

For files under `data/home/`, run the relevant syntax or configuration validation without installing them into the real home directory unless requested.
