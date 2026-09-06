import { spawnSync } from 'node:child_process';

import type { GroupContext, WorkspaceAction } from './group-context.ts';
import type { CaptureCommand, CaptureResult, RunCommand, Tmux } from './tmux.ts';
import { manageFlashcards } from './flashcards.ts';
import { manageGeneral } from './general.ts';
import { manageJslibs } from './jslibs.ts';
import { manageMiscProjects } from './misc-projects.ts';
import { createTmux } from './tmux.ts';

export type WorkspaceGroup = typeof GROUPS[number];
type GroupHandlers = Record<WorkspaceGroup, (action: WorkspaceAction, context: GroupContext) => number>;
export interface WorkspaceContext extends Partial<GroupContext> {
  readonly environment?: NodeJS.ProcessEnv;
  readonly isTTY?: boolean;
  readonly groupHandlers?: GroupHandlers;
  readonly print?: (message: string) => void;
  readonly run?: RunCommand;
  readonly capture?: CaptureCommand;
}

type ActiveContext = WorkspaceContext & { readonly tmux: Tmux; readonly groupHandlers: GroupHandlers };
interface ParsedAction {
  readonly action: WorkspaceAction;
  readonly group?: WorkspaceGroup;
}

const GROUPS = ['general', 'flashcards', 'jslibs', 'misc-projects'] as const;
const GROUP_HANDLERS = {
  flashcards: manageFlashcards,
  general: manageGeneral,
  jslibs: manageJslibs,
  'misc-projects': manageMiscProjects,
};

export function runWorkspaces(arguments_: readonly string[], context: WorkspaceContext = {}): number {
  const print = context.print ?? console.log;
  const printError = context.printError ?? console.error;
  const parsed = parseArguments(arguments_, print, printError);

  if ('status' in parsed) {
    return parsed.status;
  }

  const groupContext = {
    ...context,
    groupHandlers: context.groupHandlers ?? GROUP_HANDLERS,
    printError,
    tmux: context.tmux ?? createTmux({
      run: context.run ?? runCommand,
      capture: context.capture ?? captureCommand,
    }),
  };

  if (parsed.group !== undefined) {
    const status = runGroup(parsed.group, parsed.action, groupContext);
    return attachAfterStart(status, parsed, groupContext);
  }

  const groups =
    parsed.action === 'start' ? GROUPS : [...GROUPS].reverse();
  let status = 0;

  for (const group of groups) {
    if (runGroup(group, parsed.action, groupContext) !== 0) {
      printError(`Failed to ${parsed.action} tmux group: ${group}`);
      status = 1;
    }
  }

  return attachAfterStart(status, parsed, groupContext);
}

function attachAfterStart(status: number, parsed: ParsedAction, context: ActiveContext): number {
  const environment = context.environment ?? process.env;
  const isTTY = context.isTTY ?? process.stdin.isTTY;
  if (status !== 0 || parsed.action !== 'start' || environment.TMUX || !isTTY) {
    return status;
  }

  const result = context.tmux.listSessions();
  if (result.status !== 0) {
    if (/no server running|no sessions|error connecting/.test(result.output)) {
      return 0;
    }
    (context.printError ?? console.error)(`Failed to list tmux sessions: ${result.output}`);
    return 1;
  }

  const sessions: readonly string[] = result.output.split('\n').filter((session): boolean => {
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
  return session ? context.tmux.attachSession(session) : 0;
}

function isGroup(value: string): value is WorkspaceGroup {
  return GROUPS.some((group): boolean => group === value);
}

function parseArguments(
  arguments_: readonly string[],
  print: (message: string) => void,
  printError: (message: string) => void,
): ParsedAction | { readonly status: number } {
  if (
    arguments_.length === 1 &&
    ['help', '-h', '--help'].includes(arguments_[0])
  ) {
    print(getHelpText());
    return { status: 0 };
  }

  const [action, ...options] = arguments_;

  if (action !== 'start' && action !== 'stop') {
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
    isGroup(options[1])
  ) {
    return { action, group: options[1] };
  }

  printError(`Invalid workspace options: ${options.join(' ')}`);
  printError('');
  printError(getHelpText());
  return { status: 2 };
}

function runGroup(group: WorkspaceGroup, action: WorkspaceAction, context: ActiveContext): number {
  return context.groupHandlers[group](action, context);
}

function runCommand(
  command: string, arguments_: readonly string[], options: Parameters<RunCommand>[2] = {},
): number {
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

function captureCommand(command: string, arguments_: readonly string[]): CaptureResult {
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

function getHelpText(): string {
  return [
    'Usage: archon workspaces <start|stop> [options]',
    '',
    'Options:',
    '  -g, --group <group>  Run only flashcards, general, jslibs, or misc-projects',
    '  -h, --help           Show this help',
  ].join('\n');
}
