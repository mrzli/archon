import type {
  SpawnSyncOptions,
  SpawnSyncOptionsWithStringEncoding,
  SpawnSyncReturns,
} from 'node:child_process';
import { spawnSync } from 'node:child_process';

export function runProcess(
  command: string,
  arguments_: readonly string[],
  options: SpawnSyncOptionsWithStringEncoding,
): SpawnSyncReturns<string>;
export function runProcess(
  command: string,
  arguments_: readonly string[],
  options?: SpawnSyncOptions,
): SpawnSyncReturns<string | Buffer>;
export function runProcess(
  command: string,
  arguments_: readonly string[],
  options: SpawnSyncOptions = {},
): SpawnSyncReturns<string | Buffer> {
  return spawnSync(command, arguments_, options);
}
