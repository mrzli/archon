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

const componentRoot = fileURLToPath(new URL('..', import.meta.url));
const archon = join(componentRoot, 'bin/archon');

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

export function createGitEnvironment(fixture, overrides = {}) {
  const inherited = Object.fromEntries(
    Object.entries(process.env).filter(([key]) => !key.startsWith('GIT_')),
  );
  return {
    ...inherited,
    HOME: fixture.home,
    XDG_CONFIG_HOME: join(fixture.home, '.config'),
    PATH: `${fixture.bin}:${process.env.PATH}`,
    GIT_CONFIG_NOSYSTEM: '1',
    GIT_CONFIG_SYSTEM: '/dev/null',
    GIT_CONFIG_GLOBAL: '/dev/null',
    GIT_CONFIG_COUNT: '4',
    GIT_CONFIG_KEY_0: 'core.hooksPath',
    GIT_CONFIG_VALUE_0: '/dev/null',
    GIT_CONFIG_KEY_1: 'commit.gpgSign',
    GIT_CONFIG_VALUE_1: 'false',
    GIT_CONFIG_KEY_2: 'user.name',
    GIT_CONFIG_VALUE_2: 'Archon Test',
    GIT_CONFIG_KEY_3: 'user.email',
    GIT_CONFIG_VALUE_3: 'test@example.com',
    GIT_TERMINAL_PROMPT: '0',
    ...overrides,
  };
}

// Synchronous scope for real Git fixtures and workflows running in this process.
export function withGitFixture(name, run) {
  const fixture = createFixture(name);
  const previousEnvironment = process.env;
  try {
    process.env = createGitEnvironment(fixture);
    return run(fixture);
  } finally {
    process.env = previousEnvironment;
    removeFixture(fixture);
  }
}

export function runArchon(fixture, arguments_, environment = {}) {
  return spawnSync(archon, arguments_, {
    encoding: 'utf8',
    env: createGitEnvironment(fixture, environment),
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
