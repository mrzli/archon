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

import {
  createFixture,
  removeFixture,
  runArchon,
  writeExecutable,
} from './test-helpers.ts';

function installFakes(fixture) {
  writeExecutable(
    join(fixture.bin, 'gh'),
    `#!/usr/bin/env bash
set -u
printf '%s\n' "$*" >> "$ARCHON_TEST_GH_CALLS"
case "$*" in
  'repo list mrzli-jslib --limit 1000 --json name,nameWithOwner,isPrivate,isArchived')
    printf '%s\n' "$ARCHON_TEST_GH_OUTPUT"
    ;;
  'repo clone '*)
    ;;
  *)
    printf 'Unexpected fake gh invocation: %s\n' "$*" >&2
    exit 99
    ;;
esac
`,
  );
  writeExecutable(
    join(fixture.bin, 'bun'),
    `#!/usr/bin/env bash
printf '%s\n' "$*" >> "$ARCHON_TEST_BUN_CALLS"
`,
  );
  writeExecutable(
    join(fixture.bin, 'git'),
    `#!/usr/bin/env bash
printf '%s\n' "$*" >> "$ARCHON_TEST_GIT_CALLS"
`,
  );
}

function environment(fixture, overrides = {}) {
  return {
    ARCHON_TEST_BUN_CALLS: join(fixture.root, 'bun-calls'),
    ARCHON_TEST_GH_CALLS: join(fixture.root, 'gh-calls'),
    ARCHON_TEST_GH_OUTPUT: '[]',
    ARCHON_TEST_GIT_CALLS: join(fixture.root, 'git-calls'),
    ...overrides,
  };
}

function readCalls(path) {
  return existsSync(path) ? readFileSync(path, 'utf8') : '';
}

for (const [command, message, githubExpected] of [
  ['status', /No local Git repositories found in .*\/mrzli-jslib\./, false],
  ['delete', /No local Git repositories found in .*\/mrzli-jslib\./, false],
  ['graph', /No local Git repositories found in .*\/mrzli-jslib\./, false],
  ['build', /No local Git repositories found in .*\/mrzli-jslib\./, false],
  ['prune', /No obsolete local Git repositories found\./, true],
]) {
  test(`libs ${command} treats a missing root as empty`, () => {
    const fixture = createFixture(`libs-missing-${command}`);
    const root = join(fixture.home, 'projects/personal/mrzli-jslib');
    const bunCalls = join(fixture.root, 'bun-calls');
    const ghCalls = join(fixture.root, 'gh-calls');
    const gitCalls = join(fixture.root, 'git-calls');

    try {
      installFakes(fixture);
      const result = runArchon(
        fixture,
        ['libs', command],
        environment(fixture),
      );

      assert.equal(result.status, 0);
      assert.equal(result.stderr, '');
      assert.match(result.stdout, message);
      assert.equal(existsSync(root), false);
      assert.equal(readCalls(bunCalls), '');
      assert.equal(readCalls(gitCalls), '');
      assert.equal(readCalls(ghCalls).length > 0, githubExpected);
    } finally {
      removeFixture(fixture);
    }
  });
}

test('libs sync creates a missing root and clones normally', () => {
  const fixture = createFixture('libs-missing-sync');
  const root = join(fixture.home, 'projects/personal/mrzli-jslib');
  const ghCalls = join(fixture.root, 'gh-calls');
  const destination = join(root, 'alpha');

  try {
    installFakes(fixture);
    const result = runArchon(
      fixture,
      ['libs', 'sync'],
      environment(fixture, {
        ARCHON_TEST_GH_OUTPUT: JSON.stringify([
          {
            isArchived: false,
            isPrivate: false,
            name: 'alpha',
            nameWithOwner: 'mrzli-jslib/alpha',
          },
        ]),
      }),
    );

    assert.equal(result.status, 0);
    assert.equal(result.stderr, '');
    assert.equal(existsSync(root), true);
    assert.match(result.stdout, /Synchronizing 1 repositories/);
    assert.match(result.stdout, /cloned/);
    assert.match(
      readFileSync(ghCalls, 'utf8'),
      new RegExp(`repo clone mrzli-jslib/alpha ${destination}`),
    );
  } finally {
    removeFixture(fixture);
  }
});

test('libs sync help does not create a missing root', () => {
  const fixture = createFixture('libs-missing-sync-help');
  const root = join(fixture.home, 'projects/personal/mrzli-jslib');

  try {
    const result = runArchon(fixture, ['libs', 'sync', '--help']);

    assert.equal(result.status, 0);
    assert.equal(existsSync(root), false);
  } finally {
    removeFixture(fixture);
  }
});

test('libs rejects a root that is not a directory', () => {
  const fixture = createFixture('libs-file-root');
  const root = join(fixture.home, 'projects/personal/mrzli-jslib');

  try {
    mkdirSync(join(fixture.home, 'projects/personal'), { recursive: true });
    writeFileSync(root, 'not a directory\n');
    const result = runArchon(fixture, ['libs', 'status']);

    assert.equal(result.status, 1);
    assert.match(result.stderr, /ENOTDIR/);
  } finally {
    removeFixture(fixture);
  }
});

test('libs rejects an unreadable existing root', () => {
  const fixture = createFixture('libs-unreadable-root');
  const root = join(fixture.home, 'projects/personal/mrzli-jslib');

  try {
    mkdirSync(root, { recursive: true });
    chmodSync(root, 0o000);
    const result = runArchon(fixture, ['libs', 'status']);
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
