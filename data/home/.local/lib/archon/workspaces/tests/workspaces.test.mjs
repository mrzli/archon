import assert from 'node:assert/strict';
import test from 'node:test';

import { main } from '../src/workspaces.mjs';

function createContext({ failures = {}, tmux = '' } = {}) {
  const calls = [];
  const errors = [];
  const output = [];

  return {
    calls,
    errors,
    output,
    context: {
      environment: { TMUX: tmux },
      groupHandlers: {
        flashcards(action) {
          calls.push(['flashcards', action]);
          return failures.flashcards ?? 0;
        },
        jslibs(action) {
          calls.push(['jslibs', action]);
          return failures.jslibs ?? 0;
        },
        'misc-projects'(action) {
          calls.push(['misc-projects', action]);
          return failures['misc-projects'] ?? 0;
        },
      },
      print: (message) => output.push(message),
      printError: (message) => errors.push(message),
      run: () => {
        throw new Error('orchestrator unexpectedly ran a direct command');
      },
    },
  };
}

test('help and invalid invocations do not run commands', () => {
  const help = createContext();
  assert.equal(main(['--help'], help.context), 0);
  assert.match(help.output.join('\n'), /^Usage: archon workspaces/);
  assert.deepEqual(help.calls, []);

  const missing = createContext();
  assert.equal(main([], missing.context), 2);
  assert.match(missing.errors.join('\n'), /Missing workspace action/);
  assert.deepEqual(missing.calls, []);

  const hubs = createContext();
  assert.equal(main(['start', '--group', 'hubs'], hubs.context), 2);
  assert.deepEqual(hubs.calls, []);
});

test('group options run only their selected group', () => {
  for (const option of ['--group', '-g']) {
    for (const group of ['flashcards', 'jslibs', 'misc-projects']) {
      const fixture = createContext();
      assert.equal(main(['start', option, group], fixture.context), 0);
      assert.deepEqual(fixture.calls, [[group, 'start']]);
    }
  }
});

test('aggregate start runs every group without attaching or switching', () => {
  const fixture = createContext({ tmux: 'client' });
  assert.equal(main(['start'], fixture.context), 0);
  assert.deepEqual(fixture.calls, [
    ['flashcards', 'start'],
    ['jslibs', 'start'],
    ['misc-projects', 'start'],
  ]);
});

test('aggregate start continues after failure', () => {
  const fixture = createContext({ failures: { flashcards: 1 } });
  assert.equal(main(['start'], fixture.context), 1);
  assert.deepEqual(fixture.calls, [
    ['flashcards', 'start'],
    ['jslibs', 'start'],
    ['misc-projects', 'start'],
  ]);
  assert.deepEqual(fixture.errors, [
    'Failed to start tmux group: flashcards',
  ]);
});

test('aggregate stop uses reverse order', () => {
  const fixture = createContext();
  assert.equal(main(['stop'], fixture.context), 0);
  assert.deepEqual(fixture.calls, [
    ['misc-projects', 'stop'],
    ['jslibs', 'stop'],
    ['flashcards', 'stop'],
  ]);
});

test('aggregate stop continues after failure', () => {
  const fixture = createContext({ failures: { jslibs: 1 } });
  assert.equal(main(['stop'], fixture.context), 1);
  assert.deepEqual(fixture.calls, [
    ['misc-projects', 'stop'],
    ['jslibs', 'stop'],
    ['flashcards', 'stop'],
  ]);
  assert.deepEqual(fixture.errors, ['Failed to stop tmux group: jslibs']);
});
