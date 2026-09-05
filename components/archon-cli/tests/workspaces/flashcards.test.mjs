import assert from 'node:assert/strict';
import test from 'node:test';

import { manageFlashcards } from '../../lib/archon/workspaces/src/flashcards.mjs';

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
      run(command, arguments_) {
        assert.equal(command, 'tmux');
        calls.push(arguments_);

        if (arguments_[0] === 'has-session') {
          return sessions.has(arguments_[2]) ? 0 : 1;
        }

        if (
          failFirstNewSession &&
          !newSessionFailed &&
          arguments_[0] === 'new-session'
        ) {
          newSessionFailed = true;
          return 1;
        }

        if (arguments_[0] === 'new-session') {
          sessions.add(arguments_[3]);
        } else if (arguments_[0] === 'kill-session') {
          if (cleanupFails && arguments_[2] === 'flashcards-fe') {
            return 1;
          }

          sessions.delete(arguments_[2]);
        }

        if (
          failFirstSetupOperation &&
          !setupOperationFailed &&
          arguments_[0] === 'send-keys'
        ) {
          setupOperationFailed = true;
          return 1;
        }

        return 0;
      },
    },
  };
}

test('start creates exact flashcards sessions once', () => {
  const fixture = createContext();
  assert.equal(manageFlashcards('start', fixture.context), 0);
  assert.deepEqual([...fixture.sessions], ['flashcards-fe', 'flashcards-be']);
  assert.deepEqual(fixture.calls, [
    ['has-session', '-t', 'flashcards-fe'],
    [
      'new-session',
      '-d',
      '-s',
      'flashcards-fe',
      '-c',
      '/home/test/projects/personal/mrzli/flashcards-fe',
      '-n',
      'nvim',
    ],
    ['send-keys', '-t', 'flashcards-fe:nvim', 'nvim .', 'Enter'],
    [
      'new-window',
      '-t',
      'flashcards-fe',
      '-c',
      '/home/test/projects/personal/mrzli/flashcards-fe',
      '-n',
      'codex',
    ],
    [
      'send-keys',
      '-t',
      'flashcards-fe:codex',
      'codex resume --last',
      'Enter',
    ],
    [
      'new-window',
      '-t',
      'flashcards-fe',
      '-c',
      '/home/test/projects/personal/mrzli/flashcards-fe',
      '-n',
      'dev',
    ],
    ['send-keys', '-t', 'flashcards-fe:dev', 'bun run dev', 'Enter'],
    [
      'new-window',
      '-t',
      'flashcards-fe',
      '-c',
      '/home/test/projects/personal/mrzli/flashcards-fe',
      '-n',
      'shell',
    ],
    ['select-window', '-t', 'flashcards-fe:nvim'],
    ['has-session', '-t', 'flashcards-be'],
    [
      'new-session',
      '-d',
      '-s',
      'flashcards-be',
      '-c',
      '/home/test/projects/personal/mrzli/flashcards-be',
      '-n',
      'nvim',
    ],
    ['send-keys', '-t', 'flashcards-be:nvim', 'nvim .', 'Enter'],
    [
      'new-window',
      '-t',
      'flashcards-be',
      '-c',
      '/home/test/projects/personal/mrzli/flashcards-be',
      '-n',
      'codex',
    ],
    [
      'send-keys',
      '-t',
      'flashcards-be:codex',
      'codex resume --last',
      'Enter',
    ],
    [
      'new-window',
      '-t',
      'flashcards-be',
      '-c',
      '/home/test/projects/personal/mrzli/flashcards-be',
      '-n',
      'dev',
    ],
    ['send-keys', '-t', 'flashcards-be:dev', 'pnpm run dev', 'Enter'],
    [
      'new-window',
      '-t',
      'flashcards-be',
      '-c',
      '/home/test/projects/personal/mrzli/flashcards-be',
      '-n',
      'shell',
    ],
    ['select-window', '-t', 'flashcards-be:nvim'],
  ]);

  fixture.calls.length = 0;
  assert.equal(manageFlashcards('start', fixture.context), 0);
  assert.deepEqual(fixture.calls, [
    ['has-session', '-t', 'flashcards-fe'],
    ['has-session', '-t', 'flashcards-be'],
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

test('a partial session is rolled back and a later start retries it', () => {
  const fixture = createContext({ failFirstSetupOperation: true });

  assert.equal(manageFlashcards('start', fixture.context), 1);
  assert.deepEqual([...fixture.sessions], ['flashcards-be']);
  assert.deepEqual(fixture.errors, [
    'Failed to start tmux session: flashcards-fe',
  ]);
  assert.ok(
    fixture.calls.some(
      (arguments_) =>
        arguments_[0] === 'kill-session' && arguments_[2] === 'flashcards-fe',
    ),
  );

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
