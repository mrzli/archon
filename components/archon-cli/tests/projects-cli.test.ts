import assert from 'node:assert/strict';
import { mkdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { test } from 'bun:test';

import type { Fixture } from './test-helpers.ts';
import {
  createFixture,
  removeFixture,
  runArchon,
  writeExecutable,
} from './test-helpers.ts';

const blacklistedOrganizations = [
  'mrzli-courses',
  'mrzli-gh-actions',
  'mrzli-other',
  'mrzli-vscode-extensions',
];

function installFakeGitHub(fixture: Fixture) {
  writeExecutable(
    join(fixture.bin, 'gh'),
    `#!/usr/bin/env bash
set -u
printf '%s\n' "$*" >> "$ARCHON_TEST_GH_CALLS"
case "$*" in
  'api --hostname github.com user --jq .login')
    printf '%s\n' "\${ARCHON_TEST_GH_USER:-test-user}"
    ;;
  *'user/memberships/orgs?state=active&per_page=100'*)
    printf '%s\n' "\${ARCHON_TEST_GH_ORGS:-}"
    ;;
  *'user/repos?affiliation=owner&visibility=all&per_page=100'*)
    printf '%s\n' "\${ARCHON_TEST_GH_USER_REPOS:-}"
    ;;
  *'orgs/AlphaOrg/repos?type=all&per_page=100'*)
    printf '%s\n' "\${ARCHON_TEST_GH_ORG_REPOS:-}"
    ;;
  *)
    printf 'Unexpected fake gh invocation: %s\n' "$*" >&2
    exit 99
    ;;
esac
`,
  );
}

function projectEnvironment(fixture: Fixture, overrides: NodeJS.ProcessEnv = {}) {
  return {
    ARCHON_TEST_GH_CALLS: join(fixture.root, 'gh-calls'),
    ARCHON_TEST_GH_ORGS: [...blacklistedOrganizations, 'AlphaOrg'].join('\n'),
    ...overrides,
  };
}

test('projects list filtered, deduplicated remotes from paginated GitHub calls', () => {
  const fixture = createFixture('projects-remote');
  const callsPath = join(fixture.root, 'gh-calls');

  try {
    installFakeGitHub(fixture);
    mkdirSync(join(fixture.home, 'projects/personal'), { recursive: true });

    const result = runArchon(
      fixture,
      ['projects', 'remote'],
      projectEnvironment(fixture, {
        ARCHON_TEST_GH_USER_REPOS: [
          '1\ttest-user/Zeta\tgit@example:Zeta.git\tfalse\tpublic',
          '2\tAlphaOrg/Shared\tgit@example:Shared.git\tfalse\tpublic',
        ].join('\n'),
        ARCHON_TEST_GH_ORG_REPOS: [
          '2\talphaorg/shared\tgit@example:shared.git\ttrue\tprivate',
          '3\tAlphaOrg/Alpha\tgit@example:Alpha.git\tfalse\tpublic',
        ].join('\n'),
      }),
    );

    assert.equal(result.status, 0);
    assert.equal(result.stderr, '');
    assert.equal(
      result.stdout,
      'AlphaOrg/Alpha\nalphaorg/shared (private, archived)\ntest-user/Zeta\n',
    );

    const calls = readFileSync(callsPath, 'utf8');
    assert.match(
      calls,
      /--paginate user\/memberships\/orgs\?state=active&per_page=100/,
    );
    assert.match(
      calls,
      /--paginate user\/repos\?affiliation=owner&visibility=all&per_page=100/,
    );
    assert.match(
      calls,
      /--paginate orgs\/AlphaOrg\/repos\?type=all&per_page=100/,
    );

    for (const organization of blacklistedOrganizations) {
      assert.doesNotMatch(calls, new RegExp(`orgs/${organization}/repos`));
    }
  } finally {
    removeFixture(fixture);
  }
});

test('projects local discovery preserves owner/repository depth and ordering', () => {
  const fixture = createFixture('projects-discovery');
  const root = join(fixture.home, 'projects/personal');

  try {
    mkdirSync(join(root, 'Beta/repository/.git'), { recursive: true });
    mkdirSync(join(root, 'alpha/second/.git'), { recursive: true });
    mkdirSync(join(root, 'alpha/first/.git'), { recursive: true });
    mkdirSync(join(root, 'alpha/not-a-repository/nested/.git'), {
      recursive: true,
    });
    mkdirSync(join(root, 'direct/.git/repository'), { recursive: true });

    const result = runArchon(fixture, ['projects', 'delete', '--dry-run']);

    assert.equal(result.status, 0);
    assert.equal(result.stderr, '');
    assert.deepEqual(
      result.stdout
        .trimEnd()
        .split('\n')
        .slice(1)
        .map((line) => line.trim()),
      [
        join(root, 'alpha/first'),
        join(root, 'alpha/second'),
        join(root, 'Beta/repository'),
      ],
    );
    assert.doesNotMatch(result.stdout, /not-a-repository|personal\/direct/);
  } finally {
    removeFixture(fixture);
  }
});

test('projects sync refuses an occupied non-repository clone destination', () => {
  const fixture = createFixture('projects-clone-conflict');
  const destination = join(
    fixture.home,
    'projects/personal/AlphaOrg/alpha',
  );

  try {
    installFakeGitHub(fixture);
    mkdirSync(destination, { recursive: true });
    const result = runArchon(
      fixture,
      ['projects', 'sync'],
      projectEnvironment(fixture, {
        ARCHON_TEST_GH_ORG_REPOS:
          '1\tAlphaOrg/alpha\tgit@example:alpha.git\tfalse\tpublic',
      }),
    );

    assert.equal(result.status, 1);
    assert.match(result.stdout, /Synchronizing 1 repositories/);
    assert.match(
      result.stdout,
      new RegExp(`ERROR: destination already exists and is not a repository: ${destination}`),
    );
  } finally {
    removeFixture(fixture);
  }
});
