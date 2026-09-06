import assert from 'node:assert/strict';
import test from 'node:test';

import { manageGeneral } from '../../lib/archon/commands/workspaces/src/general.mjs';

function createContext({ missing = false, fail, present = false } = {}) {
  const calls = [];
  const errors = [];
  return {
    calls,
    errors,
    context: {
      homeDir: '/home/test',
      directoryExists: (directory) => {
        assert.equal(directory, '/home/test/projects');
        return !missing;
      },
      printError: (message) => errors.push(message),
      run(command, arguments_) {
        assert.equal(command, 'tmux');
        calls.push(arguments_);
        const operation = arguments_[0];
        if (operation === 'has-session') return present ? 0 : 1;
        if (operation === fail) return 1;
        present = operation === 'new-session';
        return 0;
      },
    },
  };
}

test('general creates one shell window at projects and preserves it on restart', () => {
  const fixture = createContext();
  assert.equal(manageGeneral('start', fixture.context), 0);
  assert.deepEqual(fixture.calls, [
    ['has-session', '-t', 'main'],
    ['new-session', '-d', '-s', 'main', '-c', '/home/test/projects', '-n', 'shell'],
  ]);
  fixture.calls.length = 0;
  assert.equal(manageGeneral('start', fixture.context), 0);
  assert.deepEqual(fixture.calls, [['has-session', '-t', 'main']]);
});

test('general skips a missing projects directory', () => {
  const fixture = createContext({ missing: true });
  assert.equal(manageGeneral('start', fixture.context), 0);
  assert.deepEqual(fixture.calls, []);
  assert.deepEqual(fixture.errors, [
    'Skipping main: directory does not exist: /home/test/projects',
  ]);
});

test('general stop tolerates an absent session and missing directory', () => {
  const fixture = createContext({ present: true, missing: true });
  assert.equal(manageGeneral('stop', fixture.context), 0);
  assert.equal(manageGeneral('stop', fixture.context), 0);
  assert.deepEqual(fixture.calls, [
    ['has-session', '-t', 'main'],
    ['kill-session', '-t', 'main'],
    ['has-session', '-t', 'main'],
  ]);
});

test('general reports start and stop failures', () => {
  for (const action of ['start', 'stop']) {
    const fixture = createContext({
      fail: action === 'start' ? 'new-session' : 'kill-session',
      present: action === 'stop',
    });
    assert.equal(manageGeneral(action, fixture.context), 1);
    assert.deepEqual(fixture.errors, [`Failed to ${action} tmux session: main`]);
  }
});
