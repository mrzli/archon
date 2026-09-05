import assert from 'node:assert/strict';
import test from 'node:test';

import { createEditorSession } from '../../lib/archon/workspaces/src/tmux.mjs';

const DEFINITION = {
  session: 'example',
  directory: '/projects/example',
  devCommand: 'bun run dev',
};

const SETUP_OPERATIONS = [
  [
    'new-session',
    '-d',
    '-s',
    'example',
    '-c',
    '/projects/example',
    '-n',
    'nvim',
  ],
  ['send-keys', '-t', 'example:nvim', 'nvim .', 'Enter'],
  [
    'new-window',
    '-t',
    'example',
    '-c',
    '/projects/example',
    '-n',
    'codex',
  ],
  ['send-keys', '-t', 'example:codex', 'codex resume --last', 'Enter'],
  [
    'new-window',
    '-t',
    'example',
    '-c',
    '/projects/example',
    '-n',
    'dev',
  ],
  ['send-keys', '-t', 'example:dev', 'bun run dev', 'Enter'],
  [
    'new-window',
    '-t',
    'example',
    '-c',
    '/projects/example',
    '-n',
    'shell',
  ],
  ['select-window', '-t', 'example:nvim'],
];

function createTmux({ cleanupFails = false, failureIndex } = {}) {
  const calls = [];
  const sessions = new Set();

  return {
    calls,
    sessions,
    run(command, arguments_) {
      assert.equal(command, 'tmux');
      calls.push(arguments_);

      if (arguments_[0] === 'kill-session') {
        if (cleanupFails) {
          return 1;
        }

        sessions.delete(arguments_[2]);
        return 0;
      }

      const operationIndex = calls.length - 1;
      if (operationIndex === failureIndex) {
        return 1;
      }

      if (arguments_[0] === 'new-session') {
        sessions.add(arguments_[3]);
      }

      return 0;
    },
  };
}

test('new-session failure does not attempt cleanup', () => {
  const fixture = createTmux({ failureIndex: 0 });

  assert.deepEqual(createEditorSession(fixture.run, DEFINITION), {
    cleanupStatus: undefined,
    status: 1,
  });
  assert.deepEqual(fixture.calls, [SETUP_OPERATIONS[0]]);
  assert.deepEqual([...fixture.sessions], []);
});

test('each failure after session creation rolls the new session back', () => {
  for (let failureIndex = 1; failureIndex < SETUP_OPERATIONS.length; failureIndex += 1) {
    const fixture = createTmux({ failureIndex });

    assert.deepEqual(createEditorSession(fixture.run, DEFINITION), {
      cleanupStatus: 0,
      status: 1,
    });
    assert.deepEqual(fixture.calls, [
      ...SETUP_OPERATIONS.slice(0, failureIndex + 1),
      ['kill-session', '-t', 'example'],
    ]);
    assert.deepEqual([...fixture.sessions], []);
  }
});

test('cleanup failure is returned with the original setup failure', () => {
  const fixture = createTmux({ cleanupFails: true, failureIndex: 1 });

  assert.deepEqual(createEditorSession(fixture.run, DEFINITION), {
    cleanupStatus: 1,
    status: 1,
  });
  assert.deepEqual([...fixture.sessions], ['example']);
});

test('a successful retry completes a session after rollback', () => {
  const firstAttempt = createTmux({ failureIndex: 3 });
  assert.equal(createEditorSession(firstAttempt.run, DEFINITION).status, 1);
  assert.deepEqual([...firstAttempt.sessions], []);

  const retry = createTmux();
  assert.deepEqual(createEditorSession(retry.run, DEFINITION), {
    cleanupStatus: undefined,
    status: 0,
  });
  assert.deepEqual(retry.calls, SETUP_OPERATIONS);
  assert.deepEqual([...retry.sessions], ['example']);
});
