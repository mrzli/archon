import assert from 'node:assert/strict';
import { existsSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { test } from 'bun:test';

import type { Fixture } from './test-helpers.ts';
import type { PackageNode } from '../src/commands/libs/build.ts';
import {
  createDependencyGraph,
  orderPackagesForBuild,
  validateBuildScripts,
} from '../src/commands/libs/build.ts';
import {
  createFixture,
  removeFixture,
  writeLibrary,
} from './test-helpers.ts';

function graphNode(name: string, dependencies: readonly string[] = []): PackageNode {
  return {
    dependencies,
    manifest: { scripts: { build: 'build-command' } },
    name: `@mrzli-jslib/${name}`,
    path: `/libraries/${name}`,
  };
}

function packageManifest(name: string, extra: Record<string, unknown> = {}): { readonly name: string; } {
  return { name: `@mrzli-jslib/${name}`, ...extra };
}

function findRepositories(fixture: Fixture): readonly { readonly name: string; readonly path: string; }[] {
  const root = join(fixture.home, 'projects/personal/mrzli-jslib');

  return readdirSync(root, { withFileTypes: true })
    .filter((entry): boolean => entry.isDirectory())
    .filter((entry): boolean => existsSync(join(root, entry.name, '.git')))
    .map((entry): { readonly name: string; readonly path: string; } => ({ name: entry.name, path: join(root, entry.name) }));
}

const INVALID_GRAPH_CASES: readonly {
  readonly name: string;
  readonly arrange: (fixture: Fixture) => void;
  readonly expected: RegExp;
}[] = [
  {
    name: 'an unreadable manifest',
    arrange: (fixture): string => writeLibrary(fixture, 'app', '{ invalid json'),
    expected: /app\/package\.json could not be read/,
  },
  {
    name: 'an unscoped package name',
    arrange: (fixture): string => writeLibrary(fixture, 'app', { name: 'unscoped' }),
    expected: /must have a name in the @mrzli-jslib scope/,
  },
  {
    name: 'an invalid dependency field',
    arrange: (fixture): string =>
      writeLibrary(fixture, 'app', packageManifest('app', {
        dependencies: [],
      })),
    expected: /has an invalid dependencies field/,
  },
  {
    name: 'a non-file local dependency',
    arrange: (fixture): string =>
      writeLibrary(fixture, 'app', packageManifest('app', {
        dependencies: { '@mrzli-jslib/dep': 'workspace:*' },
      })),
    expected: /local packages must use the file: protocol/,
  },
  {
    name: 'an empty local dependency path',
    arrange: (fixture): string =>
      writeLibrary(fixture, 'app', packageManifest('app', {
        dependencies: { '@mrzli-jslib/dep': 'file:' },
      })),
    expected: /declares an empty path/,
  },
  {
    name: 'an unresolved local dependency path',
    arrange: (fixture): string =>
      writeLibrary(fixture, 'app', packageManifest('app', {
        dependencies: { '@mrzli-jslib/dep': 'file:../missing' },
      })),
    expected: /path could not be resolved/,
  },
  {
    name: 'a local dependency that is not a repository',
    arrange(fixture): void {
      writeLibrary(fixture, 'dep', packageManifest('dep'), { git: false });
      writeLibrary(fixture, 'app', packageManifest('app', {
        dependencies: { '@mrzli-jslib/dep': 'file:../dep' },
      }));
    },
    expected: /directory is not a local repository/,
  },
  {
    name: 'a mismatched local dependency name',
    arrange(fixture): void {
      writeLibrary(fixture, 'dep', packageManifest('other'));
      writeLibrary(fixture, 'app', packageManifest('app', {
        dependencies: { '@mrzli-jslib/dep': 'file:../dep' },
      }));
    },
    expected: /but that package is named @mrzli-jslib\/other/,
  },
  {
    name: 'a duplicate package name',
    arrange(fixture): void {
      writeLibrary(fixture, 'first', packageManifest('duplicate'));
      writeLibrary(fixture, 'second', packageManifest('duplicate'));
    },
    expected: /duplicate package name "@mrzli-jslib\/duplicate"/,
  },
];

test('dependency graph resolves local packages by canonical path', (): void => {
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
      graph.map(({ dependencies, name }): { readonly dependencies: readonly string[]; readonly name: string; } => ({ dependencies, name })),
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
  test(`dependency graph rejects ${case_.name}`, (): void => {
    const fixture = createFixture('libs-invalid-graph');

    try {
      case_.arrange(fixture);
      assert.throws(
        (): readonly PackageNode[] => createDependencyGraph(findRepositories(fixture)),
        case_.expected,
      );
    } finally {
      removeFixture(fixture);
    }
  });
}

test('build ordering visits dependencies before dependants', (): void => {
  const application = graphNode('application', ['@mrzli-jslib/dependency']);
  const dependency = graphNode('dependency');

  assert.deepEqual(
    orderPackagesForBuild([application, dependency]).map(({ name }): string => name),
    ['@mrzli-jslib/dependency', '@mrzli-jslib/application'],
  );
});

test('build ordering reports the exact dependency cycle', (): void => {
  const alpha = graphNode('alpha', ['@mrzli-jslib/beta']);
  const beta = graphNode('beta', ['@mrzli-jslib/alpha']);

  assert.throws(
    (): readonly PackageNode[] => orderPackagesForBuild([alpha, beta]),
    new Error(
      'dependency cycle detected: @mrzli-jslib/alpha -> @mrzli-jslib/beta -> @mrzli-jslib/alpha',
    ),
  );
});

test('build-script validation accepts only a non-empty string', (): void => {
  assert.doesNotThrow((): void => validateBuildScripts([graphNode('valid')]));

  for (const scripts of [undefined, null, [], {}, { build: '' }]) {
    const invalid = graphNode('invalid');
    invalid.manifest.scripts = scripts;

    assert.throws(
      (): void => validateBuildScripts([invalid]),
      new Error(
        '@mrzli-jslib/invalid must define a non-empty build script',
      ),
    );
  }
});
