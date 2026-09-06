import assert from 'node:assert/strict';
import test from 'node:test';

import { manageFlashcards } from '../../src/commands/workspaces/flashcards.mjs';

function createContext({
  cleanupFails = false,
  directories,
  failFirstNewSession = false,
  failFirstSetupOperation = false,
} = {}) {
  const calls = [];
  const errors = [];
  const sessions = new Set();
  let newSessionFailed = false;
  let setupOperationFailed = false;

  return {
    calls,
    errors,
    sessions,
    context: {
      directoryExists: (directory) =>
        directories === undefined || directories.includes(directory),
      homeDir: '/home/test',
      printError: (message) => errors.push(message),
      tmux: {
        hasSession(session) {
          calls.push(['hasSession', session]);
          return sessions.has(session);
        },
        createEditorSession(definition) {
          calls.push(['createEditorSession', definition]);
          if (failFirstNewSession && !newSessionFailed) {
            newSessionFailed = true;
            return { status: 1 };
          }
          if (failFirstSetupOperation && !setupOperationFailed) {
            setupOperationFailed = true;
            if (cleanupFails) sessions.add(definition.session);
            return { status: 1, cleanupStatus: cleanupFails ? 1 : 0 };
          }
          sessions.add(definition.session);
          return { status: 0 };
        },
        stopSession(session) {
          sessions.delete(session);
          return 0;
        },
      },
    },
  };
}

test('start creates exact flashcards sessions once', () => {
  const fixture = createContext();
  assert.equal(manageFlashcards('start', fixture.context), 0);
  assert.deepEqual([...fixture.sessions], ['flashcards-fe', 'flashcards-be']);
  assert.deepEqual(
    fixture.calls.filter(([operation]) => operation === 'createEditorSession'),
    [
      ['createEditorSession', {
        session: 'flashcards-fe',
        directory: '/home/test/projects/personal/mrzli/flashcards-fe',
        devCommand: 'bun run dev',
      }],
      ['createEditorSession', {
        session: 'flashcards-be',
        directory: '/home/test/projects/personal/mrzli/flashcards-be',
        devCommand: 'pnpm run dev',
      }],
    ],
  );

  fixture.calls.length = 0;
  assert.equal(manageFlashcards('start', fixture.context), 0);
  assert.deepEqual(fixture.calls, [
    ['hasSession', 'flashcards-fe'],
    ['hasSession', 'flashcards-be'],
  ]);
});

test('missing directories are reported and skipped', () => {
  const backend = '/home/test/projects/personal/mrzli/flashcards-be';
  const fixture = createContext({ directories: [backend] });
  assert.equal(manageFlashcards('start', fixture.context), 0);
  assert.deepEqual([...fixture.sessions], ['flashcards-be']);
  assert.deepEqual(fixture.errors, [
    'Skipping flashcards-fe: directory does not exist: /home/test/projects/personal/mrzli/flashcards-fe',
  ]);
});

test('a session failure is reported and remaining sessions continue', () => {
  const fixture = createContext({ failFirstNewSession: true });
  assert.equal(manageFlashcards('start', fixture.context), 1);
  assert.deepEqual([...fixture.sessions], ['flashcards-be']);
  assert.deepEqual(fixture.errors, [
    'Failed to start tmux session: flashcards-fe',
  ]);
});

test('a rolled-back session is retried on a later start', () => {
  const fixture = createContext({ failFirstSetupOperation: true });

  assert.equal(manageFlashcards('start', fixture.context), 1);
  assert.deepEqual([...fixture.sessions], ['flashcards-be']);
  assert.deepEqual(fixture.errors, [
    'Failed to start tmux session: flashcards-fe',
  ]);

  fixture.calls.length = 0;
  fixture.errors.length = 0;
  assert.equal(manageFlashcards('start', fixture.context), 0);
  assert.deepEqual(
    [...fixture.sessions].sort(),
    ['flashcards-be', 'flashcards-fe'],
  );
  assert.deepEqual(fixture.errors, []);
});

test('cleanup failure is reported and remaining sessions continue', () => {
  const fixture = createContext({
    cleanupFails: true,
    failFirstSetupOperation: true,
  });

  assert.equal(manageFlashcards('start', fixture.context), 1);
  assert.deepEqual(
    [...fixture.sessions].sort(),
    ['flashcards-be', 'flashcards-fe'],
  );
  assert.deepEqual(fixture.errors, [
    'Failed to start tmux session: flashcards-fe',
    'Failed to clean up tmux session: flashcards-fe',
  ]);
});

test('stop removes present sessions and tolerates repeated calls', () => {
  const fixture = createContext();
  fixture.sessions.add('flashcards-fe');
  fixture.sessions.add('flashcards-be');

  assert.equal(manageFlashcards('stop', fixture.context), 0);
  assert.deepEqual([...fixture.sessions], []);

  assert.equal(manageFlashcards('stop', fixture.context), 0);
  assert.deepEqual([...fixture.sessions], []);
});
