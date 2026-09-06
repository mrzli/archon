# Archon CLI Test Instructions

- Keep READMEs limited to test-running commands and prerequisites. Keep only
  general test-design rules here, not helper names or fixture implementation.
- Test behavior at the lowest layer that fully protects the contract. Repeat
  focused cases through the CLI only when the command boundary adds behavior.
- Check command construction and rollback at the external-operation boundary.
  Higher-level tests should use small fake objects with named operations,
  checking policy and definitions without duplicating low-level transcripts.
- Verify that injected dependencies reach real callers without falling back
  to production operations.
- Keep helpers and fakes simple; do not add dedicated self-test suites for
  test machinery.
- Use temporary roots and local fixtures. Never use real accounts, sessions,
  repositories, or the user's home directory.
- Isolate subprocess configuration from the host. Restore changed process
  environment on scope exit and serialize tests that mutate process-global
  state. Keep temporary repositories and remotes local to fixtures.
- Use terminal integration tests for behavior that depends on actual terminal
  or environment wiring.
- Preserve meaningful empty-state, repeat-safety, failure, and data-preservation
  coverage. State verification limits honestly when fixtures reproduce only
  part of a production operation.
- Never execute full workstation provisioning as a test.
