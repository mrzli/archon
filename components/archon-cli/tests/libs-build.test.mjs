import assert from 'node:assert/strict';
import { existsSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import test from 'node:test';

import {
  createDependencyGraph,
  orderPackagesForBuild,
  validateBuildScripts,
} from '../lib/archon/libs/src/build.mjs';
import {
  createFixture,
  removeFixture,
  writeLibrary,
} from './test-helpers.mjs';

function graphNode(name, dependencies = []) {
  return {
    dependencies,
    manifest: { scripts: { build: 'build-command' } },
    name: `@mrzli-jslib/${name}`,
    path: `/libraries/${name}`,
  };
}

function packageManifest(name, extra = {}) {
  return { name: `@mrzli-jslib/${name}`, ...extra };
}

function findRepositories(fixture) {
  const root = join(fixture.home, 'projects/personal/mrzli-jslib');

  return readdirSync(root, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .filter((entry) => existsSync(join(root, entry.name, '.git')))
    .map((entry) => ({ name: entry.name, path: join(root, entry.name) }));
}

const INVALID_GRAPH_CASES = [
  {
    name: 'an unreadable manifest',
    arrange: (fixture) => writeLibrary(fixture, 'app', '{ invalid json'),
    expected: /app\/package\.json could not be read/,
  },
  {
    name: 'an unscoped package name',
    arrange: (fixture) => writeLibrary(fixture, 'app', { name: 'unscoped' }),
    expected: /must have a name in the @mrzli-jslib scope/,
  },
  {
    name: 'an invalid dependency field',
    arrange: (fixture) =>
      writeLibrary(fixture, 'app', packageManifest('app', {
        dependencies: [],
      })),
    expected: /has an invalid dependencies field/,
  },
  {
    name: 'a non-file local dependency',
    arrange: (fixture) =>
      writeLibrary(fixture, 'app', packageManifest('app', {
        dependencies: { '@mrzli-jslib/dep': 'workspace:*' },
      })),
    expected: /local packages must use the file: protocol/,
  },
  {
    name: 'an empty local dependency path',
    arrange: (fixture) =>
      writeLibrary(fixture, 'app', packageManifest('app', {
        dependencies: { '@mrzli-jslib/dep': 'file:' },
      })),
    expected: /declares an empty path/,
  },
  {
    name: 'an unresolved local dependency path',
    arrange: (fixture) =>
      writeLibrary(fixture, 'app', packageManifest('app', {
        dependencies: { '@mrzli-jslib/dep': 'file:../missing' },
      })),
    expected: /path could not be resolved/,
  },
  {
    name: 'a local dependency that is not a repository',
    arrange(fixture) {
      writeLibrary(fixture, 'dep', packageManifest('dep'), { git: false });
      writeLibrary(fixture, 'app', packageManifest('app', {
        dependencies: { '@mrzli-jslib/dep': 'file:../dep' },
      }));
    },
    expected: /directory is not a local repository/,
  },
  {
    name: 'a mismatched local dependency name',
    arrange(fixture) {
      writeLibrary(fixture, 'dep', packageManifest('other'));
      writeLibrary(fixture, 'app', packageManifest('app', {
        dependencies: { '@mrzli-jslib/dep': 'file:../dep' },
      }));
    },
    expected: /but that package is named @mrzli-jslib\/other/,
  },
  {
    name: 'a duplicate package name',
    arrange(fixture) {
      writeLibrary(fixture, 'first', packageManifest('duplicate'));
      writeLibrary(fixture, 'second', packageManifest('duplicate'));
    },
    expected: /duplicate package name "@mrzli-jslib\/duplicate"/,
  },
];

test('dependency graph resolves local packages by canonical path', () => {
  const fixture = createFixture('libs-build-graph');

  try {
    const dependency = writeLibrary(fixture, 'dependency', {
      name: '@mrzli-jslib/dependency',
    });
    const application = writeLibrary(fixture, 'application', {
      dependencies: {
        '@mrzli-jslib/dependency': 'file:../dependency',
      },
      name: '@mrzli-jslib/application',
    });
    const graph = createDependencyGraph([
      { name: 'application', path: application },
      { name: 'dependency', path: dependency },
    ]);

    assert.deepEqual(
      graph.map(({ dependencies, name }) => ({ dependencies, name })),
      [
        {
          dependencies: ['@mrzli-jslib/dependency'],
          name: '@mrzli-jslib/application',
        },
        {
          dependencies: [],
          name: '@mrzli-jslib/dependency',
        },
      ],
    );
  } finally {
    removeFixture(fixture);
  }
});

for (const case_ of INVALID_GRAPH_CASES) {
  test(`dependency graph rejects ${case_.name}`, () => {
    const fixture = createFixture('libs-invalid-graph');

    try {
      case_.arrange(fixture);
      assert.throws(
        () => createDependencyGraph(findRepositories(fixture)),
        case_.expected,
      );
    } finally {
      removeFixture(fixture);
    }
  });
}

test('build ordering visits dependencies before dependants', () => {
  const application = graphNode('application', ['@mrzli-jslib/dependency']);
  const dependency = graphNode('dependency');

  assert.deepEqual(
    orderPackagesForBuild([application, dependency]).map(({ name }) => name),
    ['@mrzli-jslib/dependency', '@mrzli-jslib/application'],
  );
});

test('build ordering reports the exact dependency cycle', () => {
  const alpha = graphNode('alpha', ['@mrzli-jslib/beta']);
  const beta = graphNode('beta', ['@mrzli-jslib/alpha']);

  assert.throws(
    () => orderPackagesForBuild([alpha, beta]),
    new Error(
      'dependency cycle detected: @mrzli-jslib/alpha -> @mrzli-jslib/beta -> @mrzli-jslib/alpha',
    ),
  );
});

test('build-script validation accepts only a non-empty string', () => {
  assert.doesNotThrow(() => validateBuildScripts([graphNode('valid')]));

  for (const scripts of [undefined, null, [], {}, { build: '' }]) {
    const invalid = graphNode('invalid');
    invalid.manifest.scripts = scripts;

    assert.throws(
      () => validateBuildScripts([invalid]),
      new Error(
        '@mrzli-jslib/invalid must define a non-empty build script',
      ),
    );
  }
});
