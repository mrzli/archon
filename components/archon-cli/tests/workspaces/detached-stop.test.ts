import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { setTimeout } from 'node:timers/promises';
import { test } from 'bun:test';

import { createFixture, removeFixture, runArchon, writeExecutable } from '../test-helpers.ts';

const archon = fileURLToPath(new URL('../../dist/bin/arc', import.meta.url));
const projects = ['archon', 'docs', 'js-templates', 'learning', 'repos']
  .map((name): string => `project-mrzli-${name}`);
const otherGroups = ['jslib-example', 'flashcards-fe', 'flashcards-be', 'main'];

for (const group of [undefined, 'misc-projects']) {
  test(`stop survives its calling pane closing (${group ?? 'all groups'})`, async (): Promise<void> => {
    const fixture = createFixture('detached-stop');
    const socket = join(fixture.root, 'tmux.sock');
    const environment = { ...process.env, TMUX: '', TMUX_PANE: '' };
    function tmux(arguments_: readonly string[]): string {
      const result = spawnSync('tmux', ['-S', socket, '-f', '/dev/null', ...arguments_], {
        env: environment,
        encoding: 'utf8',
      });
      assert.equal(result.status, 0, result.stderr || result.error?.message || 'tmux failed');
      return result.stdout.trim();
    }

    try {
      for (const session of [...projects, ...otherGroups, 'unrelated']) {
        tmux(['new-session', '-d', '-s', session, 'sleep', '60']);
      }
      tmux(['new-window', '-t', '=project-mrzli-archon', '-n', 'stopper',
        '/usr/bin/env', `HOME=${fixture.home}`,
        `XDG_STATE_HOME=${join(fixture.home, '.local/state')}`,
        `PATH=${process.env.PATH}`, process.execPath, archon, 'w', 'stop',
        ...(group ? ['-g', group] : []),
      ]);

      const expected = [...(group ? otherGroups : []), 'unrelated'].sort();
      let sessions: string[] = [];
      const deadline = Date.now() + 5000;
      do {
        sessions = tmux(['list-sessions', '-F', '#S']).split('\n').sort();
        if (JSON.stringify(sessions) === JSON.stringify(expected)) break;
        await setTimeout(50);
      } while (Date.now() < deadline);
      assert.deepEqual(sessions, expected);
    } finally {
      spawnSync('tmux', ['-S', socket, 'kill-server'], { env: environment, stdio: 'ignore' });
      removeFixture(fixture);
    }
  }, 10000);
}

test('detached shutdown returns failures and saves diagnostics after losing terminal output', (): void => {
  const fixture = createFixture('detached-stop-failure');
  const state = join(fixture.home, '.local/state');
  try {
    writeExecutable(join(fixture.bin, 'tmux'), `#!/bin/sh
case "$1" in
  has-session) exit 0 ;;
  kill-session) echo 'injected kill failure' >&2; exit 1 ;;
  *) exit 2 ;;
esac
`);
    const result = runArchon(fixture, ['w', 'stop', '-g', 'general'], {
      TMUX: 'fixture-server',
      XDG_STATE_HOME: state,
    });
    assert.equal(result.status, 1);
    assert.match(result.stderr, /Workspace shutdown failed/);
    const log = readFileSync(join(state, 'archon/workspaces-stop.log'), 'utf8');
    assert.match(log, /injected kill failure/);
    assert.match(log, /Failed to stop tmux session: main/);
  } finally {
    removeFixture(fixture);
  }
});
