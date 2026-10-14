require 'io/console'

module Archon
  module WorkspaceProjects
    def pick_projects(projects, previous, home:, workspace: false, input: $stdin, output: $stdout)
      raise 'Start requires an interactive terminal.' unless input.tty? && output.tty?
      input.raw do
        output.write("\e[?1049h\e[?25l")
        selection = {}
        if workspace
          workspaces = (1..10).map { |number| number == 10 ? '10 (key 0)' : number.to_s }
          indices = pick_list('Choose workspace', workspaces, [], previous.fetch('workspace') - 1,
                              input, output, multiple: false)
          return nil unless indices
          selection['workspace'] = indices.first + 1
        end
        selected = projects.each_index.select { |index| previous.fetch('projects').include?(projects[index]) }
        labels = projects.map { |path| path.delete_prefix("#{home}/projects/") }
        indices = pick_list('Choose projects', labels, selected, selected.first || 0, input, output, multiple: true)
        return nil unless indices
        selection.merge('projects' => indices.map { |index| projects[index] })
      ensure
        output.write("\e[?25h\e[?1049l")
        output.flush
      end
    end

    def pick_list(title, labels, selected, cursor, input, output, multiple:)
      loop do
        rows, columns = input.winsize
        rows = 24 if rows.zero?
        columns = 80 if columns.zero?
        height = [[rows - 5, 1].max, labels.length].min
        width = [columns - 1, 20].max
        offset = [[cursor - height / 2, 0].max, labels.length - height].min
        digits = labels.length >= 10 ? '1-9 / 0: choose (0 = 10)' : "1-#{labels.length}: choose"
        controls = multiple ? 'Space: toggle' : digits
        lines = [title, "j/k or Up/Down: move | #{controls}", 'Enter: accept | Esc / Ctrl+C: cancel', '']
        labels.slice(offset, height).each_with_index do |label, index|
          position = offset + index
          mark = multiple ? (selected.include?(position) ? '[x]' : '[ ]') : (cursor == position ? '(*)' : '( )')
          lines << "#{cursor == position ? '>' : ' '} #{mark} #{label}"
        end
        lines << "#{cursor + 1}/#{labels.length}#{multiple ? " | #{selected.length} selected" : ''}"
        output.write("\e[H\e[2J#{lines.map { |line| line.gsub(/[[:cntrl:]]/, '')[0, width] }.join("\r\n")}")
        output.flush
        case key = read_key(input)
        when 'k', :up then cursor = [cursor - 1, 0].max
        when 'j', :down then cursor = [cursor + 1, labels.length - 1].min
        when ' '
          selected.include?(cursor) ? selected.delete(cursor) : selected.push(cursor) if multiple
        when "\r", "\n" then return multiple ? selected.sort : [cursor]
        when :escape, nil then return nil
        when "\u0003" then raise Interrupt
        else
          if !multiple && key.is_a?(String) && key.match?(/\A[0-9]\z/)
            position = key == '0' ? 9 : key.to_i - 1
            cursor = position if position < labels.length
          end
        end
      end
    end

    def read_key(input)
      key = input.getc
      return key unless key == "\e"
      return :escape unless IO.select([input], nil, nil, 0.05)
      prefix = input.getc
      return :escape unless ['[', 'O'].include?(prefix)
      sequence = ''
      while IO.select([input], nil, nil, 0.05)
        character = input.getc
        break unless character
        sequence << character
        break if character.match?(/[A-Za-z~]/)
      end
      { 'A' => :up, 'B' => :down }.fetch(sequence, :unknown)
    end
  end
end
