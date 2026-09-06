import assert from 'node:assert/strict';
import { test } from 'bun:test';

import type { WorkspaceContext, WorkspaceGroup } from '../../src/commands/workspaces/workspaces.ts';
import type { WorkspaceAction } from '../../src/commands/workspaces/group-context.ts';
import type { CaptureResult, SessionDefinition, Tmux } from '../../src/commands/workspaces/tmux.ts';
import { runWorkspaces } from '../../src/commands/workspaces/index.ts';

interface FixtureOptions {
  failures?: Partial<Record<WorkspaceGroup, number>>;
  tmux?: string;
}

function unexpectedTmuxOperation(): never {
  throw new Error('unexpected tmux operation');
}

function createContext({ failures = {}, tmux = '' }: FixtureOptions = {}): {
  calls: [WorkspaceGroup, WorkspaceAction][];
  errors: string[];
  output: string[];
  context: WorkspaceContext & { tmux: Tmux };
} {
  const calls: [WorkspaceGroup, WorkspaceAction][] = [];
  const errors: string[] = [];
  const output: string[] = [];

  return {
    calls,
    errors,
    output,
    context: {
      environment: { TMUX: tmux },
      isTTY: false,
      tmux: {
        hasSession: unexpectedTmuxOperation,
        createEditorSession: unexpectedTmuxOperation,
        createShellSession: unexpectedTmuxOperation,
        stopSession: unexpectedTmuxOperation,
        killSession: unexpectedTmuxOperation,
        listSessions: () => { throw new Error('unexpected session lookup'); },
        attachSession: () => { throw new Error('unexpected attachment'); },
      },
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
  assert.equal(runWorkspaces(['--help'], help.context), 0);
  assert.match(help.output.join('\n'), /^Usage: archon workspaces/);
  assert.deepEqual(help.calls, []);

  const missing = createContext();
  assert.equal(runWorkspaces([], missing.context), 2);
  assert.match(missing.errors.join('\n'), /Missing workspace action/);
  assert.deepEqual(missing.calls, []);

  const hubs = createContext();
  assert.equal(runWorkspaces(['start', '--group', 'hubs'], hubs.context), 2);
  assert.deepEqual(hubs.calls, []);
});

test('group options run only their selected group', () => {
  for (const option of ['--group', '-g']) {
    for (const group of ['flashcards', 'general', 'jslibs', 'misc-projects']) {
      const fixture = createContext();
      assert.equal(runWorkspaces(['start', option, group], fixture.context), 0);
      assert.deepEqual(fixture.calls, [[group, 'start']]);
    }
  }
});

test('an injected tmux object reaches real group handlers and attachment', () => {
  const fixture = createContext();
  const calls: (SessionDefinition | string)[] = [];
  delete fixture.context.groupHandlers;
  fixture.context.homeDir = '/home/test';
  fixture.context.directoryExists = () => true;
  fixture.context.isTTY = true;
  fixture.context.capture = () => { throw new Error('unexpected process capture'); };
  fixture.context.tmux = {
    ...fixture.context.tmux,
    hasSession: () => false,
    createShellSession(definition) {
      calls.push(definition);
      return 0;
    },
    listSessions: () => ({ status: 0, output: 'main' }),
    attachSession(session) {
      calls.push(session);
      return 0;
    },
  };

  assert.equal(runWorkspaces(['start', '-g', 'general'], fixture.context), 0);
  assert.deepEqual(calls, [
    { session: 'main', directory: '/home/test/projects' },
    'main',
  ]);
});

test('aggregate start runs every group without attaching or switching', () => {
  const fixture = createContext({ tmux: 'client' });
  assert.equal(runWorkspaces(['start'], fixture.context), 0);
  assert.deepEqual(fixture.calls, [
    ['general', 'start'],
    ['flashcards', 'start'],
    ['jslibs', 'start'],
    ['misc-projects', 'start'],
  ]);
});

test('aggregate start continues after failure', () => {
  const fixture = createContext({ failures: { flashcards: 1 } });
  assert.equal(runWorkspaces(['start'], fixture.context), 1);
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
  assert.equal(runWorkspaces(['stop'], fixture.context), 0);
  assert.deepEqual(fixture.calls, [
    ['misc-projects', 'stop'],
    ['jslibs', 'stop'],
    ['flashcards', 'stop'],
    ['general', 'stop'],
  ]);
});

test('aggregate stop continues after failure', () => {
  const fixture = createContext({ failures: { jslibs: 1 } });
  assert.equal(runWorkspaces(['stop'], fixture.context), 1);
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
    fixture.context.tmux.listSessions = () => {
      return { status: 0, output: '0\nflashcards-be\njslib-example\nmain\nproject-mrzli-archon' };
    };
    const attachments: string[] = [];
    fixture.context.tmux.attachSession = (session) => {
      attachments.push(session);
      return 0;
    };
    assert.equal(runWorkspaces(group ? ['start', '-g', group] : ['start'], fixture.context), 0);
    assert.deepEqual(attachments, [target]);
  }
});

test('interactive calls inside tmux, stop, help, and failed starts do not attach', () => {
  for (const [arguments_, options, status] of [
    [['start'], { tmux: 'client' }, 0],
    [['stop'], {}, 0],
    [['--help'], {}, 0],
    [['start'], { failures: { general: 1 } }, 1],
  ] satisfies [string[], FixtureOptions, number][]) {
    const fixture = createContext(options);
    fixture.context.isTTY = true;
    fixture.context.tmux.listSessions = () => { throw new Error('unexpected session lookup'); };
    assert.equal(runWorkspaces(arguments_, fixture.context), status);
  }
});

test('attachment skips absent group sessions and propagates failures', () => {
  for (const [result, attachStatus, expected] of [
    [{ status: 0, output: 'unrelated' }, 0, 0],
    [{ status: 1, output: 'no server running on socket' }, 0, 0],
    [{ status: 1, output: 'permission denied' }, 0, 1],
    [{ status: 0, output: 'main' }, 1, 1],
  ] satisfies [CaptureResult, number, number][]) {
    const fixture = createContext();
    fixture.context.isTTY = true;
    fixture.context.tmux.listSessions = () => result;
    fixture.context.tmux.attachSession = () => {
      assert.equal(result.output, 'main');
      return attachStatus;
    };
    assert.equal(runWorkspaces(['start', '-g', 'general'], fixture.context), expected);
  }
});
