# ACS-002: Share projects and libraries status orchestration

Status: pending

Depends on: ACS-001

Source: [Task index](../tasks.md)

## Outcome

Replace the duplicated status flow with one small shared workflow, following
the existing sync/destructive options-object pattern.

## Acceptance checklist

- [ ] Share status argument parsing, inspection/output orchestration, and
      warning/error exit-status calculation.
- [ ] Supply domain-specific discovery, inspection, help, and empty messages
      through narrowly scoped options.
- [ ] Preserve no-fetch defaults and the existing `--fetch` behavior.
- [ ] Preserve each domain's missing-root and empty-result output.
- [ ] Keep repository layouts, names, and discovery policy in their domains.
- [ ] Reuse existing repository inspection and status formatting functions.
- [ ] Avoid adding another container layer or changing Git execution.

## Verification

Run existing projects/libs CLI, missing-root, exit-status, and repository-status
tests. Check both empty and nonempty paths, help/invalid arguments, and
inspection warnings/failures. Run the checks in the task index.
