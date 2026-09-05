#!/usr/bin/env node

import { homedir } from 'node:os';
import { join, resolve } from 'node:path';

import {
  deleteRepositories,
  pruneRepositories,
} from '../../shared/destructive-workflows.mjs';
import { getErrorMessage, toSingleLine } from '../../shared/errors.mjs';
import { runProcess } from '../../shared/process.mjs';
import {
  findChildGitRepositories,
  inspectLocalRepositories as inspectRepositories,
  printLocalRepositoryStatuses,
} from '../../shared/repository-inspection.mjs';
import {
  createSyncFailure as createRepositorySyncFailure,
  syncRepositories as runSyncWorkflow,
} from '../../shared/sync-workflow.mjs';
import {
  createDependencyGraph,
  LOCAL_PACKAGE_SCOPE,
  orderPackagesForBuild,
  validateBuildScripts,
} from './build.mjs';

const GITHUB_OWNER = 'mrzli-jslib';
const REQUIRED_ROOT_NAME = 'mrzli-jslib';

// =============================================================================
// Entry point and command routing
// =============================================================================

export async function main(arguments_, context = {}) {
  const homeDir = context.homeDir ?? homedir();
  const requiredRootDir = resolve(
    homeDir,
    'projects/personal',
    REQUIRED_ROOT_NAME,
  );
  const rootDir = resolve(context.rootDir ?? requiredRootDir);

  try {
    return await runCommand(arguments_, { requiredRootDir, rootDir });
  } catch (error) {
    console.error(`Unexpected error: ${getErrorMessage(error)}`);
    return 1;
  }
}

async function runCommand(arguments_, paths) {
  const [command, ...extraArguments] = arguments_;

  switch (command) {
    case 'build': {
      return buildLocalPackages(extraArguments, paths.rootDir);
    }
    case 'delete': {
      return deleteLocalRepositories(extraArguments, paths);
    }
    case 'graph': {
      return showDependencyGraph(extraArguments, paths.rootDir);
    }
    case 'prune': {
      return pruneLocalRepositories(extraArguments, paths);
    }
    case 'remote': {
      return listRemoteRepositories(extraArguments);
    }
    case 'status': {
      return showLocalRepositoryStatuses(extraArguments, paths.rootDir);
    }
    case 'sync': {
      return syncRepositories(extraArguments, paths.rootDir);
    }
    case 'help':
    case '--help':
    case '-h':
    case undefined: {
      return showHelp(extraArguments);
    }
    default: {
      console.error(`Unknown command: ${command}`);
      printGlobalHelp();
      return 1;
    }
  }
}

// =============================================================================
// Command: build
// =============================================================================

function buildLocalPackages(arguments_, rootDir) {
  if (isHelpRequest(arguments_)) {
    printBuildHelp();
    return 0;
  }

  if (!acceptsNoArguments('build', arguments_, printBuildHelp)) {
    return 1;
  }

  let packages;

  try {
    const graph = createDependencyGraph(findLocalRepositories(rootDir));

    validateBuildScripts(graph);
    packages = orderPackagesForBuild(graph);
  } catch (error) {
    console.error(`Could not prepare build: ${getErrorMessage(error)}`);
    return 1;
  }

  if (packages.length === 0) {
    console.log(`No local Git repositories found in ${rootDir}.`);
    return 0;
  }

  for (const [index, package_] of packages.entries()) {
    console.log(`[${index + 1}/${packages.length}] ${package_.name}`);

    if (
      !runBunForPackage(
        package_,
        ['install', '--frozen-lockfile', '--ignore-scripts'],
        'install dependencies',
      )
    ) {
      return 1;
    }

    if (!runBunForPackage(package_, ['run', 'build'], 'build package')) {
      return 1;
    }
  }

  console.log(`Built ${packages.length} packages.`);
  return 0;
}

function runBunForPackage(package_, arguments_, action) {
  const result = runProcess('bun', arguments_, {
    cwd: package_.path,
    stdio: 'inherit',
  });

  if (result.error) {
    console.error(
      `${package_.name}: could not ${action}: ${result.error.message}`,
    );
    return false;
  }

  if (result.signal) {
    console.error(
      `${package_.name}: could not ${action}: Bun was terminated by signal ${result.signal}`,
    );
    return false;
  }

  if (result.status !== 0) {
    console.error(
      `${package_.name}: could not ${action}: Bun exited with status ${result.status ?? 'unknown'}`,
    );
    return false;
  }

  return true;
}

function printBuildHelp() {
  console.log(getBuildHelpText());
}

function getBuildHelpText() {
  const lines = [
    'Usage: archon libs build [options]',
    '',
    `Build local ${LOCAL_PACKAGE_SCOPE}/* packages in dependency order.`,
    '',
    'Installs from each frozen Bun lockfile without running lifecycle scripts.',
    '',
    'Options:',
    '  -h, --help  Show help for this command',
  ];

  return lines.join('\n');
}

// =============================================================================
// Command: delete
// =============================================================================

async function deleteLocalRepositories(arguments_, paths) {
  return deleteRepositories(arguments_, {
    emptyMessage: `No local Git repositories found in ${paths.rootDir}.`,
    findRepositories: () => findLocalRepositories(paths.rootDir),
    inspectRepositories: inspectLocalRepositories,
    printHelp: printDeleteHelp,
    requiredRootDir: paths.requiredRootDir,
    rootDir: paths.rootDir,
  });
}

function printDeleteHelp() {
  console.log(getDeleteHelpText());
}

function getDeleteHelpText() {
  const lines = [
    'Usage: archon libs delete [options]',
    '',
    'Permanently delete every local Git repository in this directory.',
    '',
    'Options:',
    '  -n, --dry-run  List repositories without deleting them',
    '  -h, --help     Show help for this command',
  ];

  return lines.join('\n');
}

// =============================================================================
// Command: graph
// =============================================================================

function showDependencyGraph(arguments_, rootDir) {
  if (isHelpRequest(arguments_)) {
    printGraphHelp();
    return 0;
  }

  if (!acceptsNoArguments('graph', arguments_, printGraphHelp)) {
    return 1;
  }

  try {
    const graph = createDependencyGraph(findLocalRepositories(rootDir));

    printDependencyGraph(graph, rootDir);
    return 0;
  } catch (error) {
    console.error(
      `Could not generate dependency graph: ${getErrorMessage(error)}`,
    );
    return 1;
  }
}

function printDependencyGraph(graph, rootDir) {
  if (graph.length === 0) {
    console.log(`No local Git repositories found in ${rootDir}.`);
    return;
  }

  for (const node of graph) {
    console.log(node.name);

    for (const dependency of node.dependencies) {
      console.log(`  -> ${dependency}`);
    }
  }
}

function printGraphHelp() {
  console.log(getGraphHelpText());
}

function getGraphHelpText() {
  const lines = [
    'Usage: archon libs graph [options]',
    '',
    `Show dependencies between local ${LOCAL_PACKAGE_SCOPE}/* packages.`,
    '',
    'Local package dependencies must use the file: protocol.',
    '',
    'Options:',
    '  -h, --help  Show help for this command',
  ];

  return lines.join('\n');
}

// =============================================================================
// Command: prune
// =============================================================================

async function pruneLocalRepositories(arguments_, paths) {
  return pruneRepositories(arguments_, {
    findPrunableRepositories: (remoteRepositories) =>
      findPrunableRepositories(remoteRepositories, paths.rootDir),
    findRestoredRepositories,
    getRemoteRepositories: () => getRemoteRepositories(),
    getRepositoryName: (repository) => repository.name,
    inspectRepositories: inspectLocalRepositories,
    printHelp: printPruneHelp,
    requiredRootDir: paths.requiredRootDir,
    rootDir: paths.rootDir,
  });
}

function findPrunableRepositories(remoteRepositories, rootDir) {
  if (remoteRepositories.length >= 1000) {
    console.error(
      'Refusing to prune: the remote repository list may be truncated at 1000 entries.',
    );
    return undefined;
  }

  const remoteNames = new Set(
    remoteRepositories.map((repository) => repository.name),
  );
  return findLocalRepositories(rootDir).filter(
    (repository) => !remoteNames.has(repository.name),
  );
}

function findRestoredRepositories(repositories, remoteRepositories) {
  const remoteNames = new Set(
    remoteRepositories.map((repository) => repository.name),
  );
  return repositories.filter((repository) =>
    remoteNames.has(repository.name),
  );
}

function printPruneHelp() {
  console.log(getPruneHelpText());
}

function getPruneHelpText() {
  const lines = [
    'Usage: archon libs prune [options]',
    '',
    'Delete local repositories that no longer exist remotely.',
    '',
    'Options:',
    '  -n, --dry-run  List repositories without deleting them',
    '  -h, --help     Show help for this command',
  ];

  return lines.join('\n');
}

// =============================================================================
// Command: remote
// =============================================================================

function listRemoteRepositories(arguments_) {
  if (isHelpRequest(arguments_)) {
    printRemoteHelp();
    return 0;
  }

  if (!acceptsNoArguments('remote', arguments_, printRemoteHelp)) {
    return 1;
  }

  try {
    const repositories = getRemoteRepositories();
    const nameWidth = Math.max(
      0,
      ...repositories.map((repository) => repository.nameWithOwner.length),
    );

    for (const repository of repositories) {
      console.log(formatRemoteRepository(repository, nameWidth));
    }
  } catch (error) {
    console.error(getErrorMessage(error));
    return 1;
  }

  return 0;
}

function formatRemoteRepository(repository, nameWidth) {
  const labels = [];

  if (repository.isPrivate) {
    labels.push('private');
  }

  if (repository.isArchived) {
    labels.push('archived');
  }

  if (labels.length === 0) {
    return repository.nameWithOwner;
  }

  return `${repository.nameWithOwner.padEnd(nameWidth)} (${labels.join(', ')})`;
}

function printRemoteHelp() {
  console.log(getRemoteHelpText());
}

function getRemoteHelpText() {
  const lines = [
    'Usage: archon libs remote [options]',
    '',
    `List repositories owned by the ${GITHUB_OWNER} GitHub organization.`,
    '',
    'Options:',
    '  -h, --help  Show help for this command',
  ];

  return lines.join('\n');
}

// =============================================================================
// Command: status
// =============================================================================

function showLocalRepositoryStatuses(arguments_, rootDir) {
  if (isHelpRequest(arguments_)) {
    printStatusHelp();
    return 0;
  }

  const fetch = parseStatusArguments(arguments_);

  if (fetch === undefined) {
    return 1;
  }

  const repositories = findLocalRepositories(rootDir);

  if (repositories.length === 0) {
    console.log(`No local Git repositories found in ${rootDir}.`);
    return 0;
  }

  const statuses = inspectLocalRepositories(repositories, fetch);

  printLocalRepositoryStatuses(statuses);

  return statuses.some(
    (status) => status.error !== undefined || status.warnings.length > 0,
  )
    ? 1
    : 0;
}

function parseStatusArguments(arguments_) {
  if (arguments_.length === 0) {
    return false;
  }

  if (arguments_.length === 1 && arguments_[0] === '--fetch') {
    return true;
  }

  console.error(`Unexpected status option: ${arguments_[0]}`);
  printStatusHelp();
  return undefined;
}

function printStatusHelp() {
  console.log(getStatusHelpText());
}

function getStatusHelpText() {
  const lines = [
    'Usage: archon libs status [options]',
    '',
    'Show concise local Git status for every repository.',
    '',
    'Options:',
    '  --fetch      Fetch and prune all remotes before showing status',
    '  -h, --help   Show help for this command',
  ];

  return lines.join('\n');
}

// =============================================================================
// Command: sync
// =============================================================================

function syncRepositories(arguments_, rootDir) {
  return runSyncWorkflow(arguments_, {
    cloneRepository: (repository) =>
      cloneRemoteRepository(repository, rootDir),
    compareRepositories: (left, right) => left.name.localeCompare(right.name),
    findLocalRepositories: () => findLocalRepositories(rootDir),
    getRemoteRepositories,
    getRepositoryKey: (repository) => repository.name,
    getRepositoryName: (repository) => repository.name,
    printHelp: printSyncHelp,
  });
}

function cloneRemoteRepository(repository, rootDir) {
  const result = runProcess(
    'gh',
    ['repo', 'clone', repository.nameWithOwner, join(rootDir, repository.name)],
    { encoding: 'utf8' },
  );

  if (result.error) {
    return createSyncFailure(
      repository,
      `could not start GitHub CLI: ${result.error.message}`,
    );
  }

  if (result.signal) {
    return createSyncFailure(
      repository,
      `GitHub CLI was terminated by signal ${result.signal}`,
    );
  }

  if (result.status !== 0) {
    return createSyncFailure(
      repository,
      toSingleLine(result.stderr) || 'GitHub CLI clone failed',
    );
  }

  return {
    name: repository.name,
    succeeded: true,
    message: 'cloned',
  };
}

function createSyncFailure(repository, message) {
  return createRepositorySyncFailure(
    repository,
    message,
    (repository_) => repository_.name,
  );
}

function printSyncHelp() {
  console.log(getSyncHelpText());
}

function getSyncHelpText() {
  const lines = [
    'Usage: archon libs sync [options]',
    '',
    'Update existing local repositories and clone missing remote repositories.',
    '',
    'Options:',
    '  -h, --help  Show help for this command',
  ];

  return lines.join('\n');
}

// =============================================================================
// Command: help
// =============================================================================

function showHelp(arguments_) {
  if (arguments_.length === 0) {
    printGlobalHelp();
    return 0;
  }

  if (isHelpRequest(arguments_)) {
    printHelpHelp();
    return 0;
  }

  if (arguments_.length === 1 && printCommandHelp(arguments_[0])) {
    return 0;
  }

  if (arguments_.length > 1) {
    console.error(`Unexpected help argument: ${arguments_[1]}`);
  } else {
    console.error(`Unknown command: ${arguments_[0]}`);
  }

  printHelpHelp();
  return 1;
}

function printHelpHelp() {
  console.log(getHelpHelpText());
}

function getHelpHelpText() {
  const lines = [
    'Usage: archon libs help [command]',
    '',
    'Show global help or detailed help for one command.',
  ];

  return lines.join('\n');
}

function printGlobalHelp() {
  console.log(getGlobalHelpText());
}

function getGlobalHelpText() {
  const lines = [
    'Usage: archon libs <command>',
    '',
    'Commands:',
    `  build   Build local ${LOCAL_PACKAGE_SCOPE}/* packages in dependency order`,
    `  delete  Delete all local Git repositories inside ${REQUIRED_ROOT_NAME}`,
    `  graph   Show dependencies between local ${LOCAL_PACKAGE_SCOPE}/* packages`,
    '  prune   Delete local repositories that no longer exist remotely',
    `  remote  List repositories owned by the ${GITHUB_OWNER} GitHub organization`,
    '  status  Show concise local Git status for every repository',
    '  sync    Update existing repositories and clone missing repositories',
    '  help    Show global or command-specific help',
    '',
    'Run "archon libs help <command>" for detailed command help.',
  ];

  return lines.join('\n');
}

// =============================================================================
// Shared utilities
// =============================================================================

function getRemoteRepositories() {
  const result = runProcess(
    'gh',
    [
      'repo',
      'list',
      GITHUB_OWNER,
      '--limit',
      '1000',
      '--json',
      'name,nameWithOwner,isPrivate,isArchived',
    ],
    { encoding: 'utf8' },
  );

  if (result.error) {
    if (result.error.code === 'ENOENT') {
      throw new Error(
        'GitHub CLI (`gh`) was not found. Install it and run `gh auth login` first.',
      );
    }

    throw new Error(`Could not start GitHub CLI: ${result.error.message}`);
  }

  if (result.signal) {
    throw new Error(`GitHub CLI was terminated by signal ${result.signal}.`);
  }

  if (result.status !== 0) {
    throw new Error(
      toSingleLine(result.stderr) ||
        `GitHub CLI exited with status ${result.status ?? 'unknown'}.`,
    );
  }

  try {
    const repositories = JSON.parse(result.stdout);

    if (!Array.isArray(repositories)) {
      throw new Error('expected an array');
    }

    for (const repository of repositories) {
      if (
        typeof repository.name !== 'string' ||
        typeof repository.nameWithOwner !== 'string'
      ) {
        throw new Error('repository name is missing');
      }
    }

    return repositories;
  } catch (error) {
    throw new Error(`Could not read GitHub CLI output: ${getErrorMessage(error)}`);
  }
}

function inspectLocalRepositories(repositories, fetch) {
  return inspectRepositories(repositories, fetch, (repository) => repository.name);
}

function findLocalRepositories(rootDir) {
  return findChildGitRepositories(rootDir)
    .sort((left, right) => left.name.localeCompare(right.name));
}

function acceptsNoArguments(command, arguments_, printCommandHelp_) {
  if (arguments_.length === 0) {
    return true;
  }

  console.error(`Unexpected ${command} option: ${arguments_[0]}`);
  printCommandHelp_();
  return false;
}

function isHelpRequest(arguments_) {
  return (
    arguments_.length === 1 &&
    (arguments_[0] === '--help' || arguments_[0] === '-h')
  );
}

function printCommandHelp(command) {
  switch (command) {
    case 'build': {
      printBuildHelp();
      return true;
    }
    case 'delete': {
      printDeleteHelp();
      return true;
    }
    case 'graph': {
      printGraphHelp();
      return true;
    }
    case 'prune': {
      printPruneHelp();
      return true;
    }
    case 'remote': {
      printRemoteHelp();
      return true;
    }
    case 'status': {
      printStatusHelp();
      return true;
    }
    case 'sync': {
      printSyncHelp();
      return true;
    }
    case 'help': {
      printHelpHelp();
      return true;
    }
    default: {
      return false;
    }
  }
}
