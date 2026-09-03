import { spawnSync } from 'node:child_process';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const GROUPS = ['flashcards', 'jslibs', 'misc-projects'];
const AGGREGATE_GROUPS = ['hubs', ...GROUPS];
const LEGACY_SCRIPTS_DIR = fileURLToPath(
  new URL('../../../../../projects/workspaces/', import.meta.url),
);

export function main(arguments_, context = {}) {
  const print = context.print ?? console.log;
  const printError = context.printError ?? console.error;
  const run = context.run ?? runCommand;
  const environment = context.environment ?? process.env;
  const scriptsDir = context.scriptsDir ?? LEGACY_SCRIPTS_DIR;
  const parsed = parseArguments(arguments_, print, printError);

  if (parsed.status !== undefined) {
    return parsed.status;
  }

  if (parsed.group !== undefined) {
    return runLegacyGroup(parsed.group, parsed.action, scriptsDir, run);
  }

  const groups =
    parsed.action === 'start' ? AGGREGATE_GROUPS : [...AGGREGATE_GROUPS].reverse();
  let status = 0;

  for (const group of groups) {
    if (runLegacyGroup(group, parsed.action, scriptsDir, run) !== 0) {
      printError(`Failed to ${parsed.action} tmux group: ${group}`);
      status = 1;
    }
  }

  if (parsed.action === 'stop' || status !== 0) {
    return status;
  }

  if (environment.TMUX) {
    if (run('tmux', ['switch-client', '-t', 'workspaces']) !== 0) {
      printError('Failed to switch to tmux session: workspaces');
      return 1;
    }
  } else if (run('tmux', ['attach-session', '-t', 'workspaces']) !== 0) {
    printError('Failed to attach to tmux session: workspaces');
    return 1;
  }

  return 0;
}

function parseArguments(arguments_, print, printError) {
  if (
    arguments_.length === 1 &&
    ['help', '-h', '--help'].includes(arguments_[0])
  ) {
    print(getHelpText());
    return { status: 0 };
  }

  const [action, ...options] = arguments_;

  if (!['start', 'stop'].includes(action)) {
    if (action === undefined) {
      printError('Missing workspace action.');
    } else {
      printError(`Unknown workspace action: ${action}`);
    }

    printError('');
    printError(getHelpText());
    return { status: 2 };
  }

  if (options.length === 0) {
    return { action };
  }

  if (
    options.length === 2 &&
    ['--group', '-g'].includes(options[0]) &&
    GROUPS.includes(options[1])
  ) {
    return { action, group: options[1] };
  }

  printError(`Invalid workspace options: ${options.join(' ')}`);
  printError('');
  printError(getHelpText());
  return { status: 2 };
}

function runLegacyGroup(group, action, scriptsDir, run) {
  return run(join(scriptsDir, `${group}.sh`), [action]);
}

function runCommand(command, arguments_) {
  const result = spawnSync(command, arguments_, { stdio: 'inherit' });

  if (result.error) {
    console.error(`Could not start command: ${result.error.message}`);
    return 1;
  }

  if (result.signal) {
    process.kill(process.pid, result.signal);
    return 1;
  }

  return result.status ?? 1;
}

function getHelpText() {
  return [
    'Usage: archon workspaces <start|stop> [options]',
    '',
    'Options:',
    '  -g, --group <group>  Run only flashcards, jslibs, or misc-projects',
    '  -h, --help           Show this help',
  ].join('\n');
}
