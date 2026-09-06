import { spawnSync } from 'node:child_process';
import { closeSync, mkdirSync, openSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

export function runDetachedStop(
  arguments_: readonly string[],
  moduleUrl: string,
): number {
  const directory = join(process.env.XDG_STATE_HOME ?? join(homedir(), '.local/state'), 'archon');
  mkdirSync(directory, { recursive: true });
  const log = join(directory, 'workspaces-stop.log');
  const descriptor = openSync(log, 'a', 0o600);

  try {
    console.log(`Stopping workspaces independently; output: ${log}`);
    const result = spawnSync('setsid', ['--wait', process.execPath, '--eval',
      `import { runWorkspaces } from ${JSON.stringify(moduleUrl)};\n`
      + `process.exitCode = runWorkspaces(${JSON.stringify(arguments_)}, { environment: {} });`,
    ], {
      stdio: ['ignore', descriptor, descriptor],
    });

    if (result.error) {
      console.error(`Could not start workspace shutdown: ${result.error.message}`);
      return 1;
    }

    const status = result.status ?? 1;
    if (status !== 0) {
      console.error(`Workspace shutdown failed; see ${log}`);
    }
    return status;
  } finally {
    closeSync(descriptor);
  }
}
