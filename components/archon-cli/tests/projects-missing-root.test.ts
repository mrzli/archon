import assert from 'node:assert/strict';
import {
  chmodSync,
  existsSync,
  mkdirSync,
  readFileSync,
  writeFileSync,
} from 'node:fs';
import { join } from 'node:path';
import { test } from 'bun:test';

import type { Fixture } from './test-helpers.ts';
import {
  createFixture,
  removeFixture,
  runArchon,
  writeExecutable,
} from './test-helpers.ts';

const BLACKLISTED_ORGANIZATIONS: readonly string[] = [
  'mrzli-courses',
  'mrzli-gh-actions',
  'mrzli-other',
  'mrzli-vscode-extensions',
];

function installFakes(fixture: Fixture): void {
  writeExecutable(
    join(fixture.bin, 'gh'),
    `#!/usr/bin/env bash
set -u
printf '%s\n' "$*" >> "$ARCHON_TEST_GH_CALLS"
case "$*" in
  'api --hostname github.com user --jq .login')
    printf '%s\n' 'test-user'
    ;;
  *'user/memberships/orgs?state=active&per_page=100'*)
    printf '%s\n' "$ARCHON_TEST_GH_ORGS"
    ;;
  *'user/repos?affiliation=owner&visibility=all&per_page=100'*)
    ;;
  *'orgs/AlphaOrg/repos?type=all&per_page=100'*)
    printf '%s\n' "$ARCHON_TEST_GH_REPOSITORIES"
    ;;
  *)
    printf 'Unexpected fake gh invocation: %s\n' "$*" >&2
    exit 99
    ;;
esac
`,
  );
  writeExecutable(
    join(fixture.bin, 'git'),
    `#!/usr/bin/env bash
set -u
printf '%s\n' "$*" >> "$ARCHON_TEST_GIT_CALLS"
`,
  );
}

function environment(fixture: Fixture, overrides: NodeJS.ProcessEnv = {}): Readonly<NodeJS.ProcessEnv> {
  return {
    ARCHON_TEST_GH_CALLS: join(fixture.root, 'gh-calls'),
    ARCHON_TEST_GH_ORGS: [...BLACKLISTED_ORGANIZATIONS, 'AlphaOrg'].join('\n'),
    ARCHON_TEST_GH_REPOSITORIES: '',
    ARCHON_TEST_GIT_CALLS: join(fixture.root, 'git-calls'),
    ...overrides,
  };
}

function readCalls(path: string): string {
  return existsSync(path) ? readFileSync(path, 'utf8') : '';
}

for (const [command, message, githubExpected] of [
  [
    'status',
    /No local Git repositories found under .*\/projects\/personal\/<owner>\/<repository>\./,
    false,
  ],
  [
    'delete',
    /No local Git repositories found under .*\/projects\/personal\/<owner>\/<repository>\./,
    false,
  ],
  ['prune', /No obsolete local Git repositories found\./, true],
] satisfies readonly [string, RegExp, boolean][]) {
  test(`projects ${command} treats a missing root as empty`, (): void => {
    const fixture = createFixture(`projects-missing-${command}`);
    const root = join(fixture.home, 'projects/personal');
    const ghCalls = join(fixture.root, 'gh-calls');
    const gitCalls = join(fixture.root, 'git-calls');

    try {
      installFakes(fixture);
      const result = runArchon(
        fixture,
        ['projects', command],
        environment(fixture),
      );

      assert.equal(result.status, 0);
      assert.equal(result.stderr, '');
      assert.match(result.stdout, message);
      assert.equal(existsSync(root), false);
      assert.equal(readCalls(gitCalls), '');
      assert.equal(readCalls(ghCalls).length > 0, githubExpected);
    } finally {
      removeFixture(fixture);
    }
  });
}

test('projects sync creates a missing root and clones normally', (): void => {
  const fixture = createFixture('projects-missing-sync');
  const root = join(fixture.home, 'projects/personal');
  const gitCalls = join(fixture.root, 'git-calls');
  const destination = join(root, 'AlphaOrg/alpha');

  try {
    installFakes(fixture);
    const result = runArchon(
      fixture,
      ['projects', 'sync'],
      environment(fixture, {
        ARCHON_TEST_GH_REPOSITORIES:
          '1\tAlphaOrg/alpha\tgit@example:alpha.git\tfalse\tpublic',
      }),
    );

    assert.equal(result.status, 0);
    assert.equal(result.stderr, '');
    assert.equal(existsSync(root), true);
    assert.match(result.stdout, /Synchronizing 1 repositories/);
    assert.match(result.stdout, /cloned/);
    assert.equal(
      readFileSync(gitCalls, 'utf8'),
      `clone git@example:alpha.git ${destination}\n`,
    );
  } finally {
    removeFixture(fixture);
  }
});

test('projects sync help does not create a missing root', (): void => {
  const fixture = createFixture('projects-missing-sync-help');
  const root = join(fixture.home, 'projects/personal');

  try {
    const result = runArchon(fixture, ['projects', 'sync', '--help']);

    assert.equal(result.status, 0);
    assert.equal(existsSync(root), false);
  } finally {
    removeFixture(fixture);
  }
});

test('projects rejects a root that is not a directory', (): void => {
  const fixture = createFixture('projects-file-root');
  const root = join(fixture.home, 'projects/personal');

  try {
    mkdirSync(join(fixture.home, 'projects'), { recursive: true });
    writeFileSync(root, 'not a directory\n');
    const result = runArchon(fixture, ['projects', 'status']);

    assert.equal(result.status, 1);
    assert.match(result.stderr, /ENOTDIR/);
  } finally {
    removeFixture(fixture);
  }
});

test('projects rejects an unreadable existing root', (): void => {
  const fixture = createFixture('projects-unreadable-root');
  const root = join(fixture.home, 'projects/personal');

  try {
    mkdirSync(root, { recursive: true });
    chmodSync(root, 0o000);
    const result = runArchon(fixture, ['projects', 'status']);
    chmodSync(root, 0o700);

    assert.equal(result.status, 1);
    assert.match(result.stderr, /EACCES/);
  } finally {
    if (existsSync(root)) {
      chmodSync(root, 0o700);
    }
    removeFixture(fixture);
  }
});
