import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

import { manageJslibs } from '../../lib/archon/workspaces/src/jslibs.mjs';

function createContext({ captureResult, homeDir, sessions: initialSessions } = {}) {
  const calls = [];
  const errors = [];
  const sessions = new Set(initialSessions);

  return {
    calls,
    errors,
    sessions,
    context: {
      capture(command, arguments_) {
        assert.equal(command, 'tmux');
        assert.deepEqual(arguments_, ['list-sessions', '-F', '#S']);
        return captureResult ?? { status: 0, output: [...sessions].join('\n') };
      },
      homeDir: homeDir ?? '/home/test',
      printError: (message) => errors.push(message),
      run(command, arguments_) {
        assert.equal(command, 'tmux');
        calls.push(arguments_);

        if (arguments_[0] === 'has-session') {
          return sessions.has(arguments_[2]) ? 0 : 1;
        }

        if (arguments_[0] === 'new-session') {
          sessions.add(arguments_[3]);
        } else if (arguments_[0] === 'kill-session') {
          sessions.delete(arguments_[2]);
        }

        return 0;
      },
    },
  };
}

test('start discovers immediate non-hidden Git repositories', () => {
  const homeDir = mkdtempSync(join(tmpdir(), 'archon-jslibs-'));
  const root = join(homeDir, 'projects/personal/mrzli-jslib');

  try {
    mkdirSync(join(root, 'alpha/.git'), { recursive: true });
    mkdirSync(join(root, 'beta/.git'), { recursive: true });
    mkdirSync(join(root, 'not-a-repository'), { recursive: true });
    mkdirSync(join(root, 'nested/child/.git'), { recursive: true });
    mkdirSync(join(root, '.hidden/.git'), { recursive: true });

    const fixture = createContext({ homeDir });
    assert.equal(manageJslibs('start', fixture.context), 0);
    assert.deepEqual([...fixture.sessions], ['jslib-alpha', 'jslib-beta']);
    assert.deepEqual(
      fixture.calls.filter((call) => call[0] === 'new-session')
        .map((call) => [call[3], call[5]]),
      [
        ['jslib-alpha', `${join(root, 'alpha')}/`],
        ['jslib-beta', `${join(root, 'beta')}/`],
      ],
    );

    fixture.calls.length = 0;
    assert.equal(manageJslibs('start', fixture.context), 0);
    assert.deepEqual(fixture.calls, [
      ['has-session', '-t', 'jslib-alpha'],
      ['has-session', '-t', 'jslib-beta'],
    ]);
  } finally {
    rmSync(homeDir, { recursive: true, force: true });
  }
});

test('missing root is reported and skipped', () => {
  const fixture = createContext();
  assert.equal(manageJslibs('start', fixture.context), 0);
  assert.deepEqual(fixture.calls, []);
  assert.deepEqual(fixture.errors, [
    'Skipping JavaScript libraries: directory does not exist: /home/test/projects/personal/mrzli-jslib',
  ]);
});

test('stop filters sessions and tolerates repeated calls', () => {
  const fixture = createContext({
    sessions: ['jslib-alpha', 'unrelated', 'jslib-beta'],
  });

  assert.equal(manageJslibs('stop', fixture.context), 0);
  assert.deepEqual(fixture.calls, [
    ['kill-session', '-t', 'jslib-alpha'],
    ['kill-session', '-t', 'jslib-beta'],
  ]);
  assert.deepEqual([...fixture.sessions], ['unrelated']);

  fixture.calls.length = 0;
  assert.equal(manageJslibs('stop', fixture.context), 0);
  assert.deepEqual(fixture.calls, []);
});

test('stop tolerates an absent tmux server', () => {
  const fixture = createContext({
    captureResult: { status: 1, output: 'no server running on /tmp/tmux' },
  });
  assert.equal(manageJslibs('stop', fixture.context), 0);
  assert.deepEqual(fixture.errors, []);
});

test('stop reports other tmux list failures', () => {
  const fixture = createContext({
    captureResult: { status: 1, output: 'permission denied' },
  });
  assert.equal(manageJslibs('stop', fixture.context), 1);
  assert.deepEqual(fixture.errors, [
    'Failed to list tmux sessions: permission denied',
  ]);
});
