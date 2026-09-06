import { execFileSync } from 'node:child_process';
import { chmod, cp, mkdir, rm, symlink } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';

async function build() {
  const componentRoot = new URL('../', import.meta.url);
  const dist = new URL('dist/', componentRoot);
  const compiler = fileURLToPath(
    new URL('node_modules/typescript/bin/tsc', componentRoot),
  );

  execFileSync(process.execPath, [compiler, '--project', 'tsconfig.json'], {
    cwd: componentRoot,
    stdio: 'inherit',
  });

  await rm(dist, { recursive: true, force: true });
  execFileSync(process.execPath, [compiler, '--project', 'tsconfig.build.json'], {
    cwd: componentRoot,
    stdio: 'inherit',
  });
  await mkdir(new URL('bin/', dist), { recursive: true });
  await cp(new URL('bin/archon', componentRoot), new URL('bin/archon', dist));
  await chmod(new URL('bin/archon', dist), 0o755);
  await symlink('archon', new URL('bin/arc', dist));

  console.log(`Built Archon CLI: ${fileURLToPath(dist)}`);
}

await build();
