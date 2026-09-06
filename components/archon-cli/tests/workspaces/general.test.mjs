import assert from 'node:assert/strict';
import { test } from 'bun:test';

import { manageGeneral } from '../../src/commands/workspaces/general.mjs';

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
      tmux: {
        hasSession(session) {
          calls.push(['hasSession', session]);
          return present;
        },
        createShellSession(definition) {
          calls.push(['createShellSession', definition]);
          if (fail === 'createShellSession') return 1;
          present = true;
          return 0;
        },
        stopSession(session) {
          calls.push(['stopSession', session]);
          if (fail === 'stopSession') return 1;
          present = false;
          return 0;
        },
      },
    },
  };
}

test('general creates one shell window at projects and preserves it on restart', () => {
  const fixture = createContext();
  assert.equal(manageGeneral('start', fixture.context), 0);
  assert.deepEqual(fixture.calls, [
    ['hasSession', 'main'],
    ['createShellSession', { session: 'main', directory: '/home/test/projects' }],
  ]);
  fixture.calls.length = 0;
  assert.equal(manageGeneral('start', fixture.context), 0);
  assert.deepEqual(fixture.calls, [['hasSession', 'main']]);
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
    ['stopSession', 'main'],
    ['stopSession', 'main'],
  ]);
});

test('general reports start and stop failures', () => {
  for (const action of ['start', 'stop']) {
    const fixture = createContext({
      fail: action === 'start' ? 'createShellSession' : 'stopSession',
      present: action === 'stop',
    });
    assert.equal(manageGeneral(action, fixture.context), 1);
    assert.deepEqual(fixture.errors, [`Failed to ${action} tmux session: main`]);
  }
});
