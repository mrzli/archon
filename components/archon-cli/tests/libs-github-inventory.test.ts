import type { RemoteRepository } from '../src/commands/libs/github-inventory.ts';
import assert from 'node:assert/strict';
import { test } from 'bun:test';

import { parseRemoteRepositories } from '../src/commands/libs/github-inventory.ts';

test('library GitHub output is parsed into normalized inventory records', (): void => {
  const repositories = parseRemoteRepositories(JSON.stringify([
    {
      extra: 'ignored',
      isArchived: true,
      isPrivate: false,
      name: 'example',
      nameWithOwner: 'mrzli-jslib/example',
    },
  ]));

  assert.deepEqual(repositories, [
    {
      name: 'example',
      nameWithOwner: 'mrzli-jslib/example',
      isPrivate: false,
      isArchived: true,
    },
  ]);
});

test('library GitHub output must be a JSON array', (): void => {
  assert.throws(
    (): readonly RemoteRepository[] => parseRemoteRepositories('{}'),
    new Error('Could not read GitHub CLI output: expected an array'),
  );
  assert.throws(
    (): readonly RemoteRepository[] => parseRemoteRepositories('not-json'),
    /Could not read GitHub CLI output:/,
  );
});

test('library GitHub repositories require string name fields', (): void => {
  for (const repository of [
    { nameWithOwner: 'mrzli-jslib/example' },
    { name: 'example' },
    { name: 123, nameWithOwner: 'mrzli-jslib/example' },
    { name: 'example', nameWithOwner: null },
  ]) {
    assert.throws(
      (): readonly RemoteRepository[] => parseRemoteRepositories(JSON.stringify([repository])),
      new Error('Could not read GitHub CLI output: repository name is missing'),
    );
  }
});
