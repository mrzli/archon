import assert from 'node:assert/strict';
import { test } from 'bun:test';

import { manageMiscProjects } from '../../src/commands/workspaces/misc-projects.mjs';

const DEFINITIONS = [
  ['project-mrzli-docs', '/home/test/projects/personal/mrzli/docs'],
  ['project-mrzli-repos', '/home/test/projects/personal/mrzli/repos'],
  ['project-mrzli-archon', '/home/test/projects/personal/mrzli/archon'],
  [
    'project-mrzli-js-templates',
    '/home/test/projects/personal/mrzli/js-templates',
  ],
];

function createContext({ directories, failNewSession, failStop, sessions } = {}) {
  const calls = [];
  const errors = [];
  const presentSessions = new Set(sessions);

  return {
    calls,
    errors,
    sessions: presentSessions,
    context: {
      directoryExists: (directory) =>
        directories === undefined || directories.includes(directory),
      homeDir: '/home/test',
      printError: (message) => errors.push(message),
      tmux: {
        hasSession(session) {
          calls.push(['hasSession', session]);
          return presentSessions.has(session);
        },
        createEditorSession(definition) {
          calls.push(['createEditorSession', definition]);
          if (definition.session === failNewSession) return { status: 1 };
          presentSessions.add(definition.session);
          return { status: 0 };
        },
        stopSession(session) {
          calls.push(['stopSession', session]);
          if (session === failStop) return 1;
          presentSessions.delete(session);
          return 0;
        },
      },
    },
  };
}

test('start creates the fixed project sessions once', () => {
  const fixture = createContext();
  assert.equal(manageMiscProjects('start', fixture.context), 0);
  assert.deepEqual([...fixture.sessions], DEFINITIONS.map(([session]) => session));
  assert.deepEqual(
    fixture.calls.filter(([operation]) => operation === 'createEditorSession')
      .map(([, definition]) => [definition.session, definition.directory]),
    DEFINITIONS,
  );

  fixture.calls.length = 0;
  assert.equal(manageMiscProjects('start', fixture.context), 0);
  assert.deepEqual(
    fixture.calls,
    DEFINITIONS.map(([session]) => ['hasSession', session]),
  );
});

test('missing projects are reported and skipped', () => {
  const directories = DEFINITIONS.filter(
    ([session]) => session !== 'project-mrzli-repos',
  ).map(([, directory]) => directory);
  const fixture = createContext({ directories });

  assert.equal(manageMiscProjects('start', fixture.context), 0);
  assert.deepEqual(
    [...fixture.sessions],
    DEFINITIONS.filter(
      ([session]) => session !== 'project-mrzli-repos',
    ).map(([session]) => session),
  );
  assert.deepEqual(fixture.errors, [
    'Skipping project-mrzli-repos: directory does not exist: /home/test/projects/personal/mrzli/repos',
  ]);
});

test('a start failure is reported and remaining projects continue', () => {
  const fixture = createContext({ failNewSession: 'project-mrzli-docs' });
  assert.equal(manageMiscProjects('start', fixture.context), 1);
  assert.deepEqual(
    [...fixture.sessions],
    DEFINITIONS.slice(1).map(([session]) => session),
  );
  assert.deepEqual(fixture.errors, [
    'Failed to start tmux session: project-mrzli-docs',
  ]);
});

test('stop removes present sessions and tolerates repeated calls', () => {
  const sessions = DEFINITIONS.map(([session]) => session);
  const fixture = createContext({ sessions });

  assert.equal(manageMiscProjects('stop', fixture.context), 0);
  assert.deepEqual([...fixture.sessions], []);

  fixture.calls.length = 0;
  assert.equal(manageMiscProjects('stop', fixture.context), 0);
  assert.deepEqual(
    fixture.calls,
    DEFINITIONS.map(([session]) => ['stopSession', session]),
  );
});

test('a stop failure is reported and remaining projects continue', () => {
  const sessions = DEFINITIONS.map(([session]) => session);
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
