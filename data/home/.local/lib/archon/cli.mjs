import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ARCHON_LIB_DIR = dirname(fileURLToPath(import.meta.url));

export async function main(arguments_) {
  const [command, ...extraArguments] = arguments_;

  switch (command) {
    case 'projects': {
      return runNodeCommand(
        join(ARCHON_LIB_DIR, 'projects/src/projects.mjs'),
        extraArguments,
      );
    }
    case 'help':
    case '-h':
    case '--help': {
      if (extraArguments.length === 0) {
        printGlobalHelp();
        return 0;
      }

      console.error(`Unexpected help argument: ${extraArguments[0]}`);
      break;
    }
    case undefined: {
      console.error('Missing command.');
      break;
    }
    default: {
      console.error(`Unknown command: ${command}`);
      break;
    }
  }

  console.error('');
  printGlobalHelp(console.error);
  return 2;
}

function runNodeCommand(script, arguments_) {
  const result = spawnSync(process.execPath, [script, ...arguments_], {
    stdio: 'inherit',
  });

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

function printGlobalHelp(print = console.log) {
  print(getGlobalHelpText());
}

function getGlobalHelpText() {
  return [
    'Usage: archon <command> [options]',
    '',
    'Commands:',
    '  libs        Manage local JavaScript libraries',
    '  projects    Manage personal project repositories',
    '  workspaces  Manage tmux workspace sessions',
    '  help        Show this help',
  ].join('\n');
}
