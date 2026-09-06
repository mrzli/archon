import assert from 'node:assert/strict';
import { test } from 'bun:test';

import { createTmux } from '../../src/commands/workspaces/tmux.ts';

const DEFINITION = {
  session: 'example',
  directory: '/projects/example',
  devCommand: 'bun run dev',
};

test('shell session commands and repeat-safe stopping preserve tmux behavior', () => {
  const calls: string[][] = [];
  let present = false;
  const tmux = createTmux({
    capture: () => { throw new Error('unexpected process capture'); },
    run(command, arguments_, options) {
      assert.equal(command, 'tmux');
      calls.push(arguments_);
      if (arguments_[0] === 'has-session') {
        assert.deepEqual(options, { stdio: 'ignore' });
        return present ? 0 : 1;
      }
      present = arguments_[0] === 'new-session';
      return 0;
    },
  });

  assert.equal(tmux.hasSession('main'), false);
  assert.equal(tmux.createShellSession({ session: 'main', directory: '/projects' }), 0);
  assert.equal(tmux.hasSession('main'), true);
  assert.equal(tmux.stopSession('main'), 0);
  assert.equal(tmux.stopSession('main'), 0);
  assert.deepEqual(calls, [
    ['has-session', '-t', 'main'],
    ['new-session', '-d', '-s', 'main', '-c', '/projects', '-n', 'shell'],
    ['has-session', '-t', 'main'],
    ['has-session', '-t', 'main'],
    ['kill-session', '-t', 'main'],
    ['has-session', '-t', 'main'],
  ]);
});

test('listing, exact attachment, and direct killing preserve command results', () => {
  const calls: string[][] = [];
  const result = { status: 1, output: 'no sessions' };
  const tmux = createTmux({
    capture(command, arguments_) {
      calls.push([command, ...arguments_]);
      return result;
    },
    run(command: string, arguments_: string[]) {
      calls.push([command, ...arguments_]);
      return 7;
    },
  });

  assert.equal(tmux.listSessions(), result);
  assert.equal(tmux.attachSession('main'), 7);
  assert.equal(tmux.killSession('jslib-example'), 7);
  assert.deepEqual(calls, [
    ['tmux', 'list-sessions', '-F', '#S'],
    ['tmux', 'attach-session', '-t', '=main'],
    ['tmux', 'kill-session', '-t', 'jslib-example'],
  ]);
});

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

function createFixture({ cleanupFails = false, failureIndex }: { cleanupFails?: boolean; failureIndex?: number } = {}) {
  const calls: string[][] = [];
  const sessions = new Set<string>();

  return {
    calls,
    sessions,
    capture: () => { throw new Error('unexpected process capture'); },
    run(command: string, arguments_: string[]) {
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
  const fixture = createFixture({ failureIndex: 0 });

  assert.deepEqual(createTmux(fixture).createEditorSession(DEFINITION), {
    cleanupStatus: undefined,
    status: 1,
  });
  assert.deepEqual(fixture.calls, [SETUP_OPERATIONS[0]]);
  assert.deepEqual([...fixture.sessions], []);
});

test('each failure after session creation rolls the new session back', () => {
  for (let failureIndex = 1; failureIndex < SETUP_OPERATIONS.length; failureIndex += 1) {
    const fixture = createFixture({ failureIndex });

    assert.deepEqual(createTmux(fixture).createEditorSession(DEFINITION), {
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
  const fixture = createFixture({ cleanupFails: true, failureIndex: 1 });

  assert.deepEqual(createTmux(fixture).createEditorSession(DEFINITION), {
    cleanupStatus: 1,
    status: 1,
  });
  assert.deepEqual([...fixture.sessions], ['example']);
});

test('a successful retry completes a session after rollback', () => {
  const firstAttempt = createFixture({ failureIndex: 3 });
  assert.equal(createTmux(firstAttempt).createEditorSession(DEFINITION).status, 1);
  assert.deepEqual([...firstAttempt.sessions], []);

  const retry = createFixture();
  assert.deepEqual(createTmux(retry).createEditorSession(DEFINITION), {
    cleanupStatus: undefined,
    status: 0,
  });
  assert.deepEqual(retry.calls, SETUP_OPERATIONS);
  assert.deepEqual([...retry.sessions], ['example']);
});
