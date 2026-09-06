import type { RepositoryStatus } from '../../shared/index.ts';
import { mkdirSync } from 'node:fs';
import { homedir } from 'node:os';
import { join, resolve } from 'node:path';

import type { LocalPackage, PackageNode } from './build.ts';
import type { RemoteRepository } from './github-inventory.ts';
import type { SyncResult } from '../../shared/index.ts';
import {
  acceptsNoArguments,
  createSyncFailure as createRepositorySyncFailure,
  deleteRepositories,
  findChildGitRepositories,
  getErrorMessage,
  inspectLocalRepositories as inspectRepositories,
  isHelpRequest,
  pruneRepositories,
  runProcess,
  runStatusWorkflow,
  syncRepositories as runSyncWorkflow,
  toSingleLine,
} from '../../shared/index.ts';
import {
  createDependencyGraph,
  LOCAL_PACKAGE_SCOPE,
  orderPackagesForBuild,
  validateBuildScripts,
} from './build.ts';
import { parseRemoteRepositories } from './github-inventory.ts';

interface LocalRepository {
  readonly name: string;
  readonly path: string;
}

interface LibraryPaths {
  readonly rootDir: string;
  readonly requiredRootDir: string;
}

interface LibraryContext {
  readonly homeDir?: string;
  readonly rootDir?: string;
}

const GITHUB_OWNER = 'mrzli-jslib';
const REQUIRED_ROOT_NAME = 'mrzli-jslib';

// =============================================================================
// Entry point and command routing
// =============================================================================

export async function runLibraries(
  arguments_: readonly string[],
  context: LibraryContext = {},
): Promise<number> {
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

async function runCommand(arguments_: readonly string[], paths: LibraryPaths): Promise<number> {
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
    case '-h': {
      return showHelp(extraArguments);
    }
    case undefined: {
      console.error('Missing libraries command.');
      printGlobalHelp();
      return 2;
    }
    default: {
      console.error(`Unknown command: ${command}`);
      printGlobalHelp();
      return 2;
    }
  }
}

// =============================================================================
// Command: build
// =============================================================================

function buildLocalPackages(arguments_: readonly string[], rootDir: string): number {
  if (isHelpRequest(arguments_)) {
    printBuildHelp();
    return 0;
  }

  if (!acceptsNoArguments('build', arguments_, printBuildHelp)) {
    return 2;
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

function runBunForPackage(
  package_: LocalPackage,
  arguments_: readonly string[],
  action: string,
): boolean {
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

function printBuildHelp(): void {
  console.log(getBuildHelpText());
}

function getBuildHelpText(): string {
  const lines: readonly string[] = [
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

async function deleteLocalRepositories(arguments_: readonly string[], paths: LibraryPaths): Promise<number> {
  return deleteRepositories(arguments_, {
    emptyMessage: `No local Git repositories found in ${paths.rootDir}.`,
    findRepositories: (): readonly LocalRepository[] => findLocalRepositories(paths.rootDir),
    inspectRepositories: inspectLocalRepositories,
    printHelp: printDeleteHelp,
    requiredRootDir: paths.requiredRootDir,
    rootDir: paths.rootDir,
  });
}

function printDeleteHelp(): void {
  console.log(getDeleteHelpText());
}

function getDeleteHelpText(): string {
  const lines: readonly string[] = [
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

function showDependencyGraph(arguments_: readonly string[], rootDir: string): number {
  if (isHelpRequest(arguments_)) {
    printGraphHelp();
    return 0;
  }

  if (!acceptsNoArguments('graph', arguments_, printGraphHelp)) {
    return 2;
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

function printDependencyGraph(graph: readonly PackageNode[], rootDir: string): void {
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

function printGraphHelp(): void {
  console.log(getGraphHelpText());
}

function getGraphHelpText(): string {
  const lines: readonly string[] = [
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

async function pruneLocalRepositories(arguments_: readonly string[], paths: LibraryPaths): Promise<number> {
  return pruneRepositories(arguments_, {
    findPrunableRepositories: (remoteRepositories): readonly LocalRepository[] | undefined =>
      findPrunableRepositories(remoteRepositories, paths.rootDir),
    findRestoredRepositories,
    getRemoteRepositories: (): readonly RemoteRepository[] => getRemoteRepositories(),
    getRepositoryName: (repository): string => repository.name,
    inspectRepositories: inspectLocalRepositories,
    printHelp: printPruneHelp,
    requiredRootDir: paths.requiredRootDir,
    rootDir: paths.rootDir,
  });
}

function findPrunableRepositories(remoteRepositories: readonly RemoteRepository[], rootDir: string): readonly LocalRepository[] | undefined {
  if (remoteRepositories.length >= 1000) {
    console.error(
      'Refusing to prune: the remote repository list may be truncated at 1000 entries.',
    );
    return undefined;
  }

  const remoteNames = new Set(
    remoteRepositories.map((repository): string => repository.name),
  );
  return findLocalRepositories(rootDir).filter(
    (repository): boolean => !remoteNames.has(repository.name),
  );
}

function findRestoredRepositories(
  repositories: readonly LocalRepository[],
  remoteRepositories: readonly RemoteRepository[],
): readonly LocalRepository[] {
  const remoteNames = new Set(
    remoteRepositories.map((repository): string => repository.name),
  );
  return repositories.filter((repository): boolean =>
    remoteNames.has(repository.name),
  );
}

function printPruneHelp(): void {
  console.log(getPruneHelpText());
}

function getPruneHelpText(): string {
  const lines: readonly string[] = [
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

function listRemoteRepositories(arguments_: readonly string[]): number {
  if (isHelpRequest(arguments_)) {
    printRemoteHelp();
    return 0;
  }

  if (!acceptsNoArguments('remote', arguments_, printRemoteHelp)) {
    return 2;
  }

  try {
    const repositories = getRemoteRepositories();
    const nameWidth = Math.max(
      0,
      ...repositories.map((repository): number => repository.nameWithOwner.length),
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

function formatRemoteRepository(repository: RemoteRepository, nameWidth: number): string {
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

function printRemoteHelp(): void {
  console.log(getRemoteHelpText());
}

function getRemoteHelpText(): string {
  const lines: readonly string[] = [
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

function showLocalRepositoryStatuses(arguments_: readonly string[], rootDir: string): number {
  return runStatusWorkflow(arguments_, {
    emptyMessage: `No local Git repositories found in ${rootDir}.`,
    findRepositories: (): readonly LocalRepository[] => findLocalRepositories(rootDir),
    inspectRepositories: inspectLocalRepositories,
    printHelp: printStatusHelp,
  });
}

function printStatusHelp(): void {
  console.log(getStatusHelpText());
}

function getStatusHelpText(): string {
  const lines: readonly string[] = [
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

function syncRepositories(arguments_: readonly string[], rootDir: string): number {
  if (arguments_.length === 0) {
    mkdirSync(rootDir, { recursive: true });
  }

  return runSyncWorkflow(arguments_, {
    cloneRepository: (repository): SyncResult =>
      cloneRemoteRepository(repository, rootDir),
    compareRepositories: (left, right): number => left.name.localeCompare(right.name),
    findLocalRepositories: (): readonly LocalRepository[] => findLocalRepositories(rootDir),
    getRemoteRepositories,
    getRepositoryKey: (repository): string => repository.name,
    getRepositoryName: (repository): string => repository.name,
    printHelp: printSyncHelp,
  });
}

function cloneRemoteRepository(repository: RemoteRepository, rootDir: string): SyncResult {
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

function createSyncFailure(repository: { readonly name: string }, message: unknown): SyncResult {
  return createRepositorySyncFailure(
    repository,
    message,
    (repository_): string => repository_.name,
  );
}

function printSyncHelp(): void {
  console.log(getSyncHelpText());
}

function getSyncHelpText(): string {
  const lines: readonly string[] = [
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

function showHelp(arguments_: readonly string[]): number {
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
  return 2;
}

function printHelpHelp(): void {
  console.log(getHelpHelpText());
}

function getHelpHelpText(): string {
  const lines: readonly string[] = [
    'Usage: archon libs help [command]',
    '',
    'Show global help or detailed help for one command.',
  ];

  return lines.join('\n');
}

function printGlobalHelp(): void {
  console.log(getGlobalHelpText());
}

function getGlobalHelpText(): string {
  const lines: readonly string[] = [
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

function getRemoteRepositories(): readonly RemoteRepository[] {
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
    if ('code' in result.error && result.error.code === 'ENOENT') {
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

  return parseRemoteRepositories(result.stdout);
}

function inspectLocalRepositories(repositories: readonly LocalRepository[], fetch: boolean): readonly RepositoryStatus[] {
  return inspectRepositories(repositories, fetch, (repository): string => repository.name);
}

function findLocalRepositories(rootDir: string): readonly LocalRepository[] {
  try {
    return findChildGitRepositories(rootDir)
      .sort((left, right): number => left.name.localeCompare(right.name));
  } catch (error) {
    if (
      typeof error === 'object' &&
      error !== null &&
      'code' in error &&
      error.code === 'ENOENT'
    ) {
      return [];
    }

    throw error;
  }
}

function printCommandHelp(command: string): boolean {
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
