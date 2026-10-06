require_relative 'test_helpers'

Libraries = Archon::Libraries

test('library graph discovers immediate repositories and all dependency fields') do
  fixture do |fixture|
    manifest = { 'name' => '@mrzli-jslib/app' }
    Libraries::DEPENDENCY_FIELDS.each_with_index do |field, index|
      library(fixture, "dep-#{index}")
      manifest[field] = { "@mrzli-jslib/dep-#{index}" => "file:../dep-#{index}" }
    end
    library(fixture, 'app', manifest)
    library(fixture, '.hidden', { name: '@mrzli-jslib/hidden' })
    library(fixture, 'ignored', { name: '@mrzli-jslib/ignored' }, git: false)
    library(fixture, 'ignored/nested', { name: '@mrzli-jslib/nested' })
    result = run_archon(%w[projects libs graph])
    equal 0, result[:status]
    assert result[:stdout].include?("@mrzli-jslib/hidden\n")
    4.times { |index| assert result[:stdout].include?("  -> @mrzli-jslib/dep-#{index}\n") }
    assert !result[:stdout].match?(/ignored|nested/)
  end
end

invalid_manifests = [
  ['{ invalid', /could not be read/],
  [{ name: 'unscoped' }, /must have a name/],
  [{ name: '@mrzli-jslib/app', dependencies: [] }, /invalid dependencies field/],
  [{ name: '@mrzli-jslib/app', dependencies: { '@mrzli-jslib/dep' => 'workspace:*' } }, /file: protocol/],
  [{ name: '@mrzli-jslib/app', dependencies: { '@mrzli-jslib/dep' => 'file:' } }, /empty path/],
  [{ name: '@mrzli-jslib/app', dependencies: { '@mrzli-jslib/dep' => 'file:../missing' } }, /path could not be resolved/]
]
invalid_manifests.each_with_index do |(manifest, pattern), index|
  test("dependency graph rejects invalid manifest #{index + 1}") do
    fixture do |fixture|
      directory = library(fixture, 'app', manifest)
      raises(pattern) { Libraries.dependency_graph([{ name: 'app', path: directory }]) }
    end
  end
end

test('dependencies require a local repository with the declared name and reject duplicates') do
  fixture do |fixture|
    dep = library(fixture, 'dep', { name: '@mrzli-jslib/other' }, git: false)
    app = library(fixture, 'app', { name: '@mrzli-jslib/app', dependencies: { '@mrzli-jslib/dep' => 'file:../dep' } })
    repositories = [{ name: 'app', path: app }]
    raises(/directory is not a local repository/) { Libraries.dependency_graph(repositories) }
    repositories << { name: 'dep', path: dep }
    raises(/but that package is named @mrzli-jslib\/other/) { Libraries.dependency_graph(repositories) }
    File.write(File.join(dep, 'package.json'), JSON.generate(name: '@mrzli-jslib/app'))
    raises(/duplicate package name "@mrzli-jslib\/app"/) { Libraries.dependency_graph(repositories) }
  end
end

test('canonical dependency paths are deduplicated and dependencies build first') do
  fixture do |fixture|
    dep = library(fixture, 'dep')
    File.symlink(dep, File.join(File.dirname(dep), 'alias'))
    app = library(fixture, 'app', { name: '@mrzli-jslib/app', scripts: { build: 'build' },
      dependencies: { '@mrzli-jslib/dep' => 'file:../alias' }, peerDependencies: { '@mrzli-jslib/dep' => 'file:../dep' } })
    graph = Libraries.dependency_graph([{ name: 'app', path: app }, { name: 'dep', path: dep }])
    equal ['@mrzli-jslib/dep'], graph.first[:dependencies]
    equal %w[@mrzli-jslib/dep @mrzli-jslib/app], Libraries.order_packages(graph).map { |node| node[:name] }
  end
end

test('cycles report the entire dependency cycle') do
  graph = [{ name: 'alpha', dependencies: ['beta'] }, { name: 'beta', dependencies: ['alpha'] }]
  raises(/dependency cycle detected: alpha -> beta -> alpha/) { Libraries.order_packages(graph) }
end

test('build scripts must be nonempty strings before any package command executes') do
  [nil, [], {}, { 'build' => '' }, { 'build' => 1 }].each do |scripts|
    raises(/must define a non-empty build script/) do
      Libraries.validate_build_scripts([{ name: 'invalid', manifest: { 'scripts' => scripts } }])
    end
  end
  Libraries.validate_build_scripts([{ name: 'valid', manifest: { 'scripts' => { 'build' => 'build' } } }])
end

[nil, 'install --frozen-lockfile --ignore-scripts', 'run build'].each do |failure|
  test("library builds use frozen installs, one build per package, and stop on #{failure || 'no failure'}") do
    fixture do |fixture|
      library(fixture, 'alpha', { name: '@mrzli-jslib/alpha', scripts: { build: 'build' }, dependencies: { '@mrzli-jslib/zeta' => 'file:../zeta' } })
      library(fixture, 'zeta')
      write_executable(File.join(fixture[:bin], 'bun'), <<~'SH')
        #!/bin/sh
        printf '%s\t%s\n' "$PWD" "$*" >> "$HOME/bun-calls"
        [ "${TEST_BUN_FAIL:-}" != "$*" ] || exit 7
      SH
      result = run_archon(%w[projects libs build], 'TEST_BUN_FAIL' => failure)
      equal failure ? 1 : 0, result[:status]
      calls = File.readlines(File.join(fixture[:home], 'bun-calls'), chomp: true)
      root = File.join(fixture[:home], 'projects/personal/mrzli-jslib')
      expected = %w[zeta alpha].flat_map do |name|
        ["#{root}/#{name}\tinstall --frozen-lockfile --ignore-scripts", "#{root}/#{name}\trun build"]
      end
      expected = expected.take(failure.start_with?('install') ? 1 : 2) if failure
      equal expected, calls
      if failure
        assert result[:stderr].include?('Bun exited with status 7')
      else
        equal "[1/2] @mrzli-jslib/zeta\n[2/2] @mrzli-jslib/alpha\nBuilt 2 packages.\n", result[:stdout]
      end
    end
  end
end
