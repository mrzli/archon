import { main as runLibraries } from './libs/src/libs.mjs';
import { main as runProjects } from './projects/src/projects.mjs';
import { main as runWorkspaces } from './workspaces/src/workspaces.mjs';

export async function main(arguments_) {
  const [command, ...extraArguments] = arguments_;

  switch (command) {
    case 'libs': {
      return runLibraries(extraArguments);
    }
    case 'projects': {
      return runProjects(extraArguments);
    }
    case 'workspaces': {
      return runWorkspaces(extraArguments);
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
