import assert from 'node:assert/strict';
import test from 'node:test';

import { manageMiscProjects } from '../../lib/archon/workspaces/src/misc-projects.mjs';

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
      run(command, arguments_) {
        assert.equal(command, 'tmux');
        calls.push(arguments_);

        if (arguments_[0] === 'has-session') {
          return presentSessions.has(arguments_[2]) ? 0 : 1;
        }

        if (arguments_[0] === 'new-session') {
          if (arguments_[3] === failNewSession) {
            return 1;
          }

          presentSessions.add(arguments_[3]);
        } else if (arguments_[0] === 'kill-session') {
          if (arguments_[2] === failStop) {
            return 1;
          }

          presentSessions.delete(arguments_[2]);
        }

        return 0;
      },
    },
  };
}

function expectedStartOperations(session, directory) {
  return [
    ['has-session', '-t', session],
    ['new-session', '-d', '-s', session, '-c', directory, '-n', 'nvim'],
    ['send-keys', '-t', `${session}:nvim`, 'nvim .', 'Enter'],
    ['new-window', '-t', session, '-c', directory, '-n', 'codex'],
    [
      'send-keys',
      '-t',
      `${session}:codex`,
      'codex resume --last',
      'Enter',
    ],
    ['new-window', '-t', session, '-c', directory, '-n', 'shell'],
    ['select-window', '-t', `${session}:nvim`],
  ];
}

test('start creates the fixed project sessions and exact windows once', () => {
  const fixture = createContext();
  assert.equal(manageMiscProjects('start', fixture.context), 0);
  assert.deepEqual([...fixture.sessions], DEFINITIONS.map(([session]) => session));
  assert.deepEqual(
    fixture.calls,
    DEFINITIONS.flatMap(([session, directory]) =>
      expectedStartOperations(session, directory),
    ),
  );

  fixture.calls.length = 0;
  assert.equal(manageMiscProjects('start', fixture.context), 0);
  assert.deepEqual(
    fixture.calls,
    DEFINITIONS.map(([session]) => ['has-session', '-t', session]),
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
    DEFINITIONS.map(([session]) => ['has-session', '-t', session]),
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
