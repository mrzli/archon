import { toSingleLine } from './errors.mjs';
import { runProcess } from './process.mjs';

export function getGitOutput(repository, arguments_) {
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

export function runGit(repository, arguments_) {
  return runProcess('git', ['-C', repository.path, ...arguments_], {
    encoding: 'utf8',
  });
}

export function throwGitError(result, fallbackMessage) {
  const message = result.stderr.trim() || fallbackMessage;
  throw new Error(toSingleLine(message));
}
