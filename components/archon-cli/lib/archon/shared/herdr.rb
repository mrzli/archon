require 'json'
require_relative 'process'

module Archon
  module Herdr
    extend self

    # Sends one request to a Herdr session. capture returns { status:, output: }.
    # Returns the response's result object, or nil for pane run, which prints no JSON.
    def request(session, arguments, capture)
      result = capture.call('herdr', ['--session', session, *arguments])
      raise "Herdr #{arguments.first(2).join(' ')} failed: #{result[:output]}" unless result[:status] == 0
      return nil if arguments.first(2) == %w[pane run]
      response = JSON.parse(result[:output])
      raise 'Herdr returned a non-object response.' unless response.is_a?(Hash)
      raise "Herdr: #{response.fetch('error')}" if response.key?('error')
      response.fetch('result', response)
    rescue JSON::ParserError => error
      raise "Could not read Herdr #{arguments.first(2).join(' ')} output: #{error.message}"
    end

    # Whether a pane process-info result shows its shell idle at a prompt.
    def idle_shell?(info)
      shell_pid = info['shell_pid']
      return false unless shell_pid && info['foreground_process_group_id'] == shell_pid
      shell = info.fetch('foreground_processes', []).find { |process| process['pid'] == shell_pid }
      !shell.nil? && shell['name'] == Shared::PANE_SHELL
    end
  end
end
