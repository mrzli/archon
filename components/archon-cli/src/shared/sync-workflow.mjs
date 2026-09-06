import { isHelpRequest } from './arguments.ts';
import { getErrorMessage, toSingleLine } from './errors.mjs';
import { getGitOutput } from './git.mjs';
import {
  formatChanges,
  getBranchUpstream,
  getSymbolicCurrentBranch,
  getWorkingTreeChanges,
  hasWorkingTreeChanges,
} from './repository-inspection.mjs';

export function createSyncFailure(repository, message, getRepositoryName) {
  return {
    name: getRepositoryName(repository),
    succeeded: false,
    message: `ERROR: ${toSingleLine(message)}`,
  };
}

export function syncRepositories(arguments_, options) {
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
    ((repository) =>
      updateLocalRepository(repository, options.getRepositoryName));
  const operations = [
    ...localRepositories.map((repository) => ({
      repository,
      run: updateRepository,
    })),
    ...missingRepositories.map((repository) => ({
      repository,
      run: options.cloneRepository,
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

export function updateLocalRepository(repository, getRepositoryName) {
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

function runSyncOperations(operations, options) {
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
      result = run(repository);
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
