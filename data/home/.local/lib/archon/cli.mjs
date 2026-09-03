const HELP_ARGUMENTS = new Set(['help', '-h', '--help']);

export async function main(arguments_) {
  const [command, ...extraArguments] = arguments_;

  if (HELP_ARGUMENTS.has(command) && extraArguments.length === 0) {
    printGlobalHelp();
    return 0;
  }

  if (command === undefined) {
    console.error('Missing command.');
  } else if (HELP_ARGUMENTS.has(command)) {
    console.error(`Unexpected help argument: ${extraArguments[0]}`);
  } else {
    console.error(`Unknown command: ${command}`);
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
