from util import (
  command,
  LogLevel,
  Logger,
  LoggerConsoleHandler,
  LoggerFileHandler
)
from arch_install.steps import (
  get_environment,
  validate_environment,
  collect_inputs,
  setup_disk,
  setup_chroot_prerequisites,
  chroot_run,
  finalize_arch_installation
)

# Initialize logger.
logger = Logger([
    LoggerConsoleHandler(LogLevel.INFO),
    LoggerFileHandler(LogLevel.DEBUG, "/var/log/arch-install.log")
])

logger.command(["clear"])

env = get_environment(logger)
validate_environment(logger, env)

inputs = collect_inputs(logger)
setup_disk(logger, inputs)
setup_chroot_prerequisites(logger, inputs)
chroot_run(logger, env, inputs)
finalize_arch_installation(logger)
