import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { test } from 'bun:test';

import { withGitFixture } from './test-helpers.mjs';

import {
  createSyncFailure,
  syncRepositories,
  updateLocalRepository,
} from '../src/shared/sync-workflow.mjs';

function createOutput() {
  const errors = [];
  const output = [];
  const writes = [];
  return {
    errors,
    output,
    writes,
    print: (message) => output.push(message),
    printError: (message) => errors.push(message),
    write: (message) => writes.push(message),
  };
}

test('project and library policies produce sorted clone and update plans', () => {
  for (const kind of ['projects', 'libs']) {
    const calls = [];
    const capture = createOutput();
    const projectPolicy = kind === 'projects';
    const local = projectPolicy
      ? { name: 'zeta', nameWithOwner: 'owner/zeta' }
      : { name: 'zeta' };
    const existingRemote = projectPolicy
      ? { name: 'zeta', nameWithOwner: 'owner/zeta' }
      : { name: 'zeta' };
    const missingRemote = projectPolicy
      ? { name: 'alpha', nameWithOwner: 'owner/alpha' }
      : { name: 'alpha' };
    const getName = (repository) =>
      projectPolicy ? repository.nameWithOwner : repository.name;
    const getKey = getName;

    const status = syncRepositories([], {
      ...capture,
      cloneRepository(repository) {
        calls.push(['clone', getName(repository)]);
        return {
          message: 'cloned',
          name: getName(repository),
          succeeded: true,
        };
      },
      compareRepositories: (left, right) =>
        getName(left).localeCompare(getName(right)),
      findLocalRepositories: () => [local],
      getRemoteRepositories: () => [existingRemote, missingRemote],
      getRepositoryKey: getKey,
      getRepositoryName: getName,
      printHelp: () => {},
      updateRepository(repository) {
        calls.push(['update', getName(repository)]);
        return {
          message: 'up to date',
          name: getName(repository),
          succeeded: true,
        };
      },
    });

    const prefix = projectPolicy ? 'owner/' : '';
    assert.equal(status, 0);
    assert.deepEqual(calls, [
      ['clone', `${prefix}alpha`],
      ['update', `${prefix}zeta`],
    ]);
    assert.deepEqual(capture.output, [
      'Synchronizing 2 repositories...',
      'cloned',
      'up to date',
    ]);
    assert.deepEqual(capture.writes, [
      `[1/2] ${prefix}alpha  `,
      `[2/2] ${prefix}zeta   `,
    ]);
    assert.deepEqual(capture.errors, []);
  }
});

test('operation failures are reported and do not stop later operations', () => {
  const calls = [];
  const capture = createOutput();
  const getName = (repository) => repository.name;
  const status = syncRepositories([], {
    ...capture,
    cloneRepository(repository) {
      calls.push(['clone', repository.name]);
      return createSyncFailure(repository, 'clone failed', getName);
    },
    compareRepositories: (left, right) => left.name.localeCompare(right.name),
    findLocalRepositories: () => [{ name: 'alpha' }],
    getRemoteRepositories: () => [{ name: 'zeta' }],
    getRepositoryKey: getName,
    getRepositoryName: getName,
    printHelp: () => {},
    updateRepository(repository) {
      calls.push(['update', repository.name]);
      throw new Error('update failed');
    },
  });

  assert.equal(status, 1);
  assert.deepEqual(calls, [
    ['update', 'alpha'],
    ['clone', 'zeta'],
  ]);
  assert.deepEqual(capture.output, [
    'Synchronizing 2 repositories...',
    'ERROR: update failed',
    'ERROR: clone failed',
  ]);
});

test('local Git update reports up-to-date, updated, and dirty states', () => withGitFixture('sync', ({ root }) => {
  const remote = join(root, 'remote.git');
  const local = join(root, 'local');
  const contributor = join(root, 'contributor');
  const runGit = (directory, ...arguments_) =>
    execFileSync('git', ['-C', directory, ...arguments_], { stdio: 'ignore' });

  execFileSync(
    'git',
    ['init', '--bare', '--initial-branch=main', remote],
    { stdio: 'ignore' },
  );
  execFileSync('git', ['clone', remote, local], { stdio: 'ignore' });
  runGit(local, 'config', 'user.email', 'test@example.com');
  runGit(local, 'config', 'user.name', 'Archon Test');
  writeFileSync(join(local, 'tracked.txt'), 'initial\n');
  runGit(local, 'add', 'tracked.txt');
  runGit(local, 'commit', '-m', 'initial');
  runGit(local, 'push', '--set-upstream', 'origin', 'main');

  const repository = { name: 'example', path: local };
  const getName = (repository_) => repository_.name;
  assert.deepEqual(updateLocalRepository(repository, getName), {
    message: '[main -> origin/main]  up to date',
    name: 'example',
    succeeded: true,
  });

  execFileSync('git', ['clone', remote, contributor], { stdio: 'ignore' });
  runGit(contributor, 'config', 'user.email', 'test@example.com');
  runGit(contributor, 'config', 'user.name', 'Archon Test');
  writeFileSync(join(contributor, 'remote.txt'), 'remote\n');
  runGit(contributor, 'add', 'remote.txt');
  runGit(contributor, 'commit', '-m', 'remote');
  runGit(contributor, 'push');

  assert.deepEqual(updateLocalRepository(repository, getName), {
    message: '[main -> origin/main]  updated',
    name: 'example',
    succeeded: true,
  });

  writeFileSync(join(local, 'untracked.txt'), 'dirty\n');
  assert.deepEqual(updateLocalRepository(repository, getName), {
    message: 'ERROR: working tree is not clean (untracked: 1)',
    name: 'example',
    succeeded: false,
  });
}));
