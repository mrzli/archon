require 'rbconfig'
require 'shellwords'
require 'tmpdir'

repo_root = File.expand_path('..', __dir__)
status = nil

Dir.mktmpdir('archon-profile-') do |directory|
  timings = File.join(directory, 'timings.tsv')
  File.write(timings, '')
  { 'ruby' => RbConfig.ruby, 'bash' => '/bin/bash' }.each do |name, executable|
    wrapper = File.join(directory, name)
    File.write(wrapper, <<~BASH)
      #!/bin/bash
      case "${1:-}" in
        #{Shellwords.escape(repo_root)}/*_test.rb|#{Shellwords.escape(repo_root)}/*.sh)
          started=$EPOCHREALTIME
          #{Shellwords.escape(executable)} "$@"
          result=$?
          printf '%s\\t%s\\t%s\\t%s\\n' "$started" "$EPOCHREALTIME" "$result" "$1" >> #{Shellwords.escape(timings)}
          exit "$result"
          ;;
        *) exec #{Shellwords.escape(executable)} "$@" ;;
      esac
    BASH
    File.chmod(0o755, wrapper)
  end

  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  system({ 'PATH' => "#{directory}:#{ENV.fetch('PATH')}" }, '/bin/bash', File.join(__dir__, 'test.sh'))
  status = $?
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

  puts "\nTest timings (runner totals include their child tests):"
  rows = File.readlines(timings).map do |line|
    first, last, code, path = line.chomp.split("\t", 4)
    [last.to_f - first.to_f, code, path.delete_prefix("#{repo_root}/")]
  end
  rows.sort_by { |duration, _, _| -duration }.each do |duration, code, path|
    puts format('%7.2fs  exit=%s  %s', duration, code, path)
  end
  puts format('Total: %.2fs (%s)', elapsed, status.success? ? 'passed' : 'FAILED')
end

exit(status.exitstatus || 128 + status.termsig)
