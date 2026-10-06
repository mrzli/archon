# Libraries Command Instructions

- Limit operations to the supported repository layout and preserve unrelated
  user data.
- Validate dependencies and detect cycles before building; preserve
  dependency-first ordering.
- Keep dependency installation reproducible and avoid unintended lifecycle
  execution or duplicate builds.
- Separate validation and dependency policy from filesystem and process effects.
- Leave repository management (sync, status, deletion) to the projects command.
