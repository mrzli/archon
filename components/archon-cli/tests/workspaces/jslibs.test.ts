import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'bun:test';

import type { EditorSessionDefinition, CaptureResult } from '../../src/commands/workspaces/tmux.ts';
import { manageJslibs } from '../../src/commands/workspaces/jslibs.ts';

type Call = ['hasSession' | 'killSession', string] | ['createEditorSession', EditorSessionDefinition];
interface FixtureOptions {
  captureResult?: CaptureResult;
  homeDir?: string;
  sessions?: string[];
}

function createContext({ captureResult, homeDir, sessions: initialSessions }: FixtureOptions = {}) {
  const calls: Call[] = [];
  const errors: string[] = [];
  const sessions = new Set(initialSessions);

  return {
    calls,
    errors,
    sessions,
    context: {
      homeDir: homeDir ?? '/home/test',
      printError: (message) => errors.push(message),
      tmux: {
        hasSession(session) {
          calls.push(['hasSession', session]);
          return sessions.has(session);
        },
        createEditorSession(definition) {
          calls.push(['createEditorSession', definition]);
          sessions.add(definition.session);
          return { status: 0 };
        },
        killSession(session) {
          calls.push(['killSession', session]);
          sessions.delete(session);
          return 0;
        },
        listSessions() {
          return captureResult ?? { status: 0, output: [...sessions].join('\n') };
        },
      },
    } satisfies Parameters<typeof manageJslibs>[1],
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
      fixture.calls.filter((call) => call[0] === 'createEditorSession')
        .map(([, definition]) => [definition.session, definition.directory]),
      [
        ['jslib-alpha', `${join(root, 'alpha')}/`],
        ['jslib-beta', `${join(root, 'beta')}/`],
      ],
    );

    fixture.calls.length = 0;
    assert.equal(manageJslibs('start', fixture.context), 0);
    assert.deepEqual(fixture.calls, [
      ['hasSession', 'jslib-alpha'],
      ['hasSession', 'jslib-beta'],
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
    ['killSession', 'jslib-alpha'],
    ['killSession', 'jslib-beta'],
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
