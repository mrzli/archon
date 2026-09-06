import assert from 'node:assert/strict';
import { mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { test } from 'bun:test';

import {
  createFixture,
  removeFixture,
  runArchon,
  writeExecutable,
} from './test-helpers.ts';

const USAGE_CASES = [
  ['h', 'extra'],
  ['p', 's'],
  ['l', 'b'],
  ['w', 's'],
  [],
  ['unknown'],
  ['help', 'extra'],
  ['projects'],
  ['projects', 'unknown'],
  ['projects', 'delete', '--invalid'],
  ['projects', 'prune', '--invalid'],
  ['projects', 'remote', '--invalid'],
  ['projects', 'status', '--invalid'],
  ['projects', 'sync', '--invalid'],
  ['projects', 'help', 'unknown'],
  ['projects', 'help', 'status', 'extra'],
  ['libs'],
  ['libs', 'unknown'],
  ['libs', 'build', '--invalid'],
  ['libs', 'delete', '--invalid'],
  ['libs', 'graph', '--invalid'],
  ['libs', 'prune', '--invalid'],
  ['libs', 'remote', '--invalid'],
  ['libs', 'status', '--invalid'],
  ['libs', 'sync', '--invalid'],
  ['libs', 'help', 'unknown'],
  ['libs', 'help', 'status', 'extra'],
  ['workspaces'],
  ['workspaces', 'launch'],
  ['workspaces', 'start', '--group', 'hubs'],
];

for (const arguments_ of USAGE_CASES) {
  test(`${arguments_.join(' ') || 'archon'} is a usage error`, () => {
    const fixture = createFixture('usage-status');

    try {
      const result = runArchon(fixture, arguments_);
      assert.equal(result.status, 2);
      assert.equal(result.signal, null);
    } finally {
      removeFixture(fixture);
    }
  });
}

for (const arguments_ of [
  ['-h'],
  ['--help'],
  ['projects', '--help'],
  ['libs', '--help'],
]) {
  test(`${arguments_.join(' ')} is successful help`, () => {
    const fixture = createFixture('help-status');

    try {
      const result = runArchon(fixture, arguments_);
      assert.equal(result.status, 0);
      assert.equal(result.signal, null);
    } finally {
      removeFixture(fixture);
    }
  });
}

test('direct command aliases preserve help output and argument forwarding', () => {
  const fixture = createFixture('command-aliases');
  try {
    for (const [alias, command, arguments_] of [
      ['h', 'help', []],
      ['l', 'libs', ['help', 'build']],
      ['p', 'projects', ['help', 'status']],
      ['w', 'workspaces', ['--help']],
    ] satisfies [string, string, string[]][]) {
      const short = runArchon(fixture, [alias, ...arguments_]);
      const full = runArchon(fixture, [command, ...arguments_]);
      assert.equal(short.status, 0);
      assert.equal(full.status, 0);
      assert.equal(short.stdout, full.stdout);
      assert.equal(short.stderr, full.stderr);
    }
  } finally {
    removeFixture(fixture);
  }
});

test('a signaled tmux operation is an operational failure', () => {
  const fixture = createFixture('tmux-signal');

  try {
    mkdirSync(
      join(fixture.home, 'projects/personal/mrzli/flashcards-fe'),
      { recursive: true },
    );
    mkdirSync(
      join(fixture.home, 'projects/personal/mrzli/flashcards-be'),
      { recursive: true },
    );
    writeExecutable(
      join(fixture.bin, 'tmux'),
      `#!/usr/bin/env bash
kill -TERM "$$"
`,
    );

    const result = runArchon(fixture, [
      'workspaces',
      'start',
      '--group',
      'flashcards',
    ]);

    assert.equal(result.status, 1);
    assert.equal(result.signal, null);
    assert.match(result.stderr, /Failed to start tmux session: flashcards-fe/);
    assert.match(result.stderr, /Failed to start tmux session: flashcards-be/);
  } finally {
    removeFixture(fixture);
  }
});

test('a signaled tmux capture is an operational failure', () => {
  const fixture = createFixture('tmux-capture-signal');

  try {
    mkdirSync(
      join(fixture.home, 'projects/personal/mrzli-jslib'),
      { recursive: true },
    );
    writeExecutable(
      join(fixture.bin, 'tmux'),
      `#!/usr/bin/env bash
kill -TERM "$$"
`,
    );

    const result = runArchon(fixture, [
      'workspaces',
      'stop',
      '--group',
      'jslibs',
    ]);

    assert.equal(result.status, 1);
    assert.equal(result.signal, null);
    assert.match(result.stderr, /Failed to list tmux sessions:/);
  } finally {
    removeFixture(fixture);
  }
});
