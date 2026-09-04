# ARC-020: Remove the legacy workspace launchers

Status: proposed

Area: Migration cleanup

Depends on: ARC-012, ARC-013

Source: [Archon CLI implementation tasks](../tasks.md)

## Outcome

Retire all five shell launchers after the Node workspace command is complete.

## Acceptance checklist

- [ ] The five launchers are removed from the home overlay.
- [ ] The dedicated CLI migration retains those exact previously managed destination file entries.
- [ ] `projects/workspaces` is no longer a replacement directory when empty of managed content.
- [ ] The destination workspace directory and unrelated files are preserved.
- [ ] Legacy tests are retired or adapted only after equivalent Node coverage exists.

## Verification

- Test the dedicated migration with unrelated workspace-directory fixtures.
- Run the complete Node workspace suite after cleanup.
- Run setup syntax checks and `git diff --check`.
