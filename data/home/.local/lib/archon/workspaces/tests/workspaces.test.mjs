import assert from 'node:assert/strict';
import { basename } from 'node:path';
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
      },
      print: (message) => output.push(message),
      printError: (message) => errors.push(message),
      run(command, arguments_) {
        const name = command === 'tmux' ? command : basename(command, '.sh');
        calls.push([name, ...arguments_]);
        return failures[name] ?? 0;
      },
      scriptsDir: '/legacy-workspaces',
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
    const fixture = createContext();
    assert.equal(main(['start', option, 'flashcards'], fixture.context), 0);
    assert.deepEqual(fixture.calls, [['flashcards', 'start']]);
  }
});

test('aggregate start runs every legacy group then attaches', () => {
  const fixture = createContext();
  assert.equal(main(['start'], fixture.context), 0);
  assert.deepEqual(fixture.calls, [
    ['hubs', 'start'],
    ['flashcards', 'start'],
    ['jslibs', 'start'],
    ['misc-projects', 'start'],
    ['tmux', 'attach-session', '-t', 'workspaces'],
  ]);
});

test('aggregate start switches an existing tmux client', () => {
  const fixture = createContext({ tmux: 'client' });
  assert.equal(main(['start'], fixture.context), 0);
  assert.deepEqual(fixture.calls.at(-1), [
    'tmux',
    'switch-client',
    '-t',
    'workspaces',
  ]);
});

test('aggregate start continues after failure and does not attach', () => {
  const fixture = createContext({ failures: { flashcards: 1 } });
  assert.equal(main(['start'], fixture.context), 1);
  assert.deepEqual(fixture.calls, [
    ['hubs', 'start'],
    ['flashcards', 'start'],
    ['jslibs', 'start'],
    ['misc-projects', 'start'],
  ]);
  assert.deepEqual(fixture.errors, [
    'Failed to start tmux group: flashcards',
  ]);
});

test('aggregate stop uses reverse order and does not attach', () => {
  const fixture = createContext();
  assert.equal(main(['stop'], fixture.context), 0);
  assert.deepEqual(fixture.calls, [
    ['misc-projects', 'stop'],
    ['jslibs', 'stop'],
    ['flashcards', 'stop'],
    ['hubs', 'stop'],
  ]);
});
