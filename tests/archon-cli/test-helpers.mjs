import { spawnSync } from 'node:child_process';
import {
  chmodSync,
  mkdirSync,
  mkdtempSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const repoRoot = fileURLToPath(new URL('../..', import.meta.url));
const archon = join(repoRoot, 'data/home/.local/bin/archon');

export function createFixture(name) {
  const root = mkdtempSync(join(tmpdir(), `archon-${name}-`));
  const fixture = {
    bin: join(root, 'bin'),
    home: join(root, 'home'),
    root,
  };

  mkdirSync(fixture.bin, { recursive: true });
  mkdirSync(fixture.home, { recursive: true });
  return fixture;
}

export function removeFixture(fixture) {
  rmSync(fixture.root, { recursive: true, force: true });
}

export function runArchon(fixture, arguments_, environment = {}) {
  return spawnSync(archon, arguments_, {
    encoding: 'utf8',
    env: {
      ...process.env,
      HOME: fixture.home,
      PATH: `${fixture.bin}:${process.env.PATH}`,
      ...environment,
    },
  });
}

export function writeExecutable(path, content) {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, content);
  chmodSync(path, 0o755);
}

export function writeLibrary(fixture, directoryName, manifest, options = {}) {
  const directory = join(
    fixture.home,
    'projects/personal/mrzli-jslib',
    directoryName,
  );

  mkdirSync(directory, { recursive: true });

  if (options.git !== false) {
    mkdirSync(join(directory, '.git'));
  }

  if (manifest !== undefined) {
    const content =
      typeof manifest === 'string'
        ? manifest
        : `${JSON.stringify(manifest, null, 2)}\n`;
    writeFileSync(join(directory, 'package.json'), content);
  }

  return directory;
}
