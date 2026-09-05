import assert from 'node:assert/strict';
import test from 'node:test';

import { main } from '../../lib/archon/workspaces/src/workspaces.mjs';

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
      isTTY: false,
      groupHandlers: {
        general(action) {
          calls.push(['general', action]);
          return failures.general ?? 0;
        },
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
    for (const group of ['flashcards', 'general', 'jslibs', 'misc-projects']) {
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
    ['general', 'start'],
    ['flashcards', 'start'],
    ['jslibs', 'start'],
    ['misc-projects', 'start'],
  ]);
});

test('aggregate start continues after failure', () => {
  const fixture = createContext({ failures: { flashcards: 1 } });
  assert.equal(main(['start'], fixture.context), 1);
  assert.deepEqual(fixture.calls, [
    ['general', 'start'],
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
    ['general', 'stop'],
  ]);
});

test('aggregate stop continues after failure', () => {
  const fixture = createContext({ failures: { jslibs: 1 } });
  assert.equal(main(['stop'], fixture.context), 1);
  assert.deepEqual(fixture.calls, [
    ['misc-projects', 'stop'],
    ['jslibs', 'stop'],
    ['flashcards', 'stop'],
    ['general', 'stop'],
  ]);
  assert.deepEqual(fixture.errors, ['Failed to stop tmux group: jslibs']);
});

test('interactive starts attach to an existing session in the requested group', () => {
  for (const [group, target] of [
    [undefined, 'main'],
    ['general', 'main'],
    ['flashcards', 'flashcards-be'],
    ['jslibs', 'jslib-example'],
    ['misc-projects', 'project-mrzli-archon'],
  ]) {
    const fixture = createContext();
    fixture.context.isTTY = true;
    fixture.context.capture = (command, arguments_) => {
      assert.equal(command, 'tmux');
      assert.deepEqual(arguments_, ['list-sessions', '-F', '#S']);
      return { status: 0, output: '0\nflashcards-be\njslib-example\nmain\nproject-mrzli-archon' };
    };
    const attachments = [];
    fixture.context.run = (command, arguments_) => {
      attachments.push([command, ...arguments_]);
      return 0;
    };
    assert.equal(main(group ? ['start', '-g', group] : ['start'], fixture.context), 0);
    assert.deepEqual(attachments, [['tmux', 'attach-session', '-t', `=${target}`]]);
  }
});

test('interactive calls inside tmux, stop, help, and failed starts do not attach', () => {
  for (const [arguments_, options, status] of [
    [['start'], { tmux: 'client' }, 0],
    [['stop'], {}, 0],
    [['--help'], {}, 0],
    [['start'], { failures: { general: 1 } }, 1],
  ]) {
    const fixture = createContext(options);
    fixture.context.isTTY = true;
    fixture.context.capture = () => { throw new Error('unexpected session lookup'); };
    assert.equal(main(arguments_, fixture.context), status);
  }
});

test('attachment skips absent group sessions and propagates failures', () => {
  for (const [result, attachStatus, expected] of [
    [{ status: 0, output: 'unrelated' }, 0, 0],
    [{ status: 1, output: 'no server running on socket' }, 0, 0],
    [{ status: 1, output: 'permission denied' }, 0, 1],
    [{ status: 0, output: 'main' }, 1, 1],
  ]) {
    const fixture = createContext();
    fixture.context.isTTY = true;
    fixture.context.capture = () => result;
    fixture.context.run = () => {
      assert.equal(result.output, 'main');
      return attachStatus;
    };
    assert.equal(main(['start', '-g', 'general'], fixture.context), expected);
  }
});
