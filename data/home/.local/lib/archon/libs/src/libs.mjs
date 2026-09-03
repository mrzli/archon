#!/usr/bin/env node

import {
  readFileSync,
  realpathSync,
  rmSync,
} from 'node:fs';
import { homedir } from 'node:os';
import { join, resolve } from 'node:path';
import { createInterface } from 'node:readline/promises';

import { getErrorMessage, toSingleLine } from '../../shared/errors.mjs';
import { getGitOutput } from '../../shared/git.mjs';
import { runProcess } from '../../shared/process.mjs';
import {
  findChildGitRepositories,
  formatChanges,
  getBranchUpstream,
  getSymbolicCurrentBranch,
  getWorkingTreeChanges,
  hasWorkingTreeChanges,
  inspectLocalRepositories as inspectRepositories,
  printLocalRepositoryStatuses,
} from '../../shared/repository-inspection.mjs';

const GITHUB_OWNER = 'mrzli-jslib';
const LOCAL_PACKAGE_SCOPE = '@mrzli-jslib';
const LOCAL_PACKAGE_PREFIX = `${LOCAL_PACKAGE_SCOPE}/`;
const REQUIRED_ROOT_NAME = 'mrzli-jslib';
let REQUIRED_ROOT_DIR;
let ROOT_DIR;
const DEPENDENCY_FIELDS = [
  'dependencies',
  'devDependencies',
  'optionalDependencies',
  'peerDependencies',
];

// =============================================================================
// Entry point and command routing
// =============================================================================

export async function main(arguments_, context = {}) {
  const homeDir = context.homeDir ?? homedir();
  REQUIRED_ROOT_DIR = resolve(
    homeDir,
    'projects/personal',
    REQUIRED_ROOT_NAME,
  );
  ROOT_DIR = resolve(context.rootDir ?? REQUIRED_ROOT_DIR);

  try {
    return await runCommand(arguments_);
  } catch (error) {
    console.error(`Unexpected error: ${getErrorMessage(error)}`);
    return 1;
  }
}

async function runCommand(arguments_) {
  const [command, ...extraArguments] = arguments_;

  switch (command) {
    case 'build': {
      return buildLocalPackages(extraArguments);
    }
    case 'delete': {
      return deleteLocalRepositories(extraArguments);
    }
    case 'graph': {
      return showDependencyGraph(extraArguments);
    }
    case 'prune': {
      return pruneLocalRepositories(extraArguments);
    }
    case 'remote': {
      return listRemoteRepositories(extraArguments);
    }
    case 'status': {
      return showLocalRepositoryStatuses(extraArguments);
    }
    case 'sync': {
      return syncRepositories(extraArguments);
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

function buildLocalPackages(arguments_) {
  if (isHelpRequest(arguments_)) {
    printBuildHelp();
    return 0;
  }

  if (!acceptsNoArguments('build', arguments_, printBuildHelp)) {
    return 1;
  }

  let packages;

  try {
    const graph = createDependencyGraph(findLocalRepositories());

    validateBuildScripts(graph);
    packages = orderPackagesForBuild(graph);
  } catch (error) {
    console.error(`Could not prepare build: ${getErrorMessage(error)}`);
    return 1;
  }

  if (packages.length === 0) {
    console.log(`No local Git repositories found in ${ROOT_DIR}.`);
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

function validateBuildScripts(graph) {
  for (const node of graph) {
    if (
      node.manifest.scripts === null ||
      typeof node.manifest.scripts !== 'object' ||
      Array.isArray(node.manifest.scripts) ||
      typeof node.manifest.scripts.build !== 'string' ||
      node.manifest.scripts.build.length === 0
    ) {
      throw new Error(`${node.name} must define a non-empty build script`);
    }
  }
}

function orderPackagesForBuild(graph) {
  const nodesByName = new Map(graph.map((node) => [node.name, node]));
  const states = new Map();
  const path = [];
  const ordered = [];

  function visit(node) {
    const state = states.get(node.name);

    if (state === 'visited') {
      return;
    }

    if (state === 'visiting') {
      const cycleStart = path.indexOf(node.name);
      const cycle = [...path.slice(cycleStart), node.name];

      throw new Error(`dependency cycle detected: ${cycle.join(' -> ')}`);
    }

    states.set(node.name, 'visiting');
    path.push(node.name);

    for (const dependencyName of node.dependencies) {
      visit(nodesByName.get(dependencyName));
    }

    path.pop();
    states.set(node.name, 'visited');
    ordered.push(node);
  }

  for (const node of graph) {
    visit(node);
  }

  return ordered;
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
    'Usage: ./libs.mjs build [options]',
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

async function deleteLocalRepositories(arguments_) {
  if (isHelpRequest(arguments_)) {
    printDeleteHelp();
    return 0;
  }

  const dryRun = parseDeleteArguments(arguments_);

  if (dryRun === undefined) {
    return 1;
  }

  if (!isDeletionRootSafe()) {
    return 1;
  }

  const repositories = findLocalRepositories();

  if (repositories.length === 0) {
    console.log(`No local Git repositories found in ${ROOT_DIR}.`);
    return 0;
  }

  if (dryRun) {
    console.log('Dry run; the following directories would be deleted:');
    printRepositoryPaths(repositories);
    return 0;
  }

  const statuses = inspectLocalRepositories(repositories, false);
  const uncleanStatuses = statuses.filter(isLocalRepositoryUnclean);

  console.log('The following directories will be permanently deleted:');
  printRepositoryPaths(repositories);
  console.log('');

  if (!(await confirmRepositoryDeletion(uncleanStatuses))) {
    return 1;
  }

  return removeLocalRepositories(repositories);
}

function parseDeleteArguments(arguments_) {
  if (arguments_.length === 0) {
    return false;
  }

  if (
    arguments_.length === 1 &&
    (arguments_[0] === '--dry-run' || arguments_[0] === '-n')
  ) {
    return true;
  }

  console.error(`Unexpected delete option: ${arguments_[0]}`);
  printDeleteHelp();
  return undefined;
}

function printDeleteHelp() {
  console.log(getDeleteHelpText());
}

function getDeleteHelpText() {
  const lines = [
    'Usage: ./libs.mjs delete [options]',
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

function showDependencyGraph(arguments_) {
  if (isHelpRequest(arguments_)) {
    printGraphHelp();
    return 0;
  }

  if (!acceptsNoArguments('graph', arguments_, printGraphHelp)) {
    return 1;
  }

  try {
    const graph = createDependencyGraph(findLocalRepositories());

    printDependencyGraph(graph);
    return 0;
  } catch (error) {
    console.error(
      `Could not generate dependency graph: ${getErrorMessage(error)}`,
    );
    return 1;
  }
}

function printDependencyGraph(graph) {
  if (graph.length === 0) {
    console.log(`No local Git repositories found in ${ROOT_DIR}.`);
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
    'Usage: ./libs.mjs graph [options]',
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

async function pruneLocalRepositories(arguments_) {
  if (isHelpRequest(arguments_)) {
    printPruneHelp();
    return 0;
  }

  const dryRun = parsePruneArguments(arguments_);

  if (dryRun === undefined) {
    return 1;
  }

  if (!isDeletionRootSafe()) {
    return 1;
  }

  let remoteRepositories;

  try {
    remoteRepositories = getRemoteRepositories();
  } catch (error) {
    console.error(`Could not list remote repositories: ${getErrorMessage(error)}`);
    return 1;
  }

  if (remoteRepositories.length >= 1000) {
    console.error(
      'Refusing to prune: the remote repository list may be truncated at 1000 entries.',
    );
    return 1;
  }

  const remoteNames = new Set(
    remoteRepositories.map((repository) => repository.name),
  );
  const repositories = findLocalRepositories().filter(
    (repository) => !remoteNames.has(repository.name),
  );

  if (repositories.length === 0) {
    console.log('No obsolete local Git repositories found.');
    return 0;
  }

  if (dryRun) {
    console.log('Dry run; the following directories would be deleted:');
    printRepositoryPaths(repositories);
    return 0;
  }

  const statuses = inspectLocalRepositories(repositories, false);
  const uncleanStatuses = statuses.filter(isLocalRepositoryUnclean);

  console.log(
    'The following local repositories no longer exist remotely and will be permanently deleted:',
  );
  printRepositoryPaths(repositories);
  console.log('');

  if (!(await confirmRepositoryDeletion(uncleanStatuses))) {
    return 1;
  }

  let refreshedRemoteRepositories;

  try {
    refreshedRemoteRepositories = getRemoteRepositories();
  } catch (error) {
    console.error(
      `Could not verify remote repositories: ${getErrorMessage(error)}`,
    );
    console.error('Nothing was deleted.');
    return 1;
  }

  const refreshedRemoteNames = new Set(
    refreshedRemoteRepositories.map((repository) => repository.name),
  );
  const restoredRepositories = repositories.filter((repository) =>
    refreshedRemoteNames.has(repository.name),
  );

  if (restoredRepositories.length > 0) {
    console.error(
      'Remote repository state changed during confirmation. Nothing was deleted.',
    );
    console.error(
      `Now present remotely: ${restoredRepositories.map((repository) => repository.name).join(', ')}`,
    );
    return 1;
  }

  return removeLocalRepositories(repositories);
}

function parsePruneArguments(arguments_) {
  if (arguments_.length === 0) {
    return false;
  }

  if (
    arguments_.length === 1 &&
    (arguments_[0] === '--dry-run' || arguments_[0] === '-n')
  ) {
    return true;
  }

  console.error(`Unexpected prune option: ${arguments_[0]}`);
  printPruneHelp();
  return undefined;
}

function printPruneHelp() {
  console.log(getPruneHelpText());
}

function getPruneHelpText() {
  const lines = [
    'Usage: ./libs.mjs prune [options]',
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
    'Usage: ./libs.mjs remote [options]',
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

function showLocalRepositoryStatuses(arguments_) {
  if (isHelpRequest(arguments_)) {
    printStatusHelp();
    return 0;
  }

  const fetch = parseStatusArguments(arguments_);

  if (fetch === undefined) {
    return 1;
  }

  const repositories = findLocalRepositories();

  if (repositories.length === 0) {
    console.log(`No local Git repositories found in ${ROOT_DIR}.`);
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
    'Usage: ./libs.mjs status [options]',
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

function syncRepositories(arguments_) {
  if (isHelpRequest(arguments_)) {
    printSyncHelp();
    return 0;
  }

  if (!acceptsNoArguments('sync', arguments_, printSyncHelp)) {
    return 1;
  }

  let remoteRepositories;

  try {
    remoteRepositories = getRemoteRepositories();
  } catch (error) {
    console.error(`Could not list remote repositories: ${getErrorMessage(error)}`);
    return 1;
  }

  const localRepositories = findLocalRepositories();
  const localNames = new Set(
    localRepositories.map((repository) => repository.name),
  );
  const missingRepositories = remoteRepositories.filter(
    (repository) => !localNames.has(repository.name),
  );
  const operations = [
    ...localRepositories.map((repository) => ({
      repository,
      run: syncLocalRepository,
    })),
    ...missingRepositories.map((repository) => ({
      repository,
      run: cloneRemoteRepository,
    })),
  ].sort((left, right) =>
    left.repository.name.localeCompare(right.repository.name),
  );

  if (operations.length === 0) {
    console.log('No local or remote Git repositories found.');
    return 0;
  }

  const results = runSyncOperations(operations);

  return results.some((result) => !result.succeeded) ? 1 : 0;
}

function runSyncOperations(operations) {
  const indexWidth = String(operations.length).length;
  const nameWidth = Math.max(
    ...operations.map(({ repository }) => repository.name.length),
  );
  const results = [];

  console.log(`Synchronizing ${operations.length} repositories...`);

  for (const [index, { repository, run }] of operations.entries()) {
    const current = String(index + 1).padStart(indexWidth);
    const progress = `[${current}/${operations.length}]`;
    process.stdout.write(
      `${progress} ${repository.name.padEnd(nameWidth)}  `,
    );

    let result;

    try {
      result = run(repository);
    } catch (error) {
      result = createSyncFailure(repository, getErrorMessage(error));
    }

    console.log(result.message);
    results.push(result);
  }

  return results;
}

function cloneRemoteRepository(repository) {
  const result = runProcess(
    'gh',
    ['repo', 'clone', repository.nameWithOwner, join(ROOT_DIR, repository.name)],
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

function syncLocalRepository(repository) {
  try {
    getGitOutput(repository, ['fetch', '--all', '--prune']);

    const branch = getSymbolicCurrentBranch(repository);

    if (branch === undefined) {
      return createSyncFailure(repository, 'detached HEAD');
    }

    const changes = getWorkingTreeChanges(repository);

    if (hasWorkingTreeChanges(changes)) {
      return createSyncFailure(
        repository,
        `working tree is not clean (${formatChanges(changes)})`,
      );
    }

    const upstream = getBranchUpstream(repository, branch);

    if (upstream === undefined) {
      return createSyncFailure(repository, `${branch} has no upstream`);
    }

    const previousHead = getGitOutput(repository, ['rev-parse', 'HEAD']).trim();
    getGitOutput(repository, ['merge', '--ff-only', upstream]);
    const currentHead = getGitOutput(repository, ['rev-parse', 'HEAD']).trim();
    const state = currentHead === previousHead ? 'up to date' : 'updated';

    return {
      name: repository.name,
      succeeded: true,
      message: `[${branch} -> ${upstream}]  ${state}`,
    };
  } catch (error) {
    return createSyncFailure(repository, getErrorMessage(error));
  }
}

function createSyncFailure(repository, message) {
  return {
    name: repository.name,
    succeeded: false,
    message: `ERROR: ${toSingleLine(message)}`,
  };
}

function printSyncHelp() {
  console.log(getSyncHelpText());
}

function getSyncHelpText() {
  const lines = [
    'Usage: ./libs.mjs sync [options]',
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
    'Usage: ./libs.mjs help [command]',
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
    'Usage: ./libs.mjs <command>',
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
    'Run "./libs.mjs help <command>" for detailed command help.',
  ];

  return lines.join('\n');
}

// =============================================================================
// Shared utilities
// =============================================================================

function createDependencyGraph(repositories) {
  const packages = repositories.map(readLocalPackage);
  const packagesByName = new Map();
  const packagesByPath = new Map();

  for (const package_ of packages) {
    if (packagesByName.has(package_.name)) {
      throw new Error(`duplicate package name "${package_.name}"`);
    }

    packagesByName.set(package_.name, package_);
    packagesByPath.set(package_.path, package_);
  }

  return packages.map((package_) => ({
    ...package_,
    dependencies: findLocalPackageDependencies(package_, packagesByPath),
  }));
}

function readLocalPackage(repository) {
  const manifestPath = join(repository.path, 'package.json');
  let manifest;

  try {
    manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
  } catch (error) {
    throw new Error(
      `${repository.name}/package.json could not be read: ${getErrorMessage(error)}`,
    );
  }

  if (
    typeof manifest.name !== 'string' ||
    !manifest.name.startsWith(LOCAL_PACKAGE_PREFIX)
  ) {
    throw new Error(
      `${repository.name}/package.json must have a name in the ${LOCAL_PACKAGE_SCOPE} scope`,
    );
  }

  return {
    manifest,
    name: manifest.name,
    path: realpathSync(repository.path),
  };
}

function findLocalPackageDependencies(package_, packagesByPath) {
  const localDependencies = new Set();

  for (const field of DEPENDENCY_FIELDS) {
    const dependencies = package_.manifest[field];

    if (dependencies === undefined) {
      continue;
    }

    if (
      dependencies === null ||
      typeof dependencies !== 'object' ||
      Array.isArray(dependencies)
    ) {
      throw new Error(`${package_.name} has an invalid ${field} field`);
    }

    for (const [name, specifier] of Object.entries(dependencies)) {
      if (!name.startsWith(LOCAL_PACKAGE_PREFIX)) {
        continue;
      }

      if (typeof specifier !== 'string' || !specifier.startsWith('file:')) {
        throw new Error(
          `${package_.name} declares ${name} in ${field} with "${specifier}"; ` +
            'local packages must use the file: protocol',
        );
      }

      const dependency = resolveLocalPackageDependency(
        package_,
        name,
        specifier,
        packagesByPath,
      );

      localDependencies.add(dependency.name);
    }
  }

  return [...localDependencies].sort((left, right) =>
    left.localeCompare(right),
  );
}

function resolveLocalPackageDependency(
  package_,
  dependencyName,
  specifier,
  packagesByPath,
) {
  const dependencyPath = specifier.slice('file:'.length);

  if (dependencyPath.length === 0) {
    throw new Error(`${package_.name} declares an empty path for ${dependencyName}`);
  }

  let resolvedPath;

  try {
    resolvedPath = realpathSync(resolve(package_.path, dependencyPath));
  } catch (error) {
    throw new Error(
      `${package_.name} declares ${dependencyName} at ${specifier}, but that path could not be resolved: ` +
        getErrorMessage(error),
    );
  }

  const dependency = packagesByPath.get(resolvedPath);

  if (dependency === undefined) {
    throw new Error(
      `${package_.name} declares ${dependencyName} at ${specifier}, but that directory is not a local repository`,
    );
  }

  if (dependency.name !== dependencyName) {
    throw new Error(
      `${package_.name} declares ${dependencyName} at ${specifier}, but that package is named ${dependency.name}`,
    );
  }

  return dependency;
}

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

function isDeletionRootSafe() {
  if (resolve(ROOT_DIR) === REQUIRED_ROOT_DIR) {
    return true;
  }

  console.error(`Refusing to delete: unexpected operation root: ${ROOT_DIR}`);
  console.error(`Expected operation root: ${REQUIRED_ROOT_DIR}`);
  return false;
}

async function confirmRepositoryDeletion(uncleanStatuses) {
  if (!process.stdin.isTTY || !process.stdout.isTTY) {
    console.error('Deletion requires an interactive terminal. Nothing was deleted.');
    return false;
  }

  const confirmation = 'delete';
  const readline = createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  try {
    const answer = await readline.question(
      `Type "${confirmation}" to continue: `,
    );

    if (answer !== confirmation) {
      console.log('Deletion cancelled. Nothing was deleted.');
      return false;
    }

    console.log('');

    if (uncleanStatuses.length > 0) {
      printUncleanRepositoryReasons(uncleanStatuses);
      console.log('');

      const uncleanAnswer = await readline.question(
        `Type "${confirmation}" to continue: `,
      );

      if (uncleanAnswer !== confirmation) {
        console.log('Deletion cancelled. Nothing was deleted.');
        return false;
      }

      console.log('');
    }

    return true;
  } finally {
    readline.close();
  }
}

function printUncleanRepositoryReasons(statuses) {
  console.log('Unclean repositories:');

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

    console.log(`  ${status.name}`);

    for (const reason of reasons) {
      console.log(`    - ${reason}`);
    }
  }
}

function isLocalRepositoryUnclean(status) {
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

function printRepositoryPaths(repositories) {
  for (const repository of repositories) {
    console.log(`  ${repository.path}`);
  }
}

function removeLocalRepositories(repositories) {
  const failures = [];

  for (const repository of repositories) {
    try {
      rmSync(repository.path, { recursive: true, force: false });
      console.log(`Deleted ${repository.path}`);
    } catch (error) {
      failures.push(repository.path);
      console.error(
        `Could not delete ${repository.path}: ${getErrorMessage(error)}`,
      );
    }
  }

  if (failures.length > 0) {
    console.error(
      `Failed to delete ${failures.length} of ${repositories.length} repositories.`,
    );
    return 1;
  }

  console.log(`Deleted ${repositories.length} repositories.`);
  return 0;
}

function inspectLocalRepositories(repositories, fetch) {
  return inspectRepositories(repositories, fetch, (repository) => repository.name);
}

function findLocalRepositories() {
  return findChildGitRepositories(ROOT_DIR)
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
