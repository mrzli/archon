import { toSingleLine } from './errors.ts';
import { runProcess } from './process.ts';

export interface Repository {
  path: string;
}

export function getGitOutput(repository: Repository, arguments_: readonly string[]): string {
  const result = runGit(repository, arguments_);

  if (result.error) {
    throw new Error(`could not start Git: ${result.error.message}`);
  }

  if (result.signal) {
    throw new Error(`Git was terminated by signal ${result.signal}`);
  }

  if (result.status !== 0) {
    throwGitError(result, `git ${arguments_[0]} failed`);
  }

  return result.stdout;
}

export function runGit(repository: Repository, arguments_: readonly string[]) {
  return runProcess('git', ['-C', repository.path, ...arguments_], {
    encoding: 'utf8',
  });
}

export function throwGitError(result: { stderr: string }, fallbackMessage: string): never {
  const message = result.stderr.trim() || fallbackMessage;
  throw new Error(toSingleLine(message));
}
