import { spawnSync } from 'node:child_process';

import { manageFlashcards } from './flashcards.mjs';
import { manageGeneral } from './general.mjs';
import { manageJslibs } from './jslibs.mjs';
import { manageMiscProjects } from './misc-projects.mjs';

const GROUPS = ['general', 'flashcards', 'jslibs', 'misc-projects'];
const GROUP_HANDLERS = {
  flashcards: manageFlashcards,
  general: manageGeneral,
  jslibs: manageJslibs,
  'misc-projects': manageMiscProjects,
};

export function main(arguments_, context = {}) {
  const print = context.print ?? console.log;
  const printError = context.printError ?? console.error;
  const run = context.run ?? runCommand;
  const capture = context.capture ?? captureCommand;
  const groupHandlers = context.groupHandlers ?? GROUP_HANDLERS;
  const parsed = parseArguments(arguments_, print, printError);

  if (parsed.status !== undefined) {
    return parsed.status;
  }

  if (parsed.group !== undefined) {
    const status = runGroup(parsed.group, parsed.action, {
      ...context,
      capture,
      groupHandlers,
      printError,
      run,
    });
    return attachAfterStart(status, parsed, { ...context, capture, run });
  }

  const groups =
    parsed.action === 'start' ? GROUPS : [...GROUPS].reverse();
  let status = 0;

  for (const group of groups) {
    if (
      runGroup(group, parsed.action, {
        ...context,
        capture,
        groupHandlers,
        printError,
        run,
      }) !== 0
    ) {
      printError(`Failed to ${parsed.action} tmux group: ${group}`);
      status = 1;
    }
  }

  return attachAfterStart(status, parsed, { ...context, capture, run });
}

function attachAfterStart(status, parsed, context) {
  const environment = context.environment ?? process.env;
  const isTTY = context.isTTY ?? process.stdin.isTTY;
  if (status !== 0 || parsed.action !== 'start' || environment.TMUX || !isTTY) {
    return status;
  }

  const result = context.capture('tmux', ['list-sessions', '-F', '#S']);
  if (result.status !== 0) {
    if (/no server running|no sessions|error connecting/.test(result.output)) {
      return 0;
    }
    (context.printError ?? console.error)(`Failed to list tmux sessions: ${result.output}`);
    return 1;
  }

  const sessions = result.output.split('\n').filter((session) => {
    switch (parsed.group) {
      case 'general': { return session === 'main'; }
      case 'flashcards': { return ['flashcards-fe', 'flashcards-be'].includes(session); }
      case 'jslibs': { return session.startsWith('jslib-'); }
      case 'misc-projects': { return session.startsWith('project-'); }
      default: {
        return session === 'main' || ['flashcards-fe', 'flashcards-be'].includes(session)
          || session.startsWith('jslib-') || session.startsWith('project-');
      }
    }
  });
  const session = sessions.includes('main') ? 'main' : sessions[0];
  return session ? context.run('tmux', ['attach-session', '-t', `=${session}`]) : 0;
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

function runGroup(group, action, context) {
  return context.groupHandlers[group](action, context);
}

function runCommand(command, arguments_, options = {}) {
  const result = spawnSync(command, arguments_, {
    stdio: options.stdio ?? 'inherit',
  });

  if (result.error) {
    console.error(`Could not start command: ${result.error.message}`);
    return 1;
  }

  if (result.signal) {
    return 1;
  }

  return result.status ?? 1;
}

function captureCommand(command, arguments_) {
  const result = spawnSync(command, arguments_, { encoding: 'utf8' });

  if (result.error) {
    return { status: 1, output: result.error.message };
  }

  if (result.signal) {
    return { status: 1, output: '' };
  }

  return {
    status: result.status ?? 1,
    output: `${result.stdout}${result.stderr}`.trimEnd(),
  };
}

function getHelpText() {
  return [
    'Usage: archon workspaces <start|stop> [options]',
    '',
    'Options:',
    '  -g, --group <group>  Run only flashcards, general, jslibs, or misc-projects',
    '  -h, --help           Show this help',
  ].join('\n');
}
