import assert from 'node:assert/strict';
import test from 'node:test';

import { parseRemoteRepositories } from '../lib/archon/commands/libs/src/github-inventory.mjs';

test('library GitHub output is parsed into normalized inventory records', () => {
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

test('library GitHub output must be a JSON array', () => {
  assert.throws(
    () => parseRemoteRepositories('{}'),
    new Error('Could not read GitHub CLI output: expected an array'),
  );
  assert.throws(
    () => parseRemoteRepositories('not-json'),
    /Could not read GitHub CLI output:/,
  );
});

test('library GitHub repositories require string name fields', () => {
  for (const repository of [
    { nameWithOwner: 'mrzli-jslib/example' },
    { name: 'example' },
    { name: 123, nameWithOwner: 'mrzli-jslib/example' },
    { name: 'example', nameWithOwner: null },
  ]) {
    assert.throws(
      () => parseRemoteRepositories(JSON.stringify([repository])),
      new Error('Could not read GitHub CLI output: repository name is missing'),
    );
  }
});
