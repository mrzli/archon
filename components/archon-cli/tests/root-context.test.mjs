import assert from 'node:assert/strict';
import { mkdirSync } from 'node:fs';
import { join } from 'node:path';
import test from 'node:test';

import { runLibraries } from '../lib/archon/commands/libs/src/index.mjs';
import { runProjects } from '../lib/archon/commands/projects/src/index.mjs';
import {
  createFixture,
  removeFixture,
} from './test-helpers.mjs';

test('projects and libraries invocations keep distinct root paths', async () => {
  const fixture = createFixture('root-context');
  const roots = {
    librariesFirst: join(fixture.root, 'libraries-first'),
    librariesSecond: join(fixture.root, 'libraries-second'),
    projectsFirst: join(fixture.root, 'projects-first'),
    projectsSecond: join(fixture.root, 'projects-second'),
  };
  const output = [];
  const originalLog = console.log;

  try {
    for (const root of Object.values(roots)) {
      mkdirSync(root);
    }

    console.log = (message) => output.push(message);

    assert.equal(
      await runProjects(['status'], { rootDir: roots.projectsFirst }),
      0,
    );
    assert.equal(
      await runProjects(['status'], { rootDir: roots.projectsSecond }),
      0,
    );
    assert.equal(
      await runLibraries(['status'], { rootDir: roots.librariesFirst }),
      0,
    );
    assert.equal(
      await runLibraries(['status'], { rootDir: roots.librariesSecond }),
      0,
    );

    assert.deepEqual(output, [
      `No local Git repositories found under ${roots.projectsFirst}/<owner>/<repository>.`,
      `No local Git repositories found under ${roots.projectsSecond}/<owner>/<repository>.`,
      `No local Git repositories found in ${roots.librariesFirst}.`,
      `No local Git repositories found in ${roots.librariesSecond}.`,
    ]);
  } finally {
    console.log = originalLog;
    removeFixture(fixture);
  }
});
