export function hasSession(run, session) {
  return run('tmux', ['has-session', '-t', session], { stdio: 'ignore' }) === 0;
}

export function createEditorSession(
  run,
  { session, directory, devCommand },
) {
  const operations = [
    ['new-session', '-d', '-s', session, '-c', directory, '-n', 'nvim'],
    ['send-keys', '-t', `${session}:nvim`, 'nvim .', 'Enter'],
    ['new-window', '-t', session, '-c', directory, '-n', 'codex'],
    ['send-keys', '-t', `${session}:codex`, 'codex resume --last', 'Enter'],
  ];

  if (devCommand !== undefined) {
    operations.push(
      ['new-window', '-t', session, '-c', directory, '-n', 'dev'],
      ['send-keys', '-t', `${session}:dev`, devCommand, 'Enter'],
    );
  }

  operations.push(
    ['new-window', '-t', session, '-c', directory, '-n', 'shell'],
    ['select-window', '-t', `${session}:nvim`],
  );

  for (const arguments_ of operations) {
    if (run('tmux', arguments_) !== 0) {
      return 1;
    }
  }

  return 0;
}

export function stopSession(run, session) {
  if (!hasSession(run, session)) {
    return 0;
  }

  return run('tmux', ['kill-session', '-t', session]);
}
