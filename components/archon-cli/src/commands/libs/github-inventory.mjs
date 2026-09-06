import { getErrorMessage } from '../../shared/index.ts';

export function parseRemoteRepositories(output) {
  try {
    const repositories = JSON.parse(output);

    if (!Array.isArray(repositories)) {
      throw new Error('expected an array');
    }

    return repositories.map((repository) => {
      if (
        typeof repository.name !== 'string' ||
        typeof repository.nameWithOwner !== 'string'
      ) {
        throw new Error('repository name is missing');
      }

      return {
        name: repository.name,
        nameWithOwner: repository.nameWithOwner,
        isPrivate: repository.isPrivate,
        isArchived: repository.isArchived,
      };
    });
  } catch (error) {
    throw new Error(`Could not read GitHub CLI output: ${getErrorMessage(error)}`);
  }
}
