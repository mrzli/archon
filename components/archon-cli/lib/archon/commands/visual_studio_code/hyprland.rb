module Archon
  module VisualStudioCode
    def checked_process(run, command, arguments)
      result = run.call(command, arguments)
      raise result[:error] if result[:error]
      if result[:signal] || result[:status] != 0
        detail = Shared.single_line([result[:stderr], result[:stdout]].compact.reject(&:empty?).join("\n"))
        raise "#{command} #{arguments.join(' ')} failed (#{result[:signal] || result[:status]}): #{detail}"
      end
      result.fetch(:stdout)
    end

    def hypr_dispatch(run, dispatcher, **arguments)
      fields = arguments.map { |key, value| "#{key} = #{JSON.generate(value)}" }.join(', ')
      expression = "hl.dsp.#{dispatcher}({ #{fields} })"
      output = checked_process(run, 'hyprctl', ['dispatch', expression]).strip
      raise "Hyprland #{dispatcher}: #{output}" unless output == 'ok'
    end

    def hypr_clients(run)
      JSON.parse(checked_process(run, 'hyprctl', %w[-j clients]))
    end

    def stop_windows(run:, timeout: 30)
      addresses = hypr_clients(run).select { |client| client.fetch('class').downcase == 'code' }
                                  .map { |client| client.fetch('address') }
      return 0 if addresses.empty?

      addresses.each { |address| hypr_dispatch(run, 'window.close', window: "address:#{address}") }
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
      loop do
        remaining = hypr_clients(run).count { |client| addresses.include?(client.fetch('address')) }
        return addresses.length if remaining.zero?
        if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
          raise 'VS Code did not finish closing. Check for a shutdown confirmation or an unresponsive window.'
        end
        sleep 0.1
      end
    end

    def launch_projects(projects, workspace, run:, timeout: 30)
      original = JSON.parse(checked_process(run, 'hyprctl', %w[-j activeworkspace])).fetch('id')
      staging = "name:archon-vsc-#{Process.pid}"
      opened = []
      begin
        projects.each do |project|
          before = hypr_clients(run).map { |client| client.fetch('address') }
          hypr_dispatch(run, 'focus', workspace: staging)
          hypr_dispatch(run, 'focus', window: "address:#{opened.last}") unless opened.empty?
          checked_process(run, 'code', ['--new-window', project])
          deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
          loop do
            clients = hypr_clients(run)
            client = clients.find do |candidate|
              candidate.fetch('class').downcase == 'code' && !before.include?(candidate.fetch('address'))
            end
            if client
              opened << client.fetch('address')
              hypr_dispatch(run, 'window.move', workspace: staging, window: "address:#{opened.last}", follow: false)
              hypr_dispatch(run, 'window.float', window: "address:#{opened.last}", action: 'disable')
              group_window(run, opened)
              break
            end
            raise "Timed out waiting for VS Code: #{project}" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
            sleep 0.1
          end
        end
      ensure
        opened.each do |address|
          hypr_dispatch(run, 'window.move', workspace: workspace.to_s, window: "address:#{address}", follow: false)
        end
        hypr_dispatch(run, 'focus', workspace: opened.empty? ? original.to_s : workspace.to_s)
      end
      hypr_dispatch(run, 'focus', window: "address:#{opened.first}")
    end

    def group_window(run, opened)
      hypr_dispatch(run, 'focus', window: "address:#{opened.last}")
      clients = hypr_clients(run)
      client = clients.find { |window| window['address'] == opened.last }
      if opened.length == 1
        hypr_dispatch(run, 'group.toggle', window: "address:#{opened.last}") if client.fetch('grouped').empty?
      elsif !client.fetch('grouped').include?(opened.first)
        target = clients.find { |window| window['address'] == opened.first }
        dx, dy = target.fetch('at').zip(client.fetch('at')).map { |a, b| a - b }
        direction = dx.abs >= dy.abs ? (dx < 0 ? 'l' : 'r') : (dy < 0 ? 'u' : 'd')
        hypr_dispatch(run, 'window.move', into_group: direction, window: "address:#{opened.last}")
      end
      grouped = hypr_clients(run).find { |window| window['address'] == opened.first }.fetch('grouped')
      raise 'Hyprland could not group the selected VS Code windows in order. Check group locks and window rules.' unless grouped == opened
    end
  end
end
