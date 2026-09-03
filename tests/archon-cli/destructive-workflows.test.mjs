import assert from 'node:assert/strict';
import test from 'node:test';

import {
  confirmRepositoryDeletion,
  deleteRepositories,
  pruneRepositories,
  removeLocalRepositories,
} from '../../data/home/.local/lib/archon/shared/destructive-workflows.mjs';

const repositories = [{ name: 'obsolete', path: '/safe/obsolete' }];

async function captureConsole(run) {
  const errors = [];
  const output = [];
  const originalError = console.error;
  const originalLog = console.log;
  console.error = (message) => errors.push(message);
  console.log = (message) => output.push(message);

  try {
    return { errors, output, result: await run() };
  } finally {
    console.error = originalError;
    console.log = originalLog;
  }
}

function createDeleteOptions(overrides = {}) {
  return {
    confirmDeletion: async () => true,
    emptyMessage: 'No repositories.',
    findRepositories: () => repositories,
    inspectRepositories: () => [],
    printHelp: () => console.log('delete help'),
    removeRepositories: () => 0,
    requiredRootDir: '/safe',
    rootDir: '/safe',
    ...overrides,
  };
}

function createPruneOptions(overrides = {}) {
  return {
    confirmDeletion: async () => true,
    findPrunableRepositories: () => repositories,
    findRestoredRepositories: () => [],
    getRemoteRepositories: () => [],
    getRepositoryName: (repository) => repository.name,
    inspectRepositories: () => [],
    printHelp: () => console.log('prune help'),
    removeRepositories: () => 0,
    requiredRootDir: '/safe',
    rootDir: '/safe',
    ...overrides,
  };
}

test('invalid arguments and unsafe roots are refused before discovery', async () => {
  let discovered = false;
  const invalid = await captureConsole(() =>
    deleteRepositories(
      ['--invalid'],
      createDeleteOptions({
        findRepositories() {
          discovered = true;
          return repositories;
        },
      }),
    ),
  );
  assert.equal(invalid.result, 1);
  assert.deepEqual(invalid.errors, ['Unexpected delete option: --invalid']);
  assert.deepEqual(invalid.output, ['delete help']);
  assert.equal(discovered, false);

  const unsafe = await captureConsole(() =>
    deleteRepositories(
      ['--dry-run'],
      createDeleteOptions({ rootDir: '/unexpected' }),
    ),
  );
  assert.equal(unsafe.result, 1);
  assert.deepEqual(unsafe.errors, [
    'Refusing to delete: unexpected operation root: /unexpected',
    'Expected operation root: /safe',
  ]);
});

test('delete dry-run lists repositories without confirmation or removal', async () => {
  let confirmed = false;
  let removed = false;
  const capture = await captureConsole(() =>
    deleteRepositories(
      ['-n'],
      createDeleteOptions({
        confirmDeletion: async () => {
          confirmed = true;
          return true;
        },
        removeRepositories: () => {
          removed = true;
          return 0;
        },
      }),
    ),
  );

  assert.equal(capture.result, 0);
  assert.equal(confirmed, false);
  assert.equal(removed, false);
  assert.deepEqual(capture.output, [
    'Dry run; the following directories would be deleted:',
    '  /safe/obsolete',
  ]);
});

test('confirmation refuses non-interactive input', async () => {
  const errors = [];
  assert.equal(
    await confirmRepositoryDeletion([], {
      input: { isTTY: false },
      output: { isTTY: true },
      printError: (message) => errors.push(message),
    }),
    false,
  );
  assert.deepEqual(errors, [
    'Deletion requires an interactive terminal. Nothing was deleted.',
  ]);
});

test('clean and unclean confirmation use one and two prompts', async () => {
  async function confirm(statuses, answers) {
    const messages = [];
    const prompts = [];
    let closed = false;
    const result = await confirmRepositoryDeletion(statuses, {
      createInterface: () => ({
        close() {
          closed = true;
        },
        question: async (prompt) => {
          prompts.push(prompt);
          return answers.shift();
        },
      }),
      input: { isTTY: true },
      output: { isTTY: true },
      print: (message) => messages.push(message),
    });
    return { closed, messages, prompts, result };
  }

  const clean = await confirm([], ['delete']);
  assert.equal(clean.result, true);
  assert.equal(clean.closed, true);
  assert.equal(clean.prompts.length, 1);

  const unclean = await confirm(
    [
      {
        ahead: ['main=1'],
        changes: { staged: 1, unstaged: 0, untracked: 0 },
        name: 'obsolete',
        stashCount: 1,
        warnings: [],
      },
    ],
    ['delete', 'delete'],
  );
  assert.equal(unclean.result, true);
  assert.equal(unclean.closed, true);
  assert.equal(unclean.prompts.length, 2);
  assert.ok(unclean.messages.includes('Unclean repositories:'));
  assert.ok(unclean.messages.includes('    - working tree: staged: 1'));
  assert.ok(unclean.messages.includes('    - 1 stash'));
  assert.ok(unclean.messages.includes('    - unpushed commits: main=1'));
});

test('prune revalidates inventory and refuses restored repositories', async () => {
  const inventoryCalls = [];
  let removed = false;
  const capture = await captureConsole(() =>
    pruneRepositories(
      [],
      createPruneOptions({
        findRestoredRepositories: (local, remote) =>
          remote.some((repository) => repository.name === local[0].name)
            ? local
            : [],
        getRemoteRepositories(refresh) {
          inventoryCalls.push(refresh);
          return refresh ? [{ name: 'obsolete' }] : [];
        },
        removeRepositories: () => {
          removed = true;
          return 0;
        },
      }),
    ),
  );

  assert.equal(capture.result, 1);
  assert.deepEqual(inventoryCalls, [false, true]);
  assert.equal(removed, false);
  assert.deepEqual(capture.errors, [
    'Remote repository state changed during confirmation. Nothing was deleted.',
    'Now present remotely: obsolete',
  ]);
});

test('removal continues after a failure and returns nonzero', () => {
  const errors = [];
  const output = [];
  const removed = [];
  const status = removeLocalRepositories(
    [
      { path: '/safe/first' },
      { path: '/safe/second' },
    ],
    {
      print: (message) => output.push(message),
      printError: (message) => errors.push(message),
      remove(path) {
        removed.push(path);
        if (path.endsWith('/first')) {
          throw new Error('injected failure');
        }
      },
    },
  );

  assert.equal(status, 1);
  assert.deepEqual(removed, ['/safe/first', '/safe/second']);
  assert.deepEqual(output, ['Deleted /safe/second']);
  assert.deepEqual(errors, [
    'Could not delete /safe/first: injected failure',
    'Failed to delete 1 of 2 repositories.',
  ]);
});
