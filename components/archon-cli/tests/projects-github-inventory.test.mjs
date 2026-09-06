import assert from 'node:assert/strict';
import test from 'node:test';

import {
  addRemoteRepositories,
  compareRepositories,
  getRepositoryBlacklistLookupNames,
  isRepositoryBlacklisted,
  parseRemoteRepository,
  repositoryKey,
  validateBlacklists,
} from '../lib/archon/commands/projects/src/github-inventory.mjs';

test('project repository rows are parsed into normalized inventory records', () => {
  assert.deepEqual(
    parseRemoteRepository(
      '123\tExample/Repository\tgit@example:Repository.git\ttrue\tprivate',
    ),
    {
      id: '123',
      isArchived: true,
      name: 'Repository',
      nameWithOwner: 'Example/Repository',
      owner: 'Example',
      sshUrl: 'git@example:Repository.git',
      visibility: 'private',
    },
  );
});

test('project repository row validation preserves incomplete-data errors', () => {
  for (const row of [
    '',
    '123\towner/repository\tssh\tfalse',
    '\towner/repository\tssh\tfalse\tpublic',
    '123\trepository\tssh\tfalse\tpublic',
    '123\towner/\tssh\tfalse\tpublic',
    '123\towner/repository\t\tfalse\tpublic',
    '123\towner/repository\tssh\tunknown\tpublic',
    '123\towner/repository\tssh\tfalse\t',
  ]) {
    assert.throws(
      () => parseRemoteRepository(row),
      new Error(`GitHub returned incomplete repository data: ${row}`),
    );
  }
});

test('project inventory keys, ordering, and exclusions are case-insensitive', () => {
  const alpha = { nameWithOwner: 'owner/Alpha', owner: 'owner' };
  const zeta = { nameWithOwner: 'Owner/zeta', owner: 'Owner' };
  const repositoriesByName = new Map();

  assert.equal(repositoryKey(zeta), 'owner/zeta');
  assert.ok(compareRepositories(alpha, zeta) < 0);
  addRemoteRepositories(repositoriesByName, [zeta]);
  addRemoteRepositories(repositoriesByName, [
    { nameWithOwner: 'owner/ZETA', owner: 'owner' },
  ]);
  assert.equal(repositoriesByName.size, 1);
  assert.equal(
    repositoriesByName.get('owner/zeta').nameWithOwner,
    'owner/ZETA',
  );
  assert.equal(
    isRepositoryBlacklisted(alpha, ['OWNER'], []),
    true,
  );
  assert.equal(
    isRepositoryBlacklisted(zeta, [], ['owner/ZETA']),
    true,
  );
  assert.equal(isRepositoryBlacklisted(alpha, [], []), false);
});

test('repository blacklist lookup names include only valid unique entries', () => {
  assert.deepEqual(
    getRepositoryBlacklistLookupNames([
      'Owner/one',
      'invalid',
      'OWNER/ONE',
      'Owner/two',
      '/missing-owner',
    ]),
    ['Owner/one', 'Owner/two'],
  );
});

test('blacklist validation accepts canonical repositories owned by the user or organizations', () => {
  const result = validateBlacklists(
    'Test-User',
    ['Owned-Org'],
    new Map([
      ['test-user/personal', 'Test-User/Personal'],
      ['owned-org/shared', 'Owned-Org/Shared'],
    ]),
    {
      organizationBlacklist: ['owned-org'],
      repositoryBlacklist: [
        'test-user/personal',
        'owned-org/shared',
      ],
    },
  );

  assert.deepEqual([...result.blacklistedOrganizations], ['owned-org']);
  assert.deepEqual([...result.blacklistedRepositories], [
    'test-user/personal',
    'owned-org/shared',
  ]);
});

test('blacklist validation aggregates exact organization and repository errors', () => {
  const canonicalRepositories = new Map([
    ['test-user/valid', 'Test-User/Valid'],
    ['test-user/renamed', 'Test-User/New-Name'],
    ['stranger/repository', 'Stranger/Repository'],
  ]);

  assert.throws(
    () =>
      validateBlacklists(
        'Test-User',
        ['Owned-Org'],
        canonicalRepositories,
        {
          organizationBlacklist: [
            'invalid organization',
            'Owned-Org',
            'owned-org',
            'Missing-Org',
          ],
          repositoryBlacklist: [
            'invalid',
            'Test-User/Valid',
            'TEST-USER/VALID',
            'Test-User/Missing',
            'Test-User/Renamed',
            'Stranger/Repository',
          ],
        },
      ),
    new Error(
      [
        'Blacklist validation failed:',
        '  - Invalid organization blacklist entry "invalid organization".',
        '  - Duplicate organization blacklist entry "owned-org".',
        '  - Blacklisted organization "Missing-Org" is not an active organization owned by "Test-User".',
        '  - Invalid repository blacklist entry "invalid"; expected "owner/repository".',
        '  - Duplicate repository blacklist entry "TEST-USER/VALID".',
        '  - Blacklisted repository "Test-User/Missing" does not exist or is not accessible.',
        '  - Blacklisted repository "Test-User/Renamed" is now "Test-User/New-Name".',
        '  - Blacklisted repository "Stranger/Repository" is not owned by "Test-User" or an organization owned by that user.',
      ].join('\n'),
    ),
  );
});
