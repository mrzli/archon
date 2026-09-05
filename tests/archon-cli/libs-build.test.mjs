import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createDependencyGraph,
  orderPackagesForBuild,
  validateBuildScripts,
} from '../../data/home/.local/lib/archon/libs/src/build.mjs';
import {
  createFixture,
  removeFixture,
  writeLibrary,
} from './characterization-helpers.mjs';

function graphNode(name, dependencies = []) {
  return {
    dependencies,
    manifest: { scripts: { build: 'build-command' } },
    name: `@mrzli-jslib/${name}`,
    path: `/libraries/${name}`,
  };
}

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
