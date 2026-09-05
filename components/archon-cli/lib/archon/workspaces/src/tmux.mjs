export function hasSession(run, session) {
  return run('tmux', ['has-session', '-t', session], { stdio: 'ignore' }) === 0;
}

export function createEditorSession(
  run,
  { session, directory, devCommand },
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

export function stopSession(run, session) {
  if (!hasSession(run, session)) {
    return 0;
  }

  return run('tmux', ['kill-session', '-t', session]);
}
