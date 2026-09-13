require_relative 'setup'

$stdout.sync = true

def main
  setup
rescue StandardError => error
  warn error.message
  exit 1
end

main
