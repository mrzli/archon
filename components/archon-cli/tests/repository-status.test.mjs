import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import test from 'node:test';

import {
  withGitFixture,
  runArchon,
} from './test-helpers.mjs';

function runGit(directory, ...arguments_) {
  execFileSync('git', ['-C', directory, ...arguments_], { stdio: 'ignore' });
}

function initializeRepository(directory) {
  mkdirSync(directory, { recursive: true });
  execFileSync('git', ['init', '-q', '-b', 'main', directory]);
  runGit(directory, 'config', 'user.email', 'test@example.com');
  runGit(directory, 'config', 'user.name', 'Archon Test');
  writeFileSync(join(directory, 'tracked.txt'), 'initial\n');
  runGit(directory, 'add', 'tracked.txt');
  runGit(directory, 'commit', '-qm', 'initial');
}

function addRepositoryChanges(directory) {
  writeFileSync(join(directory, 'tracked.txt'), 'stashed\n', { flag: 'a' });
  runGit(directory, 'stash', 'push', '-qm', 'test-stash');
  writeFileSync(join(directory, 'tracked.txt'), 'unstaged\n', { flag: 'a' });
  writeFileSync(join(directory, 'staged.txt'), 'staged\n');
  writeFileSync(join(directory, 'untracked.txt'), 'untracked\n');
  runGit(directory, 'add', 'staged.txt');
}

test('status reports repository changes, errors, and fetch warnings', () => withGitFixture('repository-status', (fixture) => {
  const projectsRoot = join(fixture.home, 'projects/personal');
  const librariesRoot = join(projectsRoot, 'mrzli-jslib');
  const projectClean = join(projectsRoot, 'example/clean');
  const projectChanged = join(projectsRoot, 'example/changed');
  const libraryClean = join(librariesRoot, 'clean');
  const libraryChanged = join(librariesRoot, 'changed');

  for (const repository of [
    projectClean,
    projectChanged,
    libraryClean,
    libraryChanged,
  ]) {
    initializeRepository(repository);
  }
  addRepositoryChanges(projectChanged);
  addRepositoryChanges(libraryChanged);

  mkdirSync(join(projectsRoot, 'example/not-a-repository'), {
    recursive: true,
  });
  mkdirSync(join(projectsRoot, 'broken-owner/broken'), { recursive: true });
  mkdirSync(join(librariesRoot, 'broken'), { recursive: true });
  writeFileSync(join(projectsRoot, 'broken-owner/broken/.git'), 'broken\n');
  writeFileSync(join(librariesRoot, 'broken/.git'), 'broken\n');
  runGit(projectClean, 'remote', 'add', 'origin', join(fixture.root, 'missing'));
  runGit(libraryClean, 'remote', 'add', 'origin', join(fixture.root, 'missing'));

  for (const [domain, changedName, brokenName] of [
    ['projects', 'example/changed', 'broken-owner/broken'],
    ['libs', 'changed', 'broken'],
  ]) {
    const result = runArchon(fixture, [domain, 'status']);

    assert.equal(result.status, 1);
    assert.match(result.stdout, new RegExp(changedName));
    assert.match(result.stdout, /staged: 1, unstaged: 1, untracked: 1/);
    assert.match(result.stdout, /stash: 1/);
    assert.match(result.stdout, new RegExp(`${brokenName} +ERROR:`));
    assert.doesNotMatch(result.stdout, /not-a-repository/);

    const fetched = runArchon(fixture, [domain, 'status', '--fetch']);
    assert.equal(fetched.status, 1);
    assert.match(fetched.stdout, /warnings: fetch failed:/);
  }
}));
