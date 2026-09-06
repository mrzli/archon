import type { Interface, ReadLineOptions } from 'node:readline/promises';
import { rmSync } from 'node:fs';
import { resolve } from 'node:path';
import { createInterface } from 'node:readline/promises';

import type { Repository } from './git.ts';
import type { RepositoryStatus } from './repository-inspection.ts';
import { isHelpRequest } from './arguments.ts';
import { getErrorMessage, toSingleLine } from './errors.ts';
import {
  formatChanges,
  hasWorkingTreeChanges,
} from './repository-inspection.ts';

interface DestructiveOptions<R extends Repository> {
  rootDir: string;
  requiredRootDir: string;
  printHelp: () => void;
  inspectRepositories: (repositories: R[], fetch: boolean) => RepositoryStatus[];
  confirmDeletion?: (statuses: RepositoryStatus[]) => Promise<boolean>;
  removeRepositories?: (repositories: R[]) => number;
}

export interface DeleteOptions<R extends Repository> extends DestructiveOptions<R> {
  findRepositories: () => R[];
  emptyMessage: string;
}

export interface PruneOptions<L extends Repository, R> extends DestructiveOptions<L> {
  getRemoteRepositories: (refresh: boolean) => R[];
  findPrunableRepositories: (remote: R[]) => L[] | undefined;
  findRestoredRepositories: (local: L[], remote: R[]) => L[];
  getRepositoryName: (repository: L) => string;
}

export interface ConfirmationContext {
  input?: NodeJS.ReadableStream & { isTTY?: boolean };
  output?: NodeJS.WritableStream & { isTTY?: boolean };
  print?: (message: string) => void;
  printError?: (message: string) => void;
  createInterface?: (options: ReadLineOptions) => Pick<Interface, 'question' | 'close'>;
}

export interface RemovalContext {
  print?: (message: string) => void;
  printError?: (message: string) => void;
  remove?: (path: string, options: { recursive: true; force: false }) => void;
}


export async function deleteRepositories<R extends Repository>(
  arguments_: readonly string[],
  options: DeleteOptions<R>,
) {
  if (isHelpRequest(arguments_)) {
    options.printHelp();
    return 0;
  }

  const dryRun = parseArguments(arguments_, 'delete', options.printHelp);

  if (dryRun === undefined) {
    return 2;
  }

  if (!isDeletionRootSafe(options.rootDir, options.requiredRootDir)) {
    return 1;
  }

  const repositories = options.findRepositories();

  if (repositories.length === 0) {
    console.log(options.emptyMessage);
    return 0;
  }

  if (dryRun) {
    console.log('Dry run; the following directories would be deleted:');
    printRepositoryPaths(repositories);
    return 0;
  }

  const statuses = options.inspectRepositories(repositories, false);
  const uncleanStatuses = statuses.filter(isLocalRepositoryUnclean);

  console.log('The following directories will be permanently deleted:');
  printRepositoryPaths(repositories);
  console.log('');

  const confirmDeletion = options.confirmDeletion ?? confirmRepositoryDeletion;

  if (!(await confirmDeletion(uncleanStatuses))) {
    return 1;
  }

  const removeRepositories =
    options.removeRepositories ?? removeLocalRepositories;
  return removeRepositories(repositories);
}

export async function pruneRepositories<L extends Repository, R>(
  arguments_: readonly string[],
  options: PruneOptions<L, R>,
) {
  if (isHelpRequest(arguments_)) {
    options.printHelp();
    return 0;
  }

  const dryRun = parseArguments(arguments_, 'prune', options.printHelp);

  if (dryRun === undefined) {
    return 2;
  }

  if (!isDeletionRootSafe(options.rootDir, options.requiredRootDir)) {
    return 1;
  }

  let remoteRepositories;

  try {
    remoteRepositories = options.getRemoteRepositories(false);
  } catch (error) {
    console.error(`Could not list remote repositories: ${getErrorMessage(error)}`);
    return 1;
  }

  const repositories = options.findPrunableRepositories(remoteRepositories);

  if (repositories === undefined) {
    return 1;
  }

  if (repositories.length === 0) {
    console.log('No obsolete local Git repositories found.');
    return 0;
  }

  if (dryRun) {
    console.log('Dry run; the following directories would be deleted:');
    printRepositoryPaths(repositories);
    return 0;
  }

  const statuses = options.inspectRepositories(repositories, false);
  const uncleanStatuses = statuses.filter(isLocalRepositoryUnclean);

  console.log(
    'The following local repositories no longer exist remotely and will be permanently deleted:',
  );
  printRepositoryPaths(repositories);
  console.log('');

  const confirmDeletion = options.confirmDeletion ?? confirmRepositoryDeletion;

  if (!(await confirmDeletion(uncleanStatuses))) {
    return 1;
  }

  let refreshedRemoteRepositories;

  try {
    refreshedRemoteRepositories = options.getRemoteRepositories(true);
  } catch (error) {
    console.error(
      `Could not verify remote repositories: ${getErrorMessage(error)}`,
    );
    console.error('Nothing was deleted.');
    return 1;
  }

  const restoredRepositories = options.findRestoredRepositories(
    repositories,
    refreshedRemoteRepositories,
  );

  if (restoredRepositories.length > 0) {
    console.error(
      'Remote repository state changed during confirmation. Nothing was deleted.',
    );
    console.error(
      `Now present remotely: ${restoredRepositories.map(options.getRepositoryName).join(', ')}`,
    );
    return 1;
  }

  const removeRepositories =
    options.removeRepositories ?? removeLocalRepositories;
  return removeRepositories(repositories);
}

export async function confirmRepositoryDeletion(
  statuses: RepositoryStatus[],
  context: ConfirmationContext = {},
) {
  const input = context.input ?? process.stdin;
  const output = context.output ?? process.stdout;
  const print = context.print ?? console.log;
  const printError = context.printError ?? console.error;

  if (!input.isTTY || !output.isTTY) {
    printError('Deletion requires an interactive terminal. Nothing was deleted.');
    return false;
  }

  const confirmation = 'delete';
  const readline = (context.createInterface ?? createInterface)({
    input,
    output,
  });

  try {
    const answer = await readline.question(
      `Type "${confirmation}" to continue: `,
    );

    if (answer !== confirmation) {
      print('Deletion cancelled. Nothing was deleted.');
      return false;
    }

    print('');

    if (statuses.length > 0) {
      printUncleanRepositoryReasons(statuses, print);
      print('');

      const uncleanAnswer = await readline.question(
        `Type "${confirmation}" to continue: `,
      );

      if (uncleanAnswer !== confirmation) {
        print('Deletion cancelled. Nothing was deleted.');
        return false;
      }

      print('');
    }

    return true;
  } finally {
    readline.close();
  }
}

export function isLocalRepositoryUnclean(status: RepositoryStatus): boolean {
  if (status.error !== undefined || status.warnings.length > 0) {
    return true;
  }

  return (
    status.changes.staged > 0 ||
    status.changes.unstaged > 0 ||
    status.changes.untracked > 0 ||
    status.stashCount > 0 ||
    status.ahead.length > 0
  );
}

export function removeLocalRepositories(
  repositories: Repository[],
  context: RemovalContext = {},
) {
  const print = context.print ?? console.log;
  const printError = context.printError ?? console.error;
  const remove = context.remove ?? rmSync;
  const failures = [];

  for (const repository of repositories) {
    try {
      remove(repository.path, { recursive: true, force: false });
      print(`Deleted ${repository.path}`);
    } catch (error) {
      failures.push(repository.path);
      printError(
        `Could not delete ${repository.path}: ${getErrorMessage(error)}`,
      );
    }
  }

  if (failures.length > 0) {
    printError(
      `Failed to delete ${failures.length} of ${repositories.length} repositories.`,
    );
    return 1;
  }

  print(`Deleted ${repositories.length} repositories.`);
  return 0;
}

function isDeletionRootSafe(rootDir: string, requiredRootDir: string) {
  if (resolve(rootDir) === requiredRootDir) {
    return true;
  }

  console.error(`Refusing to delete: unexpected operation root: ${rootDir}`);
  console.error(`Expected operation root: ${requiredRootDir}`);
  return false;
}

function parseArguments(
  arguments_: readonly string[],
  command: string,
  printHelp: () => void,
) {
  if (arguments_.length === 0) {
    return false;
  }

  if (
    arguments_.length === 1 &&
    (arguments_[0] === '--dry-run' || arguments_[0] === '-n')
  ) {
    return true;
  }

  console.error(`Unexpected ${command} option: ${arguments_[0]}`);
  printHelp();
  return undefined;
}

function printRepositoryPaths(repositories: Repository[]) {
  for (const repository of repositories) {
    console.log(`  ${repository.path}`);
  }
}

function printUncleanRepositoryReasons(
  statuses: RepositoryStatus[],
  print: (message: string) => void,
) {
  print('Unclean repositories:');

  for (const status of statuses) {
    const reasons = [];

    if (status.error === undefined) {
      if (hasWorkingTreeChanges(status.changes)) {
        reasons.push(`working tree: ${formatChanges(status.changes)}`);
      }

      if (status.stashCount > 0) {
        const label = status.stashCount === 1 ? 'stash' : 'stashes';
        reasons.push(`${status.stashCount} ${label}`);
      }

      if (status.ahead.length > 0) {
        reasons.push(`unpushed commits: ${status.ahead.join(', ')}`);
      }
    }

    reasons.push(...status.warnings.map((warning) => `warning: ${warning}`));

    if (status.error !== undefined) {
      reasons.push(`inspection error: ${toSingleLine(status.error)}`);
    }

    print(`  ${status.name}`);

    for (const reason of reasons) {
      print(`    - ${reason}`);
    }
  }
}
