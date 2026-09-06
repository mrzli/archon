# ACTS-004: Convert libraries command and tests

Status: completed

Completed: 2026-09-06

Depends on: ACTS-003

Source: [Task index](../tasks.md) and [specification](../spec.md)

## Outcome

Type library inventory, dependency ordering, and command behavior.

## Scope

src/commands/libs and its focused/CLI tests, including relevant cases in mixed command suites.

## Acceptance checklist

- [x] Convert library modules and their tests to TypeScript using the shared contracts.
- [x] Type package records, dependency graphs, build results, command options, and injected operations.
- [x] Narrow manifest and GitHub inventory data using existing accepted-input and failure behavior.
- [x] Preserve cycle detection, dependency-first ordering, install/build subprocess arguments, fixed roots, and destructive safeguards.
- [x] Update imports and remove only JavaScript files replaced in this batch. Track remaining library cases in mixed suites for the final audit.

## Verification

Run inventory, build ordering/cycle, missing-root, CLI, and library exit-status coverage, followed by the shared checkpoint checks.

## Completion record

ACTS-003 was committed as `121a7ad` before starting this checkpoint. ACTS-004
is implemented in the working tree, ready for the next implementation commit.

Converted all four libraries runtime modules (including the entry barrel) and
all four libraries test suites to TypeScript. Added package/graph records,
remote inventory records, command context/path types, and shared sync-result
contracts. Typed graph maps, traversal state, dependency sets, test fixtures,
malformed-input arrangements, and heterogeneous test tuples. Updated root routing,
shared root-context test imports, and installation assertions to emitted `.js`.
Other command groups remain JavaScript.

Manifest and inventory parsing start from unknown and narrow property types
using existing validation. Visibility/archive fields remain unknown because
existing formatting uses their truthiness rather than requiring booleans.
Documented non-null accesses deliberately preserve the original native errors
for JSON null inputs; the graph traversal lookup is asserted only because graph
construction guarantees all local dependency nodes exist. No blanket any,
suppressions, dependencies, compiler-policy changes, or new validation rules
were introduced.

Preserved dependency-first builds, exact cycle reporting, canonical-path
resolution, file: requirements, frozen installs without lifecycle scripts,
failure propagation, missing-root behavior, fixed paths, prune truncation and
revalidation safeguards, command help/output, and exit statuses.

Verification:

- `bun run --cwd components/archon-cli typecheck` passed.
- Full root verification passed with `/dev/null` stdin and terminal stdin:
  129 tests across the same 18 files, five workspace cases, three build/install
  cases. This includes all library inventory, invalid graph, ordering/cycle,
  build-script, CLI, missing-root, and exit-status cases.
- Compared baseline `121a7ad` sources against the converted parsers in isolated
  temporary directories: 20 inventory inputs and 13 manifest inputs returned
  identical results and error messages. Cases included null, primitive values,
  arrays, invalid/missing names, valid scoped names, invalid dependency fields,
  and nonboolean visibility/archive flags. Temporary copies were removed.
- Confirmed no library runtime module or library suite remains `.mjs`, and no
  live imports or installation assertions reference their former extensions.
- Installed JavaScript, both aliases, repeated builds, compilation-failure gates,
  and unrelated-file preservation passed through existing integration checks.
- Bun parsing, Bash syntax, and whitespace checks passed. ShellCheck was
  unavailable. No full setup or real home installation was run.

Library cases in mixed suites (exit statuses, root context, status, sync, and
destructive workflows) were already TypeScript and passed; no library cases are
left pending in JavaScript mixed suites. The three-day age gate and lockfile are
unchanged. ACTS-005 (projects) is next.
