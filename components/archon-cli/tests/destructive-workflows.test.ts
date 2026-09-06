import { PassThrough } from 'node:stream';
import assert from 'node:assert/strict';
import { test } from 'bun:test';

import type { DeleteOptions, PruneOptions } from '../src/shared/destructive-workflows.ts';
import type { RepositoryStatus } from '../src/shared/repository-inspection.ts';
import {
  confirmRepositoryDeletion,
  deleteRepositories,
  pruneRepositories,
  removeLocalRepositories,
} from '../src/shared/destructive-workflows.ts';

const repositories: readonly { name: string; path: string; }[] = [{ name: 'obsolete', path: '/safe/obsolete' }];

async function captureConsole<T>(run: () => Promise<T>): Promise<{ readonly errors: string[]; readonly output: string[]; readonly result: Awaited<T>; }> {
  const errors: string[] = [];
  const output: string[] = [];
  const originalError = console.error;
  const originalLog = console.log;
  console.error = (message): number => errors.push(message);
  console.log = (message): number => output.push(message);

  try {
    return { errors, output, result: await run() };
  } finally {
    console.error = originalError;
    console.log = originalLog;
  }
}

function createDeleteOptions(
  overrides: Partial<DeleteOptions<(typeof repositories)[number]>> = {},
): DeleteOptions<(typeof repositories)[number]> {
  return {
    confirmDeletion: async (): Promise<true> => true,
    emptyMessage: 'No repositories.',
    findRepositories: (): readonly { readonly name: string; readonly path: string; }[] => repositories,
    inspectRepositories: (): readonly never[] => [],
    printHelp: (): void => console.log('delete help'),
    removeRepositories: (): number => 0,
    requiredRootDir: '/safe',
    rootDir: '/safe',
    ...overrides,
  };
}

function createPruneOptions(
  overrides: Partial<PruneOptions<(typeof repositories)[number], { readonly name: string }>> = {},
): PruneOptions<(typeof repositories)[number], { readonly name: string }> {
  return {
    confirmDeletion: async (): Promise<true> => true,
    findPrunableRepositories: (): readonly { readonly name: string; readonly path: string; }[] => repositories,
    findRestoredRepositories: (): readonly never[] => [],
    getRemoteRepositories: (): readonly never[] => [],
    getRepositoryName: (repository): string => repository.name,
    inspectRepositories: (): readonly never[] => [],
    printHelp: (): void => console.log('prune help'),
    removeRepositories: (): number => 0,
    requiredRootDir: '/safe',
    rootDir: '/safe',
    ...overrides,
  };
}

test('invalid arguments and unsafe roots are refused before discovery', async (): Promise<void> => {
  let discovered = false;
  const invalid = await captureConsole((): Promise<number> =>
    deleteRepositories(
      ['--invalid'],
      createDeleteOptions({
        findRepositories(): readonly { readonly name: string; readonly path: string; }[] {
          discovered = true;
          return repositories;
        },
      }),
    ),
  );
  assert.equal(invalid.result, 2);
  assert.deepEqual(invalid.errors, ['Unexpected delete option: --invalid']);
  assert.deepEqual(invalid.output, ['delete help']);
  assert.equal(discovered, false);

  const unsafe = await captureConsole((): Promise<number> =>
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

test('delete dry-run lists repositories without confirmation or removal', async (): Promise<void> => {
  let confirmed = false;
  let removed = false;
  const capture = await captureConsole((): Promise<number> =>
    deleteRepositories(
      ['-n'],
      createDeleteOptions({
        confirmDeletion: async (): Promise<true> => {
          confirmed = true;
          return true;
        },
        removeRepositories: (): number => {
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

test('confirmation refuses non-interactive input', async (): Promise<void> => {
  const errors: string[] = [];
  assert.equal(
    await confirmRepositoryDeletion([], {
      input: Object.assign(new PassThrough(), { isTTY: false }),
      output: Object.assign(new PassThrough(), { isTTY: true }),
      printError: (message): number => errors.push(message),
    }),
    false,
  );
  assert.deepEqual(errors, [
    'Deletion requires an interactive terminal. Nothing was deleted.',
  ]);
});

test('clean and unclean confirmation use one and two prompts', async (): Promise<void> => {
  async function confirm(statuses: readonly RepositoryStatus[], answers: string[]): Promise<{ readonly closed: boolean; readonly messages: readonly string[]; readonly prompts: readonly string[]; readonly result: boolean; }> {
    const messages: string[] = [];
    const prompts: string[] = [];
    let closed = false;
    const result = await confirmRepositoryDeletion(statuses, {
      createInterface: (): { close(): void; readonly question: (prompt: string) => Promise<string>; } => ({
        close(): void {
          closed = true;
        },
        question: async (prompt): Promise<string> => {
          prompts.push(prompt);
          const answer = answers.shift();
          assert.ok(answer !== undefined);
          return answer;
        },
      }),
      input: Object.assign(new PassThrough(), { isTTY: true }),
      output: Object.assign(new PassThrough(), { isTTY: true }),
      print: (message): number => messages.push(message),
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
        branch: 'main',
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

test('prune revalidates inventory and refuses restored repositories', async (): Promise<void> => {
  const inventoryCalls: boolean[] = [];
  let removed = false;
  const capture = await captureConsole((): Promise<number> =>
    pruneRepositories(
      [],
      createPruneOptions({
        findRestoredRepositories: (local, remote): readonly { readonly name: string; readonly path: string; }[] =>
          remote.some((repository): boolean => repository.name === local[0].name)
            ? local
            : [],
        getRemoteRepositories(refresh): readonly { readonly name: string; }[] {
          inventoryCalls.push(refresh);
          return refresh ? [{ name: 'obsolete' }] : [];
        },
        removeRepositories: (): number => {
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

test('removal continues after a failure and returns nonzero', (): void => {
  const errors: string[] = [];
  const output: string[] = [];
  const removed: string[] = [];
  const status = removeLocalRepositories(
    [
      { path: '/safe/first' },
      { path: '/safe/second' },
    ],
    {
      print: (message): number => output.push(message),
      printError: (message): number => errors.push(message),
      remove(path): void {
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
