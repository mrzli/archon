import assert from 'node:assert/strict';
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import test from 'node:test';

import {
  createFixture,
  removeFixture,
  runArchon,
  writeExecutable,
  writeLibrary,
} from './characterization-helpers.mjs';

const buildScript = { scripts: { build: 'build-command' } };

function packageManifest(name, extra = {}) {
  return { name: `@mrzli-jslib/${name}`, ...buildScript, ...extra };
}

function assertFailure(result, message) {
  assert.equal(result.status, 1);
  assert.match(result.stderr, message);
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

test('library graph preserves current manifest and dependency validation errors', () => {
  const cases = [
    {
      arrange(fixture) {
        writeLibrary(fixture, 'app', '{ invalid json');
      },
      expected: /app\/package\.json could not be read/,
    },
    {
      arrange(fixture) {
        writeLibrary(fixture, 'app', { name: 'unscoped' });
      },
      expected: /must have a name in the @mrzli-jslib scope/,
    },
    {
      arrange(fixture) {
        writeLibrary(
          fixture,
          'app',
          packageManifest('app', { dependencies: [] }),
        );
      },
      expected: /has an invalid dependencies field/,
    },
    {
      arrange(fixture) {
        writeLibrary(
          fixture,
          'app',
          packageManifest('app', {
            dependencies: { '@mrzli-jslib/dep': 'workspace:\*' },
          }),
        );
      },
      expected: /local packages must use the file: protocol/,
    },
    {
      arrange(fixture) {
        writeLibrary(
          fixture,
          'app',
          packageManifest('app', {
            dependencies: { '@mrzli-jslib/dep': 'file:' },
          }),
        );
      },
      expected: /declares an empty path/,
    },
    {
      arrange(fixture) {
        writeLibrary(
          fixture,
          'app',
          packageManifest('app', {
            dependencies: { '@mrzli-jslib/dep': 'file:../missing' },
          }),
        );
      },
      expected: /path could not be resolved/,
    },
    {
      arrange(fixture) {
        writeLibrary(fixture, 'dep', packageManifest('dep'), { git: false });
        writeLibrary(
          fixture,
          'app',
          packageManifest('app', {
            dependencies: { '@mrzli-jslib/dep': 'file:../dep' },
          }),
        );
      },
      expected: /directory is not a local repository/,
    },
    {
      arrange(fixture) {
        writeLibrary(fixture, 'dep', packageManifest('other'));
        writeLibrary(
          fixture,
          'app',
          packageManifest('app', {
            dependencies: { '@mrzli-jslib/dep': 'file:../dep' },
          }),
        );
      },
      expected: /but that package is named @mrzli-jslib\/other/,
    },
    {
      arrange(fixture) {
        writeLibrary(fixture, 'first', packageManifest('duplicate'));
        writeLibrary(fixture, 'second', packageManifest('duplicate'));
      },
      expected: /duplicate package name "@mrzli-jslib\/duplicate"/,
    },
  ];

  for (const [index, case_] of cases.entries()) {
    const fixture = createFixture(`libs-validation-${index}`);

    try {
      case_.arrange(fixture);
      assertFailure(runArchon(fixture, ['libs', 'graph']), case_.expected);
    } finally {
      removeFixture(fixture);
    }
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

test('library build rejects cycles and missing build scripts before running Bun', () => {
  const cycle = createFixture('libs-cycle');

  try {
    writeLibrary(cycle, 'alpha', packageManifest('alpha', {
      dependencies: { '@mrzli-jslib/beta': 'file:../beta' },
    }));
    writeLibrary(cycle, 'beta', packageManifest('beta', {
      dependencies: { '@mrzli-jslib/alpha': 'file:../alpha' },
    }));
    assertFailure(
      runArchon(cycle, ['libs', 'build']),
      /dependency cycle detected: @mrzli-jslib\/alpha -> @mrzli-jslib\/beta -> @mrzli-jslib\/alpha/,
    );
  } finally {
    removeFixture(cycle);
  }

  const missingScript = createFixture('libs-missing-build');

  try {
    writeLibrary(missingScript, 'alpha', { name: '@mrzli-jslib/alpha' });
    assertFailure(
      runArchon(missingScript, ['libs', 'build']),
      /@mrzli-jslib\/alpha must define a non-empty build script/,
    );
  } finally {
    removeFixture(missingScript);
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

test('libraries validates GitHub output and preserves remote formatting', () => {
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

    for (const output of ['{}', '[{"name":"alpha"}]', 'not-json']) {
      writeFileSync(calls, '');
      assertFailure(
        runArchon(fixture, ['libs', 'remote'], {
          ARCHON_TEST_GH_CALLS: calls,
          ARCHON_TEST_GH_OUTPUT: output,
        }),
        /Could not read GitHub CLI output:/,
      );
    }
  } finally {
    removeFixture(fixture);
  }
});

test('libraries sync preserves GitHub clone construction', () => {
  const fixture = createFixture('libs-clone');
  const calls = join(fixture.root, 'gh-calls');

  try {
    writeLibrary(fixture, 'placeholder', undefined, { git: false });
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
    const remote = JSON.stringify([
      {
        isArchived: false,
        isPrivate: false,
        name: 'alpha',
        nameWithOwner: 'mrzli-jslib/alpha',
      },
    ]);
    const result = runArchon(fixture, ['libs', 'sync'], {
      ARCHON_TEST_GH_CALLS: calls,
      ARCHON_TEST_GH_OUTPUT: remote,
    });
    const destination = join(
      fixture.home,
      'projects/personal/mrzli-jslib/alpha',
    );

    assert.equal(result.status, 0);
    assert.match(result.stdout, /Synchronizing 1 repositories/);
    assert.match(result.stdout, /cloned/);
    assert.match(
      readFileSync(calls, 'utf8'),
      new RegExp(`repo clone mrzli-jslib/alpha ${destination}`),
    );
  } finally {
    removeFixture(fixture);
  }
});

test('libraries usage errors use the standard status', () => {
  const fixture = createFixture('libs-usage');

  try {
    const result = runArchon(fixture, ['libs', 'build', '--unexpected']);

    assert.equal(result.status, 2);
    assert.equal(result.stderr, 'Unexpected build option: --unexpected\n');
    assert.match(result.stdout, /^Usage: archon libs build \[options\]/);
  } finally {
    removeFixture(fixture);
  }
});
