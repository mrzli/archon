import {
  readFileSync,
  realpathSync,
} from 'node:fs';
import { join, resolve } from 'node:path';

import { getErrorMessage } from '../../shared/index.ts';

export const LOCAL_PACKAGE_SCOPE = '@mrzli-jslib';

const LOCAL_PACKAGE_PREFIX = `${LOCAL_PACKAGE_SCOPE}/`;
const DEPENDENCY_FIELDS = [
  'dependencies',
  'devDependencies',
  'optionalDependencies',
  'peerDependencies',
];

export function createDependencyGraph(repositories) {
  const packages = repositories.map(readLocalPackage);
  const packagesByName = new Map();
  const packagesByPath = new Map();

  for (const package_ of packages) {
    if (packagesByName.has(package_.name)) {
      throw new Error(`duplicate package name "${package_.name}"`);
    }

    packagesByName.set(package_.name, package_);
    packagesByPath.set(package_.path, package_);
  }

  return packages.map((package_) => ({
    ...package_,
    dependencies: findLocalPackageDependencies(package_, packagesByPath),
  }));
}

export function orderPackagesForBuild(graph) {
  const nodesByName = new Map(graph.map((node) => [node.name, node]));
  const states = new Map();
  const path = [];
  const ordered = [];

  function visit(node) {
    const state = states.get(node.name);

    if (state === 'visited') {
      return;
    }

    if (state === 'visiting') {
      const cycleStart = path.indexOf(node.name);
      const cycle = [...path.slice(cycleStart), node.name];

      throw new Error(`dependency cycle detected: ${cycle.join(' -> ')}`);
    }

    states.set(node.name, 'visiting');
    path.push(node.name);

    for (const dependencyName of node.dependencies) {
      visit(nodesByName.get(dependencyName));
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

export function validateBuildScripts(graph) {
  for (const node of graph) {
    if (
      node.manifest.scripts === null ||
      typeof node.manifest.scripts !== 'object' ||
      Array.isArray(node.manifest.scripts) ||
      typeof node.manifest.scripts.build !== 'string' ||
      node.manifest.scripts.build.length === 0
    ) {
      throw new Error(`${node.name} must define a non-empty build script`);
    }
  }
}

function readLocalPackage(repository) {
  const manifestPath = join(repository.path, 'package.json');
  let manifest;

  try {
    manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
  } catch (error) {
    throw new Error(
      `${repository.name}/package.json could not be read: ${getErrorMessage(error)}`,
    );
  }

  if (
    typeof manifest.name !== 'string' ||
    !manifest.name.startsWith(LOCAL_PACKAGE_PREFIX)
  ) {
    throw new Error(
      `${repository.name}/package.json must have a name in the ${LOCAL_PACKAGE_SCOPE} scope`,
    );
  }

  return {
    manifest,
    name: manifest.name,
    path: realpathSync(repository.path),
  };
}

function findLocalPackageDependencies(package_, packagesByPath) {
  const localDependencies = new Set();

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

  return [...localDependencies].sort((left, right) =>
    left.localeCompare(right),
  );
}

function resolveLocalPackageDependency(
  package_,
  dependencyName,
  specifier,
  packagesByPath,
) {
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
