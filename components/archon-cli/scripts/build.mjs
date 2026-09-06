import { chmod, cp, mkdir, rm, symlink } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';

async function build() {
  const componentRoot = new URL('../', import.meta.url);
  const dist = new URL('dist/', componentRoot);

  await rm(dist, { recursive: true, force: true });
  await mkdir(new URL('bin/', dist), { recursive: true });
  await cp(new URL('src/', componentRoot), new URL('lib/archon/', dist), {
    recursive: true,
    filter: (source) => !source.endsWith('.md'),
  });
  await cp(new URL('bin/archon', componentRoot), new URL('bin/archon', dist));
  await chmod(new URL('bin/archon', dist), 0o755);
  await symlink('archon', new URL('bin/arc', dist));

  console.log(`Built Archon CLI: ${fileURLToPath(dist)}`);
}

await build();
