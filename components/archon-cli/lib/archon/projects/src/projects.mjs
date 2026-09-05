#!/usr/bin/env node

import {
  mkdirSync,
  readdirSync,
} from 'node:fs';
import { homedir } from 'node:os';
import { join, resolve } from 'node:path';

import {
  deleteRepositories,
  pruneRepositories,
} from '../../shared/destructive-workflows.mjs';
import { getErrorMessage, toSingleLine } from '../../shared/errors.mjs';
import { pathExists } from '../../shared/paths.mjs';
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
  addRemoteRepositories,
  compareNames,
  compareRepositories,
  getRepositoryBlacklistLookupNames,
  isRepositoryBlacklisted,
  parseRemoteRepository,
  REPOSITORY_QUERY,
  repositoryKey,
  validateBlacklists,
} from './github-inventory.mjs';

// =============================================================================
// Entry point and command routing
// =============================================================================

export async function main(arguments_, context = {}) {
  const homeDir = context.homeDir ?? homedir();
  const requiredRootDir = resolve(homeDir, 'projects/personal');
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
    case 'delete': {
      return deleteLocalRepositories(extraArguments, paths);
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
      console.error('Missing projects command.');
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
// Command: delete
// =============================================================================

async function deleteLocalRepositories(arguments_, paths) {
  return deleteRepositories(arguments_, {
    emptyMessage: `No local Git repositories found under ${paths.rootDir}/<owner>/<repository>.`,
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
    'Usage: archon projects delete [options]',
    '',
    'Permanently delete every local <owner>/<repository>.',
    '',
    'Options:',
    '  -n, --dry-run  List repositories without deleting them',
    '  -h, --help     Show help for this command',
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
    getRemoteRepositories: (refresh) =>
      refresh
        ? getRemoteRepositories()
        : getRemoteRepositories((message) => console.log(message)),
    getRepositoryName: (repository) => repository.nameWithOwner,
    inspectRepositories: inspectLocalRepositories,
    printHelp: printPruneHelp,
    requiredRootDir: paths.requiredRootDir,
    rootDir: paths.rootDir,
  });
}

function findPrunableRepositories(remoteRepositories, rootDir) {
  const remoteNames = new Set(remoteRepositories.map(repositoryKey));

  return findLocalRepositories(rootDir).filter(
    (repository) =>
      !isRepositoryBlacklisted(repository) &&
      !remoteNames.has(repositoryKey(repository)),
  );
}

function findRestoredRepositories(repositories, remoteRepositories) {
  const remoteNames = new Set(remoteRepositories.map(repositoryKey));
  return repositories.filter((repository) =>
    remoteNames.has(repositoryKey(repository)),
  );
}

function printPruneHelp() {
  console.log(getPruneHelpText());
}

function getPruneHelpText() {
  const lines = [
    'Usage: archon projects prune [options]',
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
    return 2;
  }

  try {
    const repositories = getRemoteRepositories();

    if (repositories.length === 0) {
      console.log('No remote repositories found after applying the blacklists.');
      return 0;
    }

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

  if (repository.visibility !== 'public') {
    labels.push(repository.visibility);
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
    'Usage: archon projects remote [options]',
    '',
    'List included repositories owned by the authenticated GitHub user.',
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
    return 2;
  }

  const repositories = findLocalRepositories(rootDir);

  if (repositories.length === 0) {
    console.log(
      `No local Git repositories found under ${rootDir}/<owner>/<repository>.`,
    );
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
    'Usage: archon projects status [options]',
    '',
    'Show concise local Git status for every owner/repository.',
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
  if (arguments_.length === 0) {
    mkdirSync(rootDir, { recursive: true });
  }

  return runSyncWorkflow(arguments_, {
    cloneRepository: (repository) =>
      cloneRemoteRepository(repository, rootDir),
    compareRepositories,
    findLocalRepositories: () => findLocalRepositories(rootDir),
    getRemoteRepositories,
    getRepositoryKey: repositoryKey,
    getRepositoryName: (repository) => repository.nameWithOwner,
    printHelp: printSyncHelp,
  });
}

function cloneRemoteRepository(repository, rootDir) {
  const ownerPath = join(rootDir, repository.owner);
  const destination = join(ownerPath, repository.name);

  if (pathExists(destination)) {
    return createSyncFailure(
      repository,
      `destination already exists and is not a repository: ${destination}`,
    );
  }

  try {
    mkdirSync(ownerPath, { recursive: true });
  } catch (error) {
    return createSyncFailure(
      repository,
      `could not create owner directory: ${getErrorMessage(error)}`,
    );
  }

  const result = runProcess('git', ['clone', repository.sshUrl, destination], {
    encoding: 'utf8',
  });

  if (result.error) {
    return createSyncFailure(
      repository,
      `could not start Git: ${result.error.message}`,
    );
  }

  if (result.signal) {
    return createSyncFailure(
      repository,
      `Git was terminated by signal ${result.signal}`,
    );
  }

  if (result.status !== 0) {
    return createSyncFailure(
      repository,
      toSingleLine(result.stderr) || 'git clone failed',
    );
  }

  return {
    name: repository.nameWithOwner,
    succeeded: true,
    message: 'cloned',
  };
}

function createSyncFailure(repository, message) {
  return createRepositorySyncFailure(
    repository,
    message,
    (repository_) => repository_.nameWithOwner,
  );
}

function printSyncHelp() {
  console.log(getSyncHelpText());
}

function getSyncHelpText() {
  const lines = [
    'Usage: archon projects sync [options]',
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
  return 2;
}

function printHelpHelp() {
  console.log(getHelpHelpText());
}

function getHelpHelpText() {
  const lines = [
    'Usage: archon projects help [command]',
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
    'Usage: archon projects <command>',
    '',
    'Commands:',
    '  delete  Delete all local repositories inside personal',
    '  prune   Delete local repositories that no longer exist remotely',
    '  remote  List included repositories owned by the GitHub user',
    '  status  Show concise local Git status for every repository',
    '  sync    Update existing repositories and clone missing repositories',
    '  help    Show global or command-specific help',
    '',
    'Run "archon projects help <command>" for detailed command help.',
  ];

  return lines.join('\n');
}

// =============================================================================
// Shared utilities
// =============================================================================

function getRemoteRepositories(reportProgress) {
  reportProgress?.('Discovering the authenticated GitHub user...');
  const username = getAuthenticatedGitHubUser();

  reportProgress?.('Discovering owned GitHub organizations...');
  const organizations = getOwnedGitHubOrganizations();

  reportProgress?.('Validating repository exclusions...');
  const {
    blacklistedOrganizations,
    blacklistedRepositories,
  } = validateBlacklists(
    username,
    organizations,
    getCanonicalBlacklistedRepositories(),
  );
  const repositoriesByName = new Map();

  reportProgress?.(`Listing repositories for ${username}...`);
  addRemoteRepositories(
    repositoriesByName,
    getRemoteRepositoriesAt(
      'user/repos?affiliation=owner&visibility=all&per_page=100',
    ),
  );

  for (const organization of organizations) {
    if (blacklistedOrganizations.has(organization.toLowerCase())) {
      continue;
    }

    reportProgress?.(`Listing repositories for ${organization}...`);
    addRemoteRepositories(
      repositoriesByName,
      getRemoteRepositoriesAt(
        `orgs/${organization}/repos?type=all&per_page=100`,
      ),
    );
  }

  for (const repository of blacklistedRepositories) {
    repositoriesByName.delete(repository);
  }

  return [...repositoriesByName.values()].sort(compareRepositories);
}

function getAuthenticatedGitHubUser() {
  const username = getGitHubOutput(['user', '--jq', '.login']).trim();

  if (username.length === 0) {
    throw new Error('GitHub returned an empty username.');
  }

  return username;
}

function getOwnedGitHubOrganizations() {
  const output = getGitHubOutput([
    '--paginate',
    'user/memberships/orgs?state=active&per_page=100',
    '--jq',
    '.[] | select(.role == "admin") | .organization.login',
  ]);

  return output
    .split('\n')
    .map((organization) => organization.trim())
    .filter((organization) => organization.length > 0)
    .sort(compareNames);
}

function getCanonicalBlacklistedRepositories() {
  const repositories = new Map();

  for (const nameWithOwner of getRepositoryBlacklistLookupNames()) {
    try {
      const canonicalName = getGitHubOutput([
        `repos/${nameWithOwner}`,
        '--jq',
        '.full_name',
      ]).trim();
      repositories.set(nameWithOwner.toLowerCase(), canonicalName);
    } catch {
      // Blacklist validation reports inaccessible repositories.
    }
  }

  return repositories;
}

function getRemoteRepositoriesAt(endpoint) {
  const output = getGitHubOutput([
    '--paginate',
    endpoint,
    '--jq',
    REPOSITORY_QUERY,
  ]);

  return output
    .split('\n')
    .filter((line) => line.length > 0)
    .map(parseRemoteRepository);
}

function getGitHubOutput(arguments_) {
  const result = runProcess(
    'gh',
    ['api', '--hostname', 'github.com', ...arguments_],
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

  return result.stdout;
}

function inspectLocalRepositories(repositories, fetch) {
  return inspectRepositories(
    repositories,
    fetch,
    (repository) => repository.nameWithOwner,
  );
}

function findLocalRepositories(rootDir) {
  const repositories = [];
  let entries;

  try {
    entries = readdirSync(rootDir, { withFileTypes: true });
  } catch (error) {
    if (error?.code === 'ENOENT') {
      return repositories;
    }

    throw error;
  }

  const owners = entries
    .filter((entry) => entry.isDirectory() && entry.name !== '.git')
    .sort((left, right) => compareNames(left.name, right.name));

  for (const owner of owners) {
    const ownerPath = join(rootDir, owner.name);
    for (const repository of findChildGitRepositories(ownerPath)) {
      repositories.push({
        owner: owner.name,
        name: repository.name,
        nameWithOwner: `${owner.name}/${repository.name}`,
        path: repository.path,
      });
    }
  }

  return repositories.sort(compareRepositories);
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
    case 'delete': {
      printDeleteHelp();
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
