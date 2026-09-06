import type { Repository } from './git.ts';
import { isHelpRequest } from './arguments.ts';
import { getErrorMessage, toSingleLine } from './errors.ts';
import { getGitOutput } from './git.ts';
import {
  formatChanges,
  getBranchUpstream,
  getSymbolicCurrentBranch,
  getWorkingTreeChanges,
  hasWorkingTreeChanges,
} from './repository-inspection.ts';

export interface SyncResult {
  name: string;
  succeeded: boolean;
  message: string;
}

export interface SyncOptions<L extends Repository, R> {
  printHelp: () => void;
  getRemoteRepositories: () => R[];
  findLocalRepositories: () => L[];
  getRepositoryKey: (repository: L | R) => string;
  getRepositoryName: (repository: L | R) => string;
  compareRepositories: (left: L | R, right: L | R) => number;
  updateRepository?: (repository: L) => SyncResult;
  cloneRepository: (repository: R) => SyncResult;
  print?: (message: string) => void;
  printError?: (message: string) => void;
  write?: (message: string) => void;
}

export function createSyncFailure<R>(
  repository: R,
  message: unknown,
  getRepositoryName: (repository: R) => string,
): SyncResult {
  return {
    name: getRepositoryName(repository),
    succeeded: false,
    message: `ERROR: ${toSingleLine(message)}`,
  };
}

export function syncRepositories<L extends Repository, R>(
  arguments_: readonly string[],
  options: SyncOptions<L, R>,
) {
  const print = options.print ?? console.log;
  const printError = options.printError ?? console.error;

  if (isHelpRequest(arguments_)) {
    options.printHelp();
    return 0;
  }

  if (arguments_.length > 0) {
    printError(`Unexpected sync option: ${arguments_[0]}`);
    options.printHelp();
    return 2;
  }

  let remoteRepositories;

  try {
    remoteRepositories = options.getRemoteRepositories();
  } catch (error) {
    printError(`Could not list remote repositories: ${getErrorMessage(error)}`);
    return 1;
  }

  const localRepositories = options.findLocalRepositories();
  const localNames = new Set(
    localRepositories.map(options.getRepositoryKey),
  );
  const missingRepositories = remoteRepositories.filter(
    (repository) => !localNames.has(options.getRepositoryKey(repository)),
  );
  const updateRepository =
    options.updateRepository ??
    ((repository: L) =>
      updateLocalRepository(repository, options.getRepositoryName));
  const cloneRepository = options.cloneRepository;
  const operations = [
    ...localRepositories.map((repository) => ({
      repository,
      run: () => updateRepository(repository),
    })),
    ...missingRepositories.map((repository) => ({
      repository,
      run: () => cloneRepository(repository),
    })),
  ].sort((left, right) =>
    options.compareRepositories(left.repository, right.repository),
  );

  if (operations.length === 0) {
    print('No local or remote Git repositories found.');
    return 0;
  }

  const results = runSyncOperations(operations, options);
  return results.some((result) => !result.succeeded) ? 1 : 0;
}

export function updateLocalRepository<R extends Repository>(
  repository: R,
  getRepositoryName: (repository: R) => string,
): SyncResult {
  try {
    getGitOutput(repository, ['fetch', '--all', '--prune']);

    const branch = getSymbolicCurrentBranch(repository);

    if (branch === undefined) {
      return createSyncFailure(repository, 'detached HEAD', getRepositoryName);
    }

    const changes = getWorkingTreeChanges(repository);

    if (hasWorkingTreeChanges(changes)) {
      return createSyncFailure(
        repository,
        `working tree is not clean (${formatChanges(changes)})`,
        getRepositoryName,
      );
    }

    const upstream = getBranchUpstream(repository, branch);

    if (upstream === undefined) {
      return createSyncFailure(
        repository,
        `${branch} has no upstream`,
        getRepositoryName,
      );
    }

    const previousHead = getGitOutput(repository, ['rev-parse', 'HEAD']).trim();
    getGitOutput(repository, ['merge', '--ff-only', upstream]);
    const currentHead = getGitOutput(repository, ['rev-parse', 'HEAD']).trim();
    const state = currentHead === previousHead ? 'up to date' : 'updated';

    return {
      name: getRepositoryName(repository),
      succeeded: true,
      message: `[${branch} -> ${upstream}]  ${state}`,
    };
  } catch (error) {
    return createSyncFailure(
      repository,
      getErrorMessage(error),
      getRepositoryName,
    );
  }
}

function runSyncOperations<R>(
  operations: { repository: R; run: () => SyncResult }[],
  options: {
    print?: (message: string) => void;
    write?: (message: string) => void;
    getRepositoryName: (repository: R) => string;
  },
) {
  const print = options.print ?? console.log;
  const write = options.write ?? process.stdout.write.bind(process.stdout);
  const indexWidth = String(operations.length).length;
  const nameWidth = Math.max(
    ...operations.map(({ repository }) =>
      options.getRepositoryName(repository).length,
    ),
  );
  const results = [];

  print(`Synchronizing ${operations.length} repositories...`);

  for (const [index, { repository, run }] of operations.entries()) {
    const current = String(index + 1).padStart(indexWidth);
    const progress = `[${current}/${operations.length}]`;
    write(
      `${progress} ${options.getRepositoryName(repository).padEnd(nameWidth)}  `,
    );

    let result;

    try {
      result = run();
    } catch (error) {
      result = createSyncFailure(
        repository,
        getErrorMessage(error),
        options.getRepositoryName,
      );
    }

    print(result.message);
    results.push(result);
  }

  return results;
}
