import type { SpawnSyncReturns } from 'node:child_process';
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

export interface Fixture {
  readonly bin: string;
  readonly home: string;
  readonly root: string;
}

const componentRoot = fileURLToPath(new URL('..', import.meta.url));
const archon = join(componentRoot, 'dist/bin/archon');

export function createFixture(name: string): Fixture {
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

export function removeFixture(fixture: Fixture): void {
  rmSync(fixture.root, { recursive: true, force: true });
}

export function createGitEnvironment(
  fixture: Fixture,
  overrides: NodeJS.ProcessEnv = {},
): NodeJS.ProcessEnv {
  const inherited = Object.fromEntries(
    Object.entries(process.env).filter(([key]): boolean => !key.startsWith('GIT_')),
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
export function withGitFixture<T>(name: string, run: (fixture: Fixture) => T): T {
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

export function runArchon(
  fixture: Fixture,
  arguments_: readonly string[],
  environment: NodeJS.ProcessEnv = {},
): SpawnSyncReturns<string> {
  // Keep the CLI runtime separate from fake Bun package commands on PATH.
  return spawnSync(process.execPath, [archon, ...arguments_], {
    encoding: 'utf8',
    env: createGitEnvironment(fixture, {
      TMUX: '',
      TMUX_PANE: '',
      XDG_STATE_HOME: join(fixture.home, '.local/state'),
      ...environment,
    }),
  });
}

export function writeExecutable(path: string, content: string): void {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, content);
  chmodSync(path, 0o755);
}

export function writeLibrary(
  fixture: Fixture,
  directoryName: string,
  manifest: unknown,
  options: { readonly git?: boolean } = {},
): string {
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
