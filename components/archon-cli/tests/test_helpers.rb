require 'fileutils'
require 'json'
require 'open3'
require 'rbconfig'
require 'stringio'
require 'tmpdir'
require_relative '../lib/archon/cli'

ARCHON = File.expand_path('../bin/archon', __dir__)
TEST_BIN = File.expand_path('bin', __dir__)
$checks = 0
$failures = 0

def assert(condition, message = 'assertion failed')
  raise message unless condition
end

def equal(expected, actual)
  assert(expected == actual, "expected #{expected.inspect}, got #{actual.inspect}")
end

def raises(pattern)
  begin
    yield
  rescue StandardError => error
    assert pattern.match?(error.message), error.message
    return
  end
  raise "expected error matching #{pattern}"
end

def capture
  previous_output, previous_error = $stdout, $stderr
  $stdout, $stderr = StringIO.new, StringIO.new
  result = yield
  [result, $stdout.string, $stderr.string]
ensure
  $stdout, $stderr = previous_output, previous_error
end

# TEST_NAME runs only tests whose names include it. Failures are reported and later tests still run.
def test(name)
  return if ENV['TEST_NAME'] && !name.include?(ENV['TEST_NAME'])
  capture do
    yield
  rescue StandardError => error
    # Keep what the test printed; it usually explains the failure.
    raise error.exception("#{error.message}\n#{captured_output($stdout.string, $stderr.string)}")
  end
  $checks += 1
  puts "PASS #{name}"
rescue StandardError => error
  $failures += 1
  warn "FAIL #{name}: #{error.message}\n#{error.backtrace.first(5).join("\n")}"
end

def captured_output(output, error)
  [['stdout', output], ['stderr', error]].filter_map do |label, text|
    "--- captured #{label} ---\n#{text.chomp}" unless text.empty?
  end.join("\n")
end

at_exit do
  next unless $!.nil?
  puts "#{$checks} checks passed"
  if $failures > 0
    warn "#{$failures} checks failed"
    exit 1
  end
end

def fixture
  Dir.mktmpdir('archon-cli-') do |root|
    home, bin = File.join(root, 'home with spaces'), File.join(root, 'bin')
    FileUtils.mkdir_p([home, bin])
    previous = ENV.to_h
    env = previous.reject { |key, _| key.start_with?('GIT_', 'HERDR_') }.merge(
      'HOME' => home, 'PATH' => "#{bin}:#{TEST_BIN}:#{previous.fetch('PATH')}",
      'XDG_CONFIG_HOME' => "#{home}/.config", 'XDG_DATA_HOME' => "#{home}/.local/share",
      'XDG_STATE_HOME' => "#{home}/.local/state",
      'TMUX' => '', 'TMUX_PANE' => '', 'GIT_CONFIG_NOSYSTEM' => '1',
      'GIT_CONFIG_SYSTEM' => '/dev/null', 'GIT_CONFIG_GLOBAL' => '/dev/null', 'GIT_TERMINAL_PROMPT' => '0',
      'GIT_CONFIG_COUNT' => '4', 'GIT_CONFIG_KEY_0' => 'core.hooksPath', 'GIT_CONFIG_VALUE_0' => '/dev/null',
      'GIT_CONFIG_KEY_1' => 'commit.gpgSign', 'GIT_CONFIG_VALUE_1' => 'false',
      'GIT_CONFIG_KEY_2' => 'user.name', 'GIT_CONFIG_VALUE_2' => 'Archon Test',
      'GIT_CONFIG_KEY_3' => 'user.email', 'GIT_CONFIG_VALUE_3' => 'test@example.com'
    )
    begin
      ENV.replace(env)
      yield({ root: root, home: home, bin: bin })
    ensure
      ENV.replace(previous)
    end
  end
end

def run_archon(arguments, env = {})
  output, error, status = Open3.capture3(env, RbConfig.ruby, ARCHON, *arguments)
  { stdout: output, stderr: error, status: status.exitstatus, signal: status.termsig }
end

def write_executable(path, content)
  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, content)
  File.chmod(0o755, path)
end

def library(fixture, name, manifest = { 'name' => "@mrzli-jslib/#{name}", 'scripts' => { 'build' => 'build-command' } }, git: true)
  directory = File.join(fixture[:home], 'projects/personal/mrzli-jslib', name)
  FileUtils.mkdir_p(git ? File.join(directory, '.git') : directory)
  File.write(File.join(directory, 'package.json'), manifest.is_a?(String) ? manifest : JSON.generate(manifest))
  directory
end

def git(directory, *arguments)
  output, error, status = Open3.capture3('git', '-C', directory, *arguments)
  assert status.success?, error
  output.strip
end

def initialize_repository(directory)
  FileUtils.mkdir_p(directory)
  git(directory, 'init', '-q', '-b', 'main')
  File.write(File.join(directory, 'tracked.txt'), "initial\n")
  git(directory, 'add', '.')
  git(directory, 'commit', '-qm', 'initial')
  { name: File.basename(directory), path: directory }
end

def fake_github(fixture)
  write_executable(File.join(fixture[:bin], 'gh'), <<~'SH')
    #!/usr/bin/env bash
    set -u
    printf '%s\n' "$*" >> "$HOME/gh-calls"
    case "$*" in
      'api --hostname github.com user --jq .login') printf '%s\n' "${TEST_USER-test-user}" ;;
      *'user/memberships/orgs?state=active&per_page=100'*) printf '%s\n' "$TEST_ORGS" ;;
      *'user/repos?affiliation=owner&visibility=all&per_page=100'*) printf '%s\n' "${TEST_USER_REPOS:-}" ;;
      *'orgs/AlphaOrg/repos?type=all&per_page=100'*) printf '%s\n' "${TEST_ORG_REPOS:-}" ;;
      *) exit 99 ;;
    esac
  SH
  ENV['TEST_ORGS'] = (Archon::Projects::ORGANIZATION_BLACKLIST + ['AlphaOrg']).join("\n")
end
