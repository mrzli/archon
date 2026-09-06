import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'bun:test';

import type { EditorSessionDefinition, CaptureResult } from '../../src/commands/workspaces/shared/tmux.ts';
import { manageJslibs } from '../../src/commands/workspaces/groups/jslibs.ts';

type Call = ['hasSession' | 'killSession', string] | ['createEditorSession', EditorSessionDefinition];
interface FixtureOptions {
  readonly captureResult?: CaptureResult;
  readonly homeDir?: string;
  readonly sessions?: readonly string[];
}

function createContext({ captureResult, homeDir, sessions: initialSessions }: FixtureOptions = {}): {
  readonly calls: Call[];
  readonly errors: string[];
  readonly sessions: Set<string>;
  readonly context: Parameters<typeof manageJslibs>[1];
} {
  const calls: Call[] = [];
  const errors: string[] = [];
  const sessions = new Set(initialSessions);

  return {
    calls,
    errors,
    sessions,
    context: {
      homeDir: homeDir ?? '/home/test',
      printError: (message): number => errors.push(message),
      tmux: {
        hasSession(session): boolean {
          calls.push(['hasSession', session]);
          return sessions.has(session);
        },
        createEditorSession(definition): { readonly status: number; } {
          calls.push(['createEditorSession', definition]);
          sessions.add(definition.session);
          return { status: 0 };
        },
        killSession(session): number {
          calls.push(['killSession', session]);
          sessions.delete(session);
          return 0;
        },
        listSessions(): CaptureResult {
          return captureResult ?? { status: 0, output: [...sessions].join('\n') };
        },
      },
    } satisfies Parameters<typeof manageJslibs>[1],
  };
}

test('start discovers immediate non-hidden Git repositories', (): void => {
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
      fixture.calls.filter((call): call is ["createEditorSession", EditorSessionDefinition] => call[0] === 'createEditorSession')
        .map(([, definition]): readonly string[] => [definition.session, definition.directory]),
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

test('missing root is reported and skipped', (): void => {
  const fixture = createContext();
  assert.equal(manageJslibs('start', fixture.context), 0);
  assert.deepEqual(fixture.calls, []);
  assert.deepEqual(fixture.errors, [
    'Skipping JavaScript libraries: directory does not exist: /home/test/projects/personal/mrzli-jslib',
  ]);
});

test('stop filters sessions and tolerates repeated calls', (): void => {
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

test('stop tolerates an absent tmux server', (): void => {
  const fixture = createContext({
    captureResult: { status: 1, output: 'no server running on /tmp/tmux' },
  });
  assert.equal(manageJslibs('stop', fixture.context), 0);
  assert.deepEqual(fixture.errors, []);
});

test('stop reports other tmux list failures', (): void => {
  const fixture = createContext({
    captureResult: { status: 1, output: 'permission denied' },
  });
  assert.equal(manageJslibs('stop', fixture.context), 1);
  assert.deepEqual(fixture.errors, [
    'Failed to list tmux sessions: permission denied',
  ]);
});
