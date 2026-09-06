# ACTS-005: Convert projects command and tests

Status: completed

Completed: 2026-09-06

Depends on: ACTS-004

Source: [Task index](../tasks.md) and [specification](../spec.md)

## Outcome

Type project inventory and repository workflows without changing behavior.

## Scope

src/commands/projects and its focused/CLI tests, including relevant cases in mixed command suites.

## Acceptance checklist

- [x] Convert project modules and their tests to TypeScript using the shared contracts.
- [x] Type inventory records, options, and injected operations; narrow external values with existing validation.
- [x] Preserve pagination, filtering/exclusions, fixed roots, missing-root behavior, subprocess arguments, and shared workflow semantics.
- [x] Preserve confirmation, cleanliness, deletion, and remote-state safeguards.
- [x] Update imports and remove only replaced JavaScript files; retain working workspace and CLI callers.

## Verification

Run inventory, missing-root, project CLI and exit-status tests plus applicable sync/destructive coverage, followed by the shared checkpoint checks.

## Completion record

ACTS-004 was committed as `16104dc` before starting this checkpoint. ACTS-005
is implemented in the working tree, ready for the next implementation commit.

Converted all three projects runtime modules (including the entry barrel) and
all three project test suites to TypeScript. Typed repository identity, remote
and local records, blacklist policy, command context/paths, inventory maps/sets,
and progress callbacks. Reused shared sync-result and workflow contracts.
External repository rows remain strings from GitHub CLI TSV output and retain
their existing field validation; no new parsing or exclusion rules were added.

Updated root routing and shared root-context test imports and installation
assertions to emitted `.js`. Fixture helpers now use the shared Fixture and
process-environment types. Missing-root scenarios specify their heterogeneous
tuple shape, and the inventory test uses a typed map with an optional lookup
that still must equal the expected repository name. All existing assertions,
fake command behavior, and isolation remain intact.

Preserved pagination flags, case-insensitive deduplication/order, owned-organization
selection, canonical exclusion checks and exact validation messages, fixed roots,
clone destinations and argument arrays, missing-directory behavior, confirmation,
cleanliness/deletion safeguards, and refreshed remote-state checks. Caught
filesystem errors are narrowed from unknown; spawn error codes are checked for
presence. The one non-null map lookup follows an existing has/continue guard and
is documented. No any annotations, suppressions, new dependencies, or runtime
refactors were introduced.

Verification:

- `bun run --cwd components/archon-cli typecheck` passed with strict settings.
- Full root verification passed with `/dev/null` stdin and terminal stdin:
  129 tests across 18 files, five workspace cases, and three build/install cases.
- Coverage includes normalized/incomplete TSV rows, exclusion ownership and
  aggregate errors, case-insensitive keys, paginated/deduplicated CLI inventory,
  missing-root handling, clone failures, shared sync/destructive safeguards,
  and all project usage/exit-status cases.
- Checked that no project runtime module or project suite remains `.mjs` and
  live imports/installation assertions use the new extensions. Workspace and
  root CLI callers continue working through the emitted JavaScript artifact.
- Repeat builds, compilation-failure gates, both executable aliases, repeated
  isolated installation, and unrelated-file preservation passed.
- Bun parsing, Bash syntax, and whitespace checks passed. ShellCheck was
  unavailable. Full setup and real home installation were not executed.

Project cases in mixed suites were already TypeScript and passed. The three-day
dependency release-age policy and lockfile remain unchanged. ACTS-006
(workspaces) is next.
