import {
  readFileSync,
  realpathSync,
} from 'node:fs';
import { join, resolve } from 'node:path';

import { getErrorMessage } from '../../shared/index.ts';

export interface LocalPackage {
  readonly manifest: Record<string, unknown>;
  readonly name: string;
  readonly path: string;
}

export interface PackageNode extends LocalPackage {
  readonly dependencies: readonly string[];
}

export const LOCAL_PACKAGE_SCOPE = '@mrzli-jslib';

const LOCAL_PACKAGE_PREFIX = `${LOCAL_PACKAGE_SCOPE}/`;
const DEPENDENCY_FIELDS: readonly string[] = [
  'dependencies',
  'devDependencies',
  'optionalDependencies',
  'peerDependencies',
];

export function createDependencyGraph(
  repositories: readonly { readonly name: string; readonly path: string }[],
): readonly PackageNode[] {
  const packages: readonly LocalPackage[] = repositories.map(readLocalPackage);
  const packagesByName = new Map<string, LocalPackage>();
  const packagesByPath = new Map<string, LocalPackage>();

  for (const package_ of packages) {
    if (packagesByName.has(package_.name)) {
      throw new Error(`duplicate package name "${package_.name}"`);
    }

    packagesByName.set(package_.name, package_);
    packagesByPath.set(package_.path, package_);
  }

  return packages.map((package_): PackageNode => ({
    ...package_,
    dependencies: findLocalPackageDependencies(package_, packagesByPath),
  }));
}

export function orderPackagesForBuild(graph: readonly PackageNode[]): readonly PackageNode[] {
  const nodesByName = new Map(graph.map((node): [string, PackageNode] => [node.name, node]));
  const states = new Map<string, 'visiting' | 'visited'>();
  const path: string[] = [];
  const ordered: PackageNode[] = [];

  function visit(node: PackageNode): void {
    const state = states.get(node.name);

    if (state === 'visited') {
      return;
    }

    if (state === 'visiting') {
      const cycleStart = path.indexOf(node.name);
      const cycle: readonly string[] = [...path.slice(cycleStart), node.name];

      throw new Error(`dependency cycle detected: ${cycle.join(' -> ')}`);
    }

    states.set(node.name, 'visiting');
    path.push(node.name);

    for (const dependencyName of node.dependencies) {
      // Graph construction guarantees that each dependency names a local node.
      visit(nodesByName.get(dependencyName)!);
    }

    path.pop();
    states.set(node.name, 'visited');
    ordered.push(node);
  }

  for (const node of graph) {
    visit(node);
  }

  return ordered;
}

export function validateBuildScripts(graph: readonly PackageNode[]): void {
  for (const node of graph) {
    if (
      node.manifest.scripts === null ||
      typeof node.manifest.scripts !== 'object' ||
      Array.isArray(node.manifest.scripts) ||
      !('build' in node.manifest.scripts) ||
      typeof node.manifest.scripts.build !== 'string' ||
      node.manifest.scripts.build.length === 0
    ) {
      throw new Error(`${node.name} must define a non-empty build script`);
    }
  }
}

function readLocalPackage(repository: { readonly name: string; readonly path: string }): LocalPackage {
  const manifestPath = join(repository.path, 'package.json');
  let manifest: unknown;

  try {
    manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
  } catch (error) {
    throw new Error(
      `${repository.name}/package.json could not be read: ${getErrorMessage(error)}`,
    );
  }

  // Preserve the existing native property-access failure for a null manifest.
  if (
    typeof manifest !== 'object' ||
    (manifest !== null && !('name' in manifest)) ||
    typeof manifest!.name !== 'string' ||
    !manifest!.name.startsWith(LOCAL_PACKAGE_PREFIX)
  ) {
    throw new Error(
      `${repository.name}/package.json must have a name in the ${LOCAL_PACKAGE_SCOPE} scope`,
    );
  }

  return {
    manifest: manifest!,
    name: manifest!.name,
    path: realpathSync(repository.path),
  };
}

function findLocalPackageDependencies(
  package_: LocalPackage,
  packagesByPath: Map<string, LocalPackage>,
): readonly string[] {
  const localDependencies = new Set<string>();

  for (const field of DEPENDENCY_FIELDS) {
    const dependencies = package_.manifest[field];

    if (dependencies === undefined) {
      continue;
    }

    if (
      dependencies === null ||
      typeof dependencies !== 'object' ||
      Array.isArray(dependencies)
    ) {
      throw new Error(`${package_.name} has an invalid ${field} field`);
    }

    for (const [name, specifier] of Object.entries(dependencies)) {
      if (!name.startsWith(LOCAL_PACKAGE_PREFIX)) {
        continue;
      }

      if (typeof specifier !== 'string' || !specifier.startsWith('file:')) {
        throw new Error(
          `${package_.name} declares ${name} in ${field} with "${specifier}"; ` +
            'local packages must use the file: protocol',
        );
      }

      const dependency = resolveLocalPackageDependency(
        package_,
        name,
        specifier,
        packagesByPath,
      );

      localDependencies.add(dependency.name);
    }
  }

  return [...localDependencies].sort((left, right): number =>
    left.localeCompare(right),
  );
}

function resolveLocalPackageDependency(
  package_: LocalPackage,
  dependencyName: string,
  specifier: string,
  packagesByPath: Map<string, LocalPackage>,
): LocalPackage {
  const dependencyPath = specifier.slice('file:'.length);

  if (dependencyPath.length === 0) {
    throw new Error(`${package_.name} declares an empty path for ${dependencyName}`);
  }

  let resolvedPath;

  try {
    resolvedPath = realpathSync(resolve(package_.path, dependencyPath));
  } catch (error) {
    throw new Error(
      `${package_.name} declares ${dependencyName} at ${specifier}, but that path could not be resolved: ` +
        getErrorMessage(error),
    );
  }

  const dependency = packagesByPath.get(resolvedPath);

  if (dependency === undefined) {
    throw new Error(
      `${package_.name} declares ${dependencyName} at ${specifier}, but that directory is not a local repository`,
    );
  }

  if (dependency.name !== dependencyName) {
    throw new Error(
      `${package_.name} declares ${dependencyName} at ${specifier}, but that package is named ${dependency.name}`,
    );
  }

  return dependency;
}
