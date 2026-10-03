module Archon
  module VisualStudioCode
    def checked_process(run, command, arguments)
      result = run.call(command, arguments)
      raise result[:error] if result[:error]
      if result[:signal] || result[:status] != 0
        raise "#{command} failed: #{Shared.single_line(result[:stderr])} (#{result[:signal] || result[:status]})"
      end
      result.fetch(:stdout)
    end

    def hypr_dispatch(run, dispatcher, argument = '')
      output = checked_process(run, 'hyprctl', ['dispatch', dispatcher, argument]).strip
      raise "Hyprland #{dispatcher}: #{output}" unless output == 'ok'
    end

    def hypr_clients(run)
      JSON.parse(checked_process(run, 'hyprctl', %w[-j clients]))
    end

    def launch_projects(projects, workspace, run:, timeout: 30)
      original = JSON.parse(checked_process(run, 'hyprctl', %w[-j activeworkspace])).fetch('id')
      staging = "name:archon-vsc-#{Process.pid}"
      opened = []
      begin
        projects.each do |project|
          before = hypr_clients(run).map { |client| client.fetch('address') }
          hypr_dispatch(run, 'workspace', staging)
          hypr_dispatch(run, 'focuswindow', "address:#{opened.last}") unless opened.empty?
          checked_process(run, 'code', ['--new-window', project])
          deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
          loop do
            clients = hypr_clients(run)
            client = clients.find do |candidate|
              candidate.fetch('class').downcase == 'code' && !before.include?(candidate.fetch('address'))
            end
            if client
              opened << client.fetch('address')
              hypr_dispatch(run, 'movetoworkspacesilent', "#{staging},address:#{opened.last}")
              hypr_dispatch(run, 'settiled', "address:#{opened.last}")
              group_window(run, opened)
              break
            end
            raise "Timed out waiting for VS Code: #{project}" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
            sleep 0.1
          end
        end
      ensure
        opened.each do |address|
          hypr_dispatch(run, 'movetoworkspacesilent', "#{workspace},address:#{address}")
        end
        hypr_dispatch(run, 'workspace', opened.empty? ? original.to_s : workspace.to_s)
      end
      hypr_dispatch(run, 'focuswindow', "address:#{opened.first}")
    end

    def group_window(run, opened)
      hypr_dispatch(run, 'focuswindow', "address:#{opened.last}")
      clients = hypr_clients(run)
      client = clients.find { |window| window['address'] == opened.last }
      if opened.length == 1
        hypr_dispatch(run, 'togglegroup') if client.fetch('grouped').empty?
      elsif !client.fetch('grouped').include?(opened.first)
        target = clients.find { |window| window['address'] == opened.first }
        dx, dy = target.fetch('at').zip(client.fetch('at')).map { |a, b| a - b }
        direction = dx.abs >= dy.abs ? (dx < 0 ? 'l' : 'r') : (dy < 0 ? 'u' : 'd')
        hypr_dispatch(run, 'moveintogroup', direction)
      end
      grouped = hypr_clients(run).find { |window| window['address'] == opened.first }.fetch('grouped')
      raise 'Hyprland could not group the selected VS Code windows in order. Check group locks and window rules.' unless grouped == opened
    end
  end
end
