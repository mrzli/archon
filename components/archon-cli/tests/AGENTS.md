# Archon CLI test instructions

- Keep README.md limited to test-running commands and prerequisites. Put test
  design and fixture instructions here.
- Test behavior at the lowest layer that fully protects the contract. CLI
  tests cover wiring, output, and external command construction; focused module
  tests cover validation, ordering, and workflow policy. Do not repeat focused
  cases through the CLI unless the command boundary adds behavior.
- Preserve missing-root regression coverage and repository-status checks using
  temporary real Git repositories. Never use the real home directory, GitHub
  account, or tmux server.
- Keep detailed editor-session command sequences in `workspaces/tmux.test.mjs`.
  Group tests cover definitions, discovery, repeat behavior, and failures
  without duplicating the window-creation transcript. Adapter cases use exact
  session-set assertions. Helpers and fakes need no dedicated self-test suites.
- Keep module tests for workspace failure/routing policy and terminal
  integration tests for actual environment, stdin, and attachment wiring.
- Use `createGitEnvironment` for child processes and synchronous `withGitFixture`
  scopes for in-process real-Git workflows. `runArchon` applies the same Git
  isolation automatically. Pass intentional environment overrides explicitly.
- Keep `withGitFixture` callbacks synchronous. Do not run concurrent tests that
  change process environment within the same test process. Keep repositories
  and remotes local to temporary fixtures.
- Installation-layout tests reproduce copy operations and check imports,
  aliases, filtering, and repeated installation; they do not verify setup's
  managed-directory replacement behavior. Never run complete workstation
  setup as a test.
