import { getErrorMessage } from '../../shared/index.ts';

export interface RemoteRepository {
  readonly name: string;
  readonly nameWithOwner: string;
  readonly isPrivate: unknown;
  readonly isArchived: unknown;
}

export function parseRemoteRepositories(output: string): readonly RemoteRepository[] {
  try {
    const repositories: unknown = JSON.parse(output);

    if (!Array.isArray(repositories)) {
      throw new Error('expected an array');
    }

    // Null entries retain their existing native property-access failure.
    return repositories.map((repository: unknown): RemoteRepository => {
      if (
        typeof repository !== 'object' ||
        (repository !== null &&
          (!('name' in repository) || !('nameWithOwner' in repository))) ||
        typeof repository!.name !== 'string' ||
        typeof repository!.nameWithOwner !== 'string'
      ) {
        throw new Error('repository name is missing');
      }

      return {
        name: repository!.name,
        nameWithOwner: repository!.nameWithOwner,
        isPrivate: 'isPrivate' in repository! ? repository.isPrivate : undefined,
        isArchived: 'isArchived' in repository! ? repository.isArchived : undefined,
      };
    });
  } catch (error) {
    throw new Error(`Could not read GitHub CLI output: ${getErrorMessage(error)}`);
  }
}
