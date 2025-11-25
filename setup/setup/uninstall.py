import os
import subprocess
from util import (
  command,
  LogLevel,
  Logger,
  LoggerConsoleHandler,
  LoggerFileHandler
)

def uninstall():
     subprocess.run('archon-uninstall-paru')