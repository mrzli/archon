import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const [modulePath, ...arguments_] = process.argv.slice(2);
const module = await import(pathToFileURL(resolve(modulePath)));

if (arguments_[0] !== '--import-only') {
  process.exitCode = await module.main(arguments_, { homeDir: process.env.HOME });
}
