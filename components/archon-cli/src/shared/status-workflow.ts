import type { RepositoryStatus } from './repository-inspection.ts';
import { isHelpRequest } from './arguments.ts';
import { printLocalRepositoryStatuses } from './repository-inspection.ts';

export interface StatusOptions<R> {
  readonly printHelp: () => void;
  readonly findRepositories: () => readonly R[];
  readonly inspectRepositories: (repositories: readonly R[], fetch: boolean) => readonly RepositoryStatus[];
  readonly emptyMessage: string;
}

export function runStatusWorkflow<R>(
  arguments_: readonly string[],
  options: StatusOptions<R>,
): number {
  if (isHelpRequest(arguments_)) {
    options.printHelp();
    return 0;
  }

  const fetch = parseStatusArguments(arguments_, options.printHelp);

  if (fetch === undefined) {
    return 2;
  }

  const repositories = options.findRepositories();

  if (repositories.length === 0) {
    console.log(options.emptyMessage);
    return 0;
  }

  const statuses = options.inspectRepositories(repositories, fetch);

  printLocalRepositoryStatuses(statuses);

  return statuses.some(
    (status): boolean => status.error !== undefined || status.warnings.length > 0,
  )
    ? 1
    : 0;
}

function parseStatusArguments(arguments_: readonly string[], printHelp: () => void): boolean | undefined {
  if (arguments_.length === 0) {
    return false;
  }

  if (arguments_.length === 1 && arguments_[0] === '--fetch') {
    return true;
  }

  console.error(`Unexpected status option: ${arguments_[0]}`);
  printHelp();
  return undefined;
}
