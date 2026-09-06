import type { StdioOptions } from 'node:child_process';

export interface SessionDefinition {
  session: string;
  directory: string;
}

export interface EditorSessionDefinition extends SessionDefinition {
  devCommand?: string;
}

export interface CaptureResult {
  status: number;
  output: string;
}

export type RunCommand = (
  command: string, arguments_: string[], options?: { stdio?: StdioOptions },
) => number;
export type CaptureCommand = (command: string, arguments_: string[]) => CaptureResult;

export interface Tmux {
  hasSession(session: string): boolean;
  createEditorSession(definition: EditorSessionDefinition): { status: number; cleanupStatus?: number };
  createShellSession(definition: SessionDefinition): number;
  stopSession(session: string): number;
  killSession(session: string): number;
  listSessions(): CaptureResult;
  attachSession(session: string): number;
}

export function createTmux({ run, capture }: { run: RunCommand; capture: CaptureCommand }): Tmux {
  return {
    hasSession: (session) => hasSession(run, session),
    createEditorSession: (definition) => createEditorSession(run, definition),
    createShellSession: ({ session, directory }) => run('tmux', [
      'new-session', '-d', '-s', session, '-c', directory, '-n', 'shell',
    ]),
    stopSession: (session) => stopSession(run, session),
    killSession: (session) => run('tmux', ['kill-session', '-t', session]),
    listSessions: () => capture('tmux', ['list-sessions', '-F', '#S']),
    attachSession: (session) => run('tmux', ['attach-session', '-t', `=${session}`]),
  };
}

function hasSession(run: RunCommand, session: string) {
  return run('tmux', ['has-session', '-t', session], { stdio: 'ignore' }) === 0;
}

function createEditorSession(
  run: RunCommand,
  { session, directory, devCommand }: EditorSessionDefinition,
) {
  const newSessionArguments = [
    'new-session',
    '-d',
    '-s',
    session,
    '-c',
    directory,
    '-n',
    'nvim',
  ];
  const setupOperations = [
    ['send-keys', '-t', `${session}:nvim`, 'nvim .', 'Enter'],
    ['new-window', '-t', session, '-c', directory, '-n', 'codex'],
    ['send-keys', '-t', `${session}:codex`, 'codex resume --last', 'Enter'],
  ];

  if (devCommand !== undefined) {
    setupOperations.push(
      ['new-window', '-t', session, '-c', directory, '-n', 'dev'],
      ['send-keys', '-t', `${session}:dev`, devCommand, 'Enter'],
    );
  }

  setupOperations.push(
    ['new-window', '-t', session, '-c', directory, '-n', 'shell'],
    ['select-window', '-t', `${session}:nvim`],
  );

  if (run('tmux', newSessionArguments) !== 0) {
    return { cleanupStatus: undefined, status: 1 };
  }

  for (const arguments_ of setupOperations) {
    if (run('tmux', arguments_) !== 0) {
      return {
        cleanupStatus: run('tmux', ['kill-session', '-t', session]),
        status: 1,
      };
    }
  }

  return { cleanupStatus: undefined, status: 0 };
}

function stopSession(run: RunCommand, session: string) {
  if (!hasSession(run, session)) {
    return 0;
  }

  return run('tmux', ['kill-session', '-t', session]);
}
