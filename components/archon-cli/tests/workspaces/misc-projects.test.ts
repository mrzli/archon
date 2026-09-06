import assert from 'node:assert/strict';
import { test } from 'bun:test';

import type { EditorSessionDefinition } from '../../src/commands/workspaces/shared/tmux.ts';
import { manageMiscProjects } from '../../src/commands/workspaces/groups/misc-projects.ts';

type Call = ['hasSession' | 'stopSession', string] | ['createEditorSession', EditorSessionDefinition];
interface FixtureOptions {
  readonly directories?: readonly string[];
  readonly failNewSession?: string;
  readonly failStop?: string;
  readonly sessions?: readonly string[];
}

const DEFINITIONS: readonly (readonly string[])[] = [
  ['project-mrzli-archon', '/home/test/projects/personal/mrzli/archon'],
  ['project-mrzli-docs', '/home/test/projects/personal/mrzli/docs'],
  [
    'project-mrzli-js-templates',
    '/home/test/projects/personal/mrzli/js-templates',
  ],
  ['project-mrzli-learning', '/home/test/projects/personal/mrzli/learning'],
  ['project-mrzli-repos', '/home/test/projects/personal/mrzli/repos'],
  ['project-mrzli-skills', '/home/test/projects/personal/mrzli/skills'],
];

function createContext({ directories, failNewSession, failStop, sessions }: FixtureOptions = {}): {
  readonly calls: Call[];
  readonly errors: string[];
  readonly sessions: Set<string>;
  readonly context: Parameters<typeof manageMiscProjects>[1];
} {
  const calls: Call[] = [];
  const errors: string[] = [];
  const presentSessions = new Set(sessions);

  return {
    calls,
    errors,
    sessions: presentSessions,
    context: {
      directoryExists: (directory): boolean =>
        directories === undefined || directories.includes(directory),
      homeDir: '/home/test',
      printError: (message): number => errors.push(message),
      tmux: {
        hasSession(session): boolean {
          calls.push(['hasSession', session]);
          return presentSessions.has(session);
        },
        createEditorSession(definition): { readonly status: number; } {
          calls.push(['createEditorSession', definition]);
          if (definition.session === failNewSession) return { status: 1 };
          presentSessions.add(definition.session);
          return { status: 0 };
        },
        stopSession(session): number {
          calls.push(['stopSession', session]);
          if (session === failStop) return 1;
          presentSessions.delete(session);
          return 0;
        },
      },
    } satisfies Parameters<typeof manageMiscProjects>[1],
  };
}

test('start creates the fixed project sessions once', (): void => {
  const fixture = createContext();
  assert.equal(manageMiscProjects('start', fixture.context), 0);
  assert.deepEqual([...fixture.sessions], DEFINITIONS.map(([session]): string => session));
  assert.deepEqual(
    fixture.calls.filter((call): call is ["createEditorSession", EditorSessionDefinition] => call[0] === 'createEditorSession')
      .map(([, definition]): readonly string[] => [definition.session, definition.directory]),
    DEFINITIONS,
  );

  fixture.calls.length = 0;
  assert.equal(manageMiscProjects('start', fixture.context), 0);
  assert.deepEqual(
    fixture.calls,
    DEFINITIONS.map(([session]): readonly string[] => ['hasSession', session]),
  );
});

test('missing projects are reported and skipped', (): void => {
  const directories: readonly string[] = DEFINITIONS.filter(
    ([session]): boolean => session !== 'project-mrzli-repos',
  ).map(([, directory]): string => directory);
  const fixture = createContext({ directories });

  assert.equal(manageMiscProjects('start', fixture.context), 0);
  assert.deepEqual(
    [...fixture.sessions],
    DEFINITIONS.filter(
      ([session]): boolean => session !== 'project-mrzli-repos',
    ).map(([session]): string => session),
  );
  assert.deepEqual(fixture.errors, [
    'Skipping project-mrzli-repos: directory does not exist: /home/test/projects/personal/mrzli/repos',
  ]);
});

test('a start failure is reported and remaining projects continue', (): void => {
  const fixture = createContext({ failNewSession: 'project-mrzli-docs' });
  assert.equal(manageMiscProjects('start', fixture.context), 1);
  assert.deepEqual(
    [...fixture.sessions],
    DEFINITIONS.filter(([session]): boolean => session !== 'project-mrzli-docs')
      .map(([session]): string => session),
  );
  assert.deepEqual(fixture.errors, [
    'Failed to start tmux session: project-mrzli-docs',
  ]);
});

test('stop removes present sessions and tolerates repeated calls', (): void => {
  const sessions: readonly string[] = DEFINITIONS.map(([session]): string => session);
  const fixture = createContext({ sessions });

  assert.equal(manageMiscProjects('stop', fixture.context), 0);
  assert.deepEqual([...fixture.sessions], []);

  fixture.calls.length = 0;
  assert.equal(manageMiscProjects('stop', fixture.context), 0);
  assert.deepEqual(
    fixture.calls,
    DEFINITIONS.map(([session]): readonly string[] => ['stopSession', session]),
  );
});

test('a stop failure is reported and remaining projects continue', (): void => {
  const sessions: readonly string[] = DEFINITIONS.map(([session]): string => session);
  const fixture = createContext({
    failStop: 'project-mrzli-repos',
    sessions,
  });

  assert.equal(manageMiscProjects('stop', fixture.context), 1);
  assert.deepEqual([...fixture.sessions], ['project-mrzli-repos']);
  assert.deepEqual(fixture.errors, [
    'Failed to stop tmux session: project-mrzli-repos',
  ]);
});
