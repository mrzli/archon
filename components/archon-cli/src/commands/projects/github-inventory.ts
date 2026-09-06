export interface RepositoryIdentity {
  readonly owner: string;
  readonly name: string;
  readonly nameWithOwner: string;
}

export interface RemoteRepository extends RepositoryIdentity {
  readonly id: string;
  readonly sshUrl: string;
  readonly isArchived: boolean;
  readonly visibility: string;
}

export interface BlacklistPolicy {
  readonly organizationBlacklist?: readonly string[];
  readonly repositoryBlacklist?: readonly string[];
}

export const ORGANIZATION_BLACKLIST: readonly string[] = [
  'mrzli-courses',
  'mrzli-gh-actions',
  'mrzli-other',
  'mrzli-vscode-extensions',
];
export const REPOSITORY_BLACKLIST: string[] = [];
export const REPOSITORY_QUERY = [
  '.[]',
  '| [',
  '    .id,',
  '    .full_name,',
  '    .ssh_url,',
  '    .archived,',
  '    (.visibility // (if .private then "private" else "public" end))',
  '  ]',
  '| @tsv',
].join('\n');

const ORGANIZATION_PATTERN = /^[A-Za-z0-9][A-Za-z0-9-]*$/;
const REPOSITORY_PATTERN =
  /^[A-Za-z0-9][A-Za-z0-9-]*\/[A-Za-z0-9._-]+$/;

export function addRemoteRepositories<R extends { readonly nameWithOwner: string }>(
  repositoriesByName: Map<string, R>,
  repositories: readonly R[],
): void {
  for (const repository of repositories) {
    repositoriesByName.set(repositoryKey(repository), repository);
  }
}

export function compareNames(left: string, right: string): number {
  return left.localeCompare(right, undefined, { sensitivity: 'base' });
}

export function compareRepositories(
  left: { readonly nameWithOwner: string },
  right: { readonly nameWithOwner: string },
): number {
  return compareNames(left.nameWithOwner, right.nameWithOwner);
}

export function getRepositoryBlacklistLookupNames(
  repositoryBlacklist: readonly string[] = REPOSITORY_BLACKLIST,
): readonly string[] {
  const names = [];
  const seen = new Set<string>();

  for (const nameWithOwner of repositoryBlacklist) {
    const key = nameWithOwner.toLowerCase();

    if (!REPOSITORY_PATTERN.test(nameWithOwner) || seen.has(key)) {
      continue;
    }

    seen.add(key);
    names.push(nameWithOwner);
  }

  return names;
}

export function isRepositoryBlacklisted(
  repository: { readonly owner: string; readonly nameWithOwner: string },
  organizationBlacklist: readonly string[] = ORGANIZATION_BLACKLIST,
  repositoryBlacklist: readonly string[] = REPOSITORY_BLACKLIST,
): boolean {
  const owner = repository.owner.toLowerCase();

  return (
    organizationBlacklist.some(
      (organization): boolean => organization.toLowerCase() === owner,
    ) ||
    repositoryBlacklist.some(
      (nameWithOwner): boolean =>
        nameWithOwner.toLowerCase() === repositoryKey(repository),
    )
  );
}

export function parseRemoteRepository(row: string): RemoteRepository {
  const fields: readonly string[] = row.split('\t');
  const [id, nameWithOwner, sshUrl, archived, visibility] = fields;
  const separator = nameWithOwner?.indexOf('/') ?? -1;

  if (
    fields.length !== 5 ||
    typeof id !== 'string' ||
    id.length === 0 ||
    separator <= 0 ||
    separator === nameWithOwner.length - 1 ||
    typeof sshUrl !== 'string' ||
    sshUrl.length === 0 ||
    !['true', 'false'].includes(archived) ||
    typeof visibility !== 'string' ||
    visibility.length === 0
  ) {
    throw new Error(`GitHub returned incomplete repository data: ${row}`);
  }

  return {
    id,
    owner: nameWithOwner.slice(0, separator),
    name: nameWithOwner.slice(separator + 1),
    nameWithOwner,
    sshUrl,
    isArchived: archived === 'true',
    visibility,
  };
}

export function repositoryKey(repository: { readonly nameWithOwner: string }): string {
  return repository.nameWithOwner.toLowerCase();
}

export function validateBlacklists(
  username: string,
  organizations: readonly string[],
  canonicalRepositories: ReadonlyMap<string, string> = new Map(),
  policy: BlacklistPolicy = {},
): { readonly blacklistedOrganizations: Set<string>; readonly blacklistedRepositories: Set<string>; } {
  const organizationBlacklist =
    policy.organizationBlacklist ?? ORGANIZATION_BLACKLIST;
  const repositoryBlacklist =
    policy.repositoryBlacklist ?? REPOSITORY_BLACKLIST;
  const errors = [];
  const organizationsByName = new Map(
    organizations.map((organization): [string, string] => [organization.toLowerCase(), organization]),
  );
  const blacklistedOrganizations = new Set<string>();

  for (const organization of organizationBlacklist) {
    const key = organization.toLowerCase();

    if (!ORGANIZATION_PATTERN.test(organization)) {
      errors.push(`Invalid organization blacklist entry "${organization}".`);
      continue;
    }

    if (blacklistedOrganizations.has(key)) {
      errors.push(`Duplicate organization blacklist entry "${organization}".`);
      continue;
    }

    blacklistedOrganizations.add(key);

    if (!organizationsByName.has(key)) {
      errors.push(
        `Blacklisted organization "${organization}" is not an active organization owned by "${username}".`,
      );
    }
  }

  const blacklistedRepositories = new Set<string>();

  for (const nameWithOwner of repositoryBlacklist) {
    const key = nameWithOwner.toLowerCase();

    if (!REPOSITORY_PATTERN.test(nameWithOwner)) {
      errors.push(
        `Invalid repository blacklist entry "${nameWithOwner}"; expected "owner/repository".`,
      );
      continue;
    }

    if (blacklistedRepositories.has(key)) {
      errors.push(`Duplicate repository blacklist entry "${nameWithOwner}".`);
      continue;
    }

    blacklistedRepositories.add(key);

    if (!canonicalRepositories.has(key)) {
      errors.push(
        `Blacklisted repository "${nameWithOwner}" does not exist or is not accessible.`,
      );
      continue;
    }

    // The missing-key case exits above.
    const canonicalName = canonicalRepositories.get(key)!;

    if (canonicalName.toLowerCase() !== key) {
      errors.push(
        `Blacklisted repository "${nameWithOwner}" is now "${canonicalName}".`,
      );
      continue;
    }

    const owner = canonicalName.slice(0, canonicalName.indexOf('/'));
    const ownerKey = owner.toLowerCase();

    if (
      ownerKey !== username.toLowerCase() &&
      !organizationsByName.has(ownerKey)
    ) {
      errors.push(
        `Blacklisted repository "${nameWithOwner}" is not owned by "${username}" or an organization owned by that user.`,
      );
    }
  }

  if (errors.length > 0) {
    throw new Error(
      ['Blacklist validation failed:', ...errors.map((error): string => `  - ${error}`)].join(
        '\n',
      ),
    );
  }

  return { blacklistedOrganizations, blacklistedRepositories };
}
