import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

import {
  createFixture,
  createGitEnvironment,
  removeFixture,
  withGitFixture,
  writeExecutable,
} from './test-helpers.mjs';

test('real Git suites ignore inherited repository, signing, and hook settings', () => {
  const external = createFixture('external-git-config');
  const sentinel = join(external.root, 'hook-ran');
  const hooks = join(external.root, 'hooks');
  const config = join(external.root, 'gitconfig');
  const signer = join(external.bin, 'signer');
  const decoy = join(external.root, 'decoy');
  const script = `#!/usr/bin/env node
require('node:fs').writeFileSync(process.env.ARCHON_TEST_SENTINEL, 'unexpected execution');
process.exit(1);
`;
  try {
    writeExecutable(join(hooks, 'pre-commit'), script);
    writeExecutable(signer, script);
    writeFileSync(config, `[core]\n hooksPath = "${hooks}"\n[commit]\n gpgSign = true\n[gpg]\n program = "${signer}"\n`);
    mkdirSync(decoy);
    execFileSync('git', ['init', '-q', decoy], {
      env: createGitEnvironment(external),
    });

    const result = spawnSync(process.execPath, [
      '--test', '--test-concurrency=1',
      fileURLToPath(new URL('./repository-status.test.mjs', import.meta.url)),
      fileURLToPath(new URL('./sync-workflow.test.mjs', import.meta.url)),
    ], {
      encoding: 'utf8',
      timeout: 30000,
      env: {
        ...process.env,
        ARCHON_TEST_SENTINEL: sentinel,
        GIT_CONFIG_GLOBAL: config,
        GIT_CONFIG_SYSTEM: config,
        GIT_CONFIG_COUNT: '1',
        GIT_CONFIG_KEY_0: 'core.hooksPath',
        GIT_CONFIG_VALUE_0: hooks,
        GIT_DIR: join(decoy, '.git'),
        GIT_WORK_TREE: decoy,
        GIT_INDEX_FILE: join(external.root, 'external-index'),
        GIT_CONFIG_PARAMETERS: "'commit.gpgSign'='true'",
      },
    });
    assert.equal(result.error, undefined);
    assert.equal(result.status, 0, `${result.stdout}\n${result.stderr}`);
    assert.equal(existsSync(sentinel), false);
    assert.equal(existsSync(join(external.root, 'external-index')), false);
    assert.equal(existsSync(join(decoy, 'tracked.txt')), false);
  } finally {
    removeFixture(external);
  }
});

test('Git fixture scopes restore the environment and clean up after failure', () => {
  const previousEnvironment = process.env;
  let root;
  assert.throws(() => withGitFixture('failed-git-scope', (fixture) => {
    root = fixture.root;
    assert.equal(process.env.HOME, fixture.home);
    assert.equal(process.env.GIT_CONFIG_GLOBAL, '/dev/null');
    throw new Error('injected fixture failure');
  }), /injected fixture failure/);
  assert.equal(process.env, previousEnvironment);
  assert.equal(existsSync(root), false);
});

test('Git environment retains explicitly supplied test settings', () => {
  const fixture = createFixture('git-overrides');
  try {
    const environment = createGitEnvironment(fixture, { GIT_TRACE: '1' });
    assert.equal(environment.GIT_TRACE, '1');
    assert.equal(environment.GIT_CONFIG_NOSYSTEM, '1');
    assert.equal(environment.HOME, fixture.home);
    assert.ok(environment.PATH.startsWith(`${fixture.bin}:`));
  } finally {
    removeFixture(fixture);
  }
});
