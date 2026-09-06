import { runLibraries, runProjects, runWorkspaces } from './commands/index.ts';

export async function main(arguments_: string[]) {
  const [commandOrAlias, ...extraArguments] = arguments_;
  const aliases = new Map([
    ['h', 'help'],
    ['l', 'libs'],
    ['p', 'projects'],
    ['w', 'workspaces'],
  ]);
  const command = aliases.get(commandOrAlias) ?? commandOrAlias;

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
    '  help (h)        Show this help',
    '  libs (l)        Manage local JavaScript libraries',
    '  projects (p)    Manage personal project repositories',
    '  workspaces (w)  Manage tmux workspace sessions',
  ].join('\n');
}
