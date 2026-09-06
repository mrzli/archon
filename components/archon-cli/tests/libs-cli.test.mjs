import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { test } from 'bun:test';

import {
  createFixture,
  removeFixture,
  runArchon,
  writeExecutable,
  writeLibrary,
} from './test-helpers.mjs';

const buildScript = { scripts: { build: 'build-command' } };

function packageManifest(name, extra = {}) {
  return { name: `@mrzli-jslib/${name}`, ...buildScript, ...extra };
}

test('library graph discovers immediate repositories and every dependency field', () => {
  const fixture = createFixture('libs-graph');

  try {
    for (const name of ['dep-a', 'dep-b', 'dep-c', 'dep-d']) {
      writeLibrary(fixture, name, packageManifest(name));
    }

    writeLibrary(
      fixture,
      'app',
      packageManifest('app', {
        dependencies: { '@mrzli-jslib/dep-a': 'file:../dep-a' },
        devDependencies: { '@mrzli-jslib/dep-b': 'file:../dep-b' },
        optionalDependencies: { '@mrzli-jslib/dep-c': 'file:../dep-c' },
        peerDependencies: { '@mrzli-jslib/dep-d': 'file:../dep-d' },
      }),
    );
    writeLibrary(fixture, '.hidden', packageManifest('hidden'));
    writeLibrary(fixture, 'not-a-repository', packageManifest('ignored'), {
      git: false,
    });
    writeLibrary(
      fixture,
      'not-a-repository/nested',
      packageManifest('nested'),
    );

    const result = runArchon(fixture, ['libs', 'graph']);

    assert.equal(result.status, 0);
    assert.match(result.stdout, /^@mrzli-jslib\/hidden/m);
    assert.match(result.stdout, /^@mrzli-jslib\/app$/m);

    for (const name of ['dep-a', 'dep-b', 'dep-c', 'dep-d']) {
      assert.match(result.stdout, new RegExp(`^  -> @mrzli-jslib/${name}$`, 'm'));
    }

    assert.doesNotMatch(result.stdout, /ignored|nested/);
    assert.equal(result.stderr, '');
  } finally {
    removeFixture(fixture);
  }
});

test('library build is dependency-first and invokes exact Bun commands', () => {
  const fixture = createFixture('libs-build-order');
  const calls = join(fixture.root, 'bun-calls');

  try {
    writeLibrary(fixture, 'alpha', packageManifest('alpha', {
      dependencies: { '@mrzli-jslib/zeta': 'file:../zeta' },
    }));
    writeLibrary(fixture, 'zeta', packageManifest('zeta'));
    writeExecutable(
      join(fixture.bin, 'bun'),
      `#!/usr/bin/env bash
set -u
printf '%s\t%s\n' "$PWD" "$*" >> "$ARCHON_TEST_BUN_CALLS"
if [[ "\${ARCHON_TEST_BUN_FAIL:-}" == "$*" ]]; then
  exit 7
fi
`,
    );

    const result = runArchon(fixture, ['libs', 'build'], {
      ARCHON_TEST_BUN_CALLS: calls,
    });
    const root = join(fixture.home, 'projects/personal/mrzli-jslib');

    assert.equal(result.status, 0);
    assert.equal(result.stderr, '');
    assert.match(
      result.stdout,
      /^\[1\/2\] @mrzli-jslib\/zeta\n\[2\/2\] @mrzli-jslib\/alpha\nBuilt 2 packages\.\n$/,
    );
    assert.deepEqual(readFileSync(calls, 'utf8').trimEnd().split('\n'), [
      `${join(root, 'zeta')}\tinstall --frozen-lockfile --ignore-scripts`,
      `${join(root, 'zeta')}\trun build`,
      `${join(root, 'alpha')}\tinstall --frozen-lockfile --ignore-scripts`,
      `${join(root, 'alpha')}\trun build`,
    ]);
  } finally {
    removeFixture(fixture);
  }
});

test('library build stops after a Bun failure and reports the current contract', () => {
  const fixture = createFixture('libs-bun-failure');
  const calls = join(fixture.root, 'bun-calls');

  try {
    writeLibrary(fixture, 'alpha', packageManifest('alpha'));
    writeLibrary(fixture, 'beta', packageManifest('beta'));
    writeExecutable(
      join(fixture.bin, 'bun'),
      `#!/usr/bin/env bash
set -u
printf '%s\n' "$*" >> "$ARCHON_TEST_BUN_CALLS"
if [[ "$*" == 'run build' ]]; then
  exit 7
fi
`,
    );

    const result = runArchon(fixture, ['libs', 'build'], {
      ARCHON_TEST_BUN_CALLS: calls,
    });

    assert.equal(result.status, 1);
    assert.equal(
      result.stderr,
      '@mrzli-jslib/alpha: could not build package: Bun exited with status 7\n',
    );
    assert.deepEqual(readFileSync(calls, 'utf8').trimEnd().split('\n'), [
      'install --frozen-lockfile --ignore-scripts',
      'run build',
    ]);
  } finally {
    removeFixture(fixture);
  }
});

test('libraries list remotes with the exact GitHub command and formatting', () => {
  const fixture = createFixture('libs-github');

  try {
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
    exit 0
    ;;
  *)
    exit 99
    ;;
esac
`,
    );

    const calls = join(fixture.root, 'gh-calls');
    const valid = runArchon(fixture, ['libs', 'remote'], {
      ARCHON_TEST_GH_CALLS: calls,
      ARCHON_TEST_GH_OUTPUT: JSON.stringify([
        {
          isArchived: false,
          isPrivate: false,
          name: 'alpha',
          nameWithOwner: 'mrzli-jslib/alpha',
        },
        {
          isArchived: true,
          isPrivate: true,
          name: 'beta',
          nameWithOwner: 'mrzli-jslib/beta',
        },
      ]),
    });

    assert.equal(valid.status, 0);
    assert.equal(
      valid.stdout,
      'mrzli-jslib/alpha\nmrzli-jslib/beta  (private, archived)\n',
    );
    assert.equal(valid.stderr, '');
    assert.equal(
      readFileSync(calls, 'utf8').trim(),
      'repo list mrzli-jslib --limit 1000 --json name,nameWithOwner,isPrivate,isArchived',
    );
  } finally {
    removeFixture(fixture);
  }
});
