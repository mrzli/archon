from util import (
  command,
  LogLevel,
  Logger,
  LoggerConsoleHandler,
  LoggerFileHandler
)
from steps import (
  collect_inputs,
  setup_disk,
  setup_chroot_prerequisites,
  chroot_run,
  finalize_arch_installation
)

# Initialize logger.
logger = Logger([
    LoggerConsoleHandler(LogLevel.INFO),
    LoggerFileHandler(LogLevel.DEBUG, "/var/log/arch-install-py.log")
])

logger.command(["clear"])

inputs = collect_inputs(logger)
setup_disk(logger, inputs)
setup_chroot_prerequisites(logger, inputs)
chroot_run(logger, inputs)
finalize_arch_installation(logger)
