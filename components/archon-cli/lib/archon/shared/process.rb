require 'open3'
require 'fileutils'
require 'json'
require 'set'

module Archon
  module Shared
    extend self

    def run_process(command, arguments, cwd: nil, stdio: :capture)
      options = cwd ? { chdir: cwd } : {}
      if stdio == :capture
        output, error, status = Open3.capture3([command, command], *arguments, **options)
      else
        options.merge!(in: File::NULL, out: File::NULL, err: File::NULL) if stdio == :ignore
        pid = Process.spawn([command, command], *arguments, **options)
        _, status = Process.wait2(pid)
        output = error = ''
      end
      { stdout: output, stderr: error, status: status.exitstatus,
        signal: status.signaled? ? "SIG#{Signal.signame(status.termsig)}" : nil }
    rescue SystemCallError => error
      { stdout: '', stderr: '', status: nil, error: error }
    end

    def single_line(value)
      value.to_s.gsub(/\s+/, ' ').strip
    end

    def path_exists?(path)
      File.lstat(path)
      true
    rescue Errno::ENOENT
      false
    end
  end
end
