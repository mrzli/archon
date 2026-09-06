import { readdirSync } from 'node:fs';
import { join } from 'node:path';

import type { Repository } from './git.ts';
import { getErrorMessage, toSingleLine } from './errors.ts';
import {
  getGitOutput,
  runGit,
  throwGitError,
} from './git.ts';
import { isGitRepository } from './paths.ts';

export interface WorkingTreeChanges {
  readonly staged: number;
  readonly unstaged: number;
  readonly untracked: number;
}

export type RepositoryStatus = {
  readonly name: string;
  readonly warnings: readonly string[];
} & ({
  readonly error?: undefined;
  readonly branch: string;
  readonly changes: WorkingTreeChanges;
  readonly stashCount: number;
  readonly ahead: readonly string[];
} | {
  readonly error: string;
});


type ValidRepositoryStatus = Extract<RepositoryStatus, { readonly error?: undefined }>;

export function findChildGitRepositories(root: string): { readonly name: string; readonly path: string; }[] {
  return readdirSync(root, { withFileTypes: true })
    .filter((entry): boolean => entry.isDirectory())
    .filter((entry): boolean => isGitRepository(join(root, entry.name)))
    .map((entry): { readonly name: string; readonly path: string; } => ({
      name: entry.name,
      path: join(root, entry.name),
    }));
}

export function formatChanges(changes: WorkingTreeChanges): string {
  const parts = [];

  if (changes.staged > 0) {
    parts.push(`staged: ${changes.staged}`);
  }

  if (changes.unstaged > 0) {
    parts.push(`unstaged: ${changes.unstaged}`);
  }

  if (changes.untracked > 0) {
    parts.push(`untracked: ${changes.untracked}`);
  }

  return parts.length > 0 ? parts.join(', ') : 'clean';
}

export function getBranchUpstream(repository: Repository, branch: string): string | undefined {
  const output = getGitOutput(repository, [
    'for-each-ref',
    '--format=%(upstream:short)',
    `refs/heads/${branch}`,
  ]).trim();

  return output.length > 0 ? output : undefined;
}

export function getSymbolicCurrentBranch(repository: Repository): string | undefined {
  const result = runGit(repository, [
    'symbolic-ref',
    '--quiet',
    '--short',
    'HEAD',
  ]);

  if (result.status === 0) {
    return result.stdout.trim();
  }

  if (result.status === 1) {
    return undefined;
  }

  throwGitError(result, 'could not determine current branch');
}

export function getWorkingTreeChanges(repository: Repository): WorkingTreeChanges {
  const output = getGitOutput(repository, [
    'status',
    '--porcelain=v1',
    '-z',
    '--untracked-files=normal',
  ]);
  const entries: readonly string[] = output.split('\0');
  const changes = {
    staged: 0,
    unstaged: 0,
    untracked: 0,
  };

  for (let index = 0; index < entries.length; index += 1) {
    const entry = entries[index];

    if (entry.length === 0) {
      continue;
    }

    const status = entry.slice(0, 2);

    if (status === '??') {
      changes.untracked += 1;
      continue;
    }

    if (status[0] !== ' ') {
      changes.staged += 1;
    }

    if (status[1] !== ' ') {
      changes.unstaged += 1;
    }

    if ('RC'.includes(status[0]) || 'RC'.includes(status[1])) {
      index += 1;
    }
  }

  return changes;
}

export function hasWorkingTreeChanges(changes: WorkingTreeChanges): boolean {
  return (
    changes.staged > 0 || changes.unstaged > 0 || changes.untracked > 0
  );
}

export function inspectLocalRepositories<R extends Repository>(
  repositories: readonly R[],
  fetch: boolean,
  getName: (repository: R) => string,
): readonly RepositoryStatus[] {
  return repositories.map((repository): RepositoryStatus =>
    inspectLocalRepository(repository, fetch, getName),
  );
}

export function printLocalRepositoryStatuses(statuses: readonly RepositoryStatus[]): void {
  const nameWidth = Math.max(...statuses.map((status): number => status.name.length));
  const validStatuses: readonly ValidRepositoryStatus[] = statuses.filter((status): status is ValidRepositoryStatus => status.error === undefined);
  const branchWidth = Math.max(
    0,
    ...validStatuses.map((status): number => status.branch.length),
  );
  const changeTexts = new Map(
    validStatuses.map((status): [ValidRepositoryStatus, string] => [status, formatChanges(status.changes)]),
  );
  const changesWidth = Math.max(
    0,
    ...[...changeTexts.values()].map((text): number => text.length),
  );

  for (const status of statuses) {
    const name = status.name.padEnd(nameWidth);

    if (status.error !== undefined) {
      console.log(`${name}  ERROR: ${toSingleLine(status.error)}`);
      continue;
    }

    const branch = `[${status.branch.padEnd(branchWidth)}]`;
    // Every successful status was inserted into changeTexts above.
    const changes = changeTexts.get(status)!.padEnd(changesWidth);
    const ahead = status.ahead.length > 0 ? status.ahead.join(', ') : 'none';
    const warnings =
      status.warnings.length > 0
        ? `  warnings: ${status.warnings.map(toSingleLine).join(', ')}`
        : '';

    console.log(
      `${name}  ${branch}  ${changes}  stash: ${status.stashCount}  ahead: ${ahead}${warnings}`,
    );
  }
}

function getAheadBranches(repository: Repository, warnings: string[]): readonly string[] {
  const output = getGitOutput(repository, [
    'for-each-ref',
    '--format=%(refname:short)%09%(refname)%09%(upstream:short)%09%(upstream)',
    'refs/heads',
  ]);
  const branches: readonly { readonly name: string; readonly ref: string; readonly upstream: string; readonly upstreamRef: string; }[] = output
    .trimEnd()
    .split('\n')
    .filter((line): boolean => line.length > 0)
    .map((line): { readonly name: string; readonly ref: string; readonly upstream: string; readonly upstreamRef: string; } => {
      const [name, ref, upstream = '', upstreamRef = ''] = line.split('\t');
      return { name, ref, upstream, upstreamRef };
    });
  const ahead = [];

  for (const branch of branches) {
    if (branch.upstream.length > 0) {
      const result = runGit(repository, [
        'rev-list',
        '--count',
        `${branch.upstreamRef}..${branch.ref}`,
      ]);

      if (result.status === 0) {
        const count = Number.parseInt(result.stdout.trim(), 10);

        if (count > 0) {
          ahead.push(`${branch.name}=${count}`);
        }

        continue;
      }

      warnings.push(`${branch.name} upstream is missing`);
    }

    const count = Number.parseInt(
      getGitOutput(repository, [
        'rev-list',
        '--count',
        branch.ref,
        '--not',
        '--remotes',
      ]).trim(),
      10,
    );

    if (count > 0) {
      const reason =
        branch.upstream.length > 0 ? 'upstream missing' : 'no upstream';
      ahead.push(`${branch.name}=${count} (${reason})`);
    }
  }

  return ahead;
}

function getCurrentBranch(repository: Repository): string {
  const branchResult = runGit(repository, [
    'symbolic-ref',
    '--quiet',
    '--short',
    'HEAD',
  ]);

  if (branchResult.status === 0) {
    return branchResult.stdout.trim();
  }

  if (branchResult.status !== 1) {
    throwGitError(branchResult, 'could not determine current branch');
  }

  const commit = getGitOutput(repository, ['rev-parse', '--short', 'HEAD']);
  return `detached@${commit.trim()}`;
}

function getStashCount(repository: Repository): number {
  const output = getGitOutput(repository, ['stash', 'list', '--format=%gd']);

  if (output.length === 0) {
    return 0;
  }

  return output.trimEnd().split('\n').length;
}

function inspectLocalRepository<R extends Repository>(
  repository: R,
  fetch: boolean,
  getName: (repository: R) => string,
): RepositoryStatus {
  const warnings: string[] = [];

  if (fetch) {
    try {
      getGitOutput(repository, ['fetch', '--all', '--prune']);
    } catch (error) {
      warnings.push(`fetch failed: ${getErrorMessage(error)}`);
    }
  }

  try {
    const branch = getCurrentBranch(repository);
    const changes = getWorkingTreeChanges(repository);
    const stashCount = getStashCount(repository);
    const ahead = getAheadBranches(repository, warnings);

    return {
      name: getName(repository),
      branch,
      changes,
      stashCount,
      ahead,
      warnings,
    };
  } catch (error) {
    return {
      name: getName(repository),
      error: getErrorMessage(error),
      warnings,
    };
  }
}
