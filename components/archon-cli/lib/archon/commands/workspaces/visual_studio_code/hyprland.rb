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

    def hypr_evaluate(run, label, expression)
      output = checked_process(run, 'hyprctl', ['dispatch', expression]).strip
      raise "#{label}: #{output}" unless output == 'ok'
    end

    def hypr_dispatch(run, dispatcher, **arguments)
      fields = arguments.map { |key, value| "#{key} = #{JSON.generate(value)}" }.join(', ')
      hypr_evaluate(run, "Hyprland #{dispatcher}", "hl.dsp.#{dispatcher}({ #{fields} })")
    end

    def hypr_clients(run)
      JSON.parse(checked_process(run, 'hyprctl', %w[-j clients]))
    end

    # Omarchy's per-monitor workspace helpers are undocumented, and relying on them
    # is an accepted choice. Their source is Omarchy's
    # default/hypr/monitor-workspaces.lua. This code relies on exactly this:
    #
    # - `hyprctl dispatch` evaluates `o.workspaces.focus(slot)` and
    #   `o.workspaces.move_window(slot, false)`, and answers ok.
    # - focus goes to that slot of the focused monitor.
    # - move_window moves the active window to that slot of the focused monitor
    #   without following it. It does nothing and still answers ok when there is no
    #   active window, so the result is read back from Hyprland.
    # - Slots run from 1 to 10, so slot 10 is passed as 10, never as the key 0.
    # - Each monitor owns a block of ten global workspace numbers: 1-10, 11-20, and
    #   so on. A slot's number therefore has that slot's position in its block.
    OMARCHY_WORKSPACE_SLOTS = 10

    def omarchy_workspace_helper(run, helper, *arguments)
      hypr_evaluate(run, "Omarchy workspace helper #{helper}", "o.workspaces.#{helper}(#{arguments.join(', ')})")
    end

    def workspace_id_in_slot?(id, slot)
      id.positive? && (id - 1) % OMARCHY_WORKSPACE_SLOTS + 1 == slot
    end

    def window_workspace_id(run, address)
      hypr_clients(run).find { |client| client.fetch('address') == address }&.dig('workspace', 'id')
    end

    # The first window moved settles which workspace the slot is. Hyprland moves a
    # group as a whole, so the other windows of a group are already there.
    def move_windows_to_slot(run, addresses, slot)
      target = nil
      addresses.each do |address|
        next if target && window_workspace_id(run, address) == target

        # move_window takes the active window, and focusing a window also makes its
        # monitor the focused one.
        hypr_dispatch(run, 'focus', window: "address:#{address}")
        omarchy_workspace_helper(run, 'move_window', slot, false)
        id = window_workspace_id(run, address)
        unless id && workspace_id_in_slot?(id, slot) && (target.nil? || id == target)
          raise "Omarchy workspace helper move_window did not move VS Code window #{address} to slot #{slot}; it is on workspace #{id.inspect}."
        end

        target = id
      end
    end

    def code_window?(client)
      client.fetch('class') == 'com.microsoft.VSCode'
    end

    def stop_windows(run:, timeout: 30)
      addresses = hypr_clients(run).select { |client| code_window?(client) }
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

    def launch_projects(projects, slot, run:, timeout: 30)
      original = JSON.parse(checked_process(run, 'hyprctl', %w[-j activeworkspace])).fetch('id')
      staging = "name:archon-vsc-#{Process.pid}"
      opened = []
      restore = lambda do
        move_windows_to_slot(run, opened, slot)
        if opened.empty?
          hypr_dispatch(run, 'focus', workspace: original.to_s)
        else
          omarchy_workspace_helper(run, 'focus', slot)
        end
      end
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
              code_window?(candidate) && !before.include?(candidate.fetch('address'))
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
      rescue StandardError, Interrupt => error
        # Report a failed cleanup without hiding the error that interrupted the launch.
        begin
          restore.call
        rescue StandardError => cleanup_error
          warn "Could not restore VS Code windows: #{cleanup_error.message}"
        end
        raise error
      end
      restore.call
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
