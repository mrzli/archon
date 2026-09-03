import { spawnSync } from 'node:child_process';

export function runProcess(command, arguments_, options = {}) {
  return spawnSync(command, arguments_, options);
}
