# Projects Command Instructions

- Operate only on Git repository roots at
  `~/projects/personal/<owner>/<repository>`.
- Treat other contents beneath the personal-project root as user project data;
  do not modify them unless explicitly required by the command.
- Preserve complete GitHub pagination and validate organization and repository
  blacklists before using a remote inventory.
- Keep GitHub inventory parsing, filtering, and blacklist policy in
  `src/github-inventory.mjs`; keep GitHub CLI execution and command
  orchestration in `src/projects.mjs`.
- Preserve deletion and prune dry-runs, cleanliness checks, confirmations, and
  remote-inventory revalidation.
- Keep command sections and README sections in alphabetical command order.
