import sys
import datetime
from abc import ABC, abstractmethod
from enum import IntEnum
from .linux import command

class LogLevel(IntEnum):
    """Enumeration for log levels with numeric severity values."""
    TRACE = 100
    DEBUG = 200
    INFO = 300
    WARN = 400
    ERROR = 500

class LoggerHandlerBase(ABC):
    """Abstract base class for log handlers."""

    def __init__(self, level: int):
        self.level = level
    
    def log(self, level: int, message: str):
        if level >= self.level:
            self.log_internal(level, message)

    @abstractmethod
    def log_internal(self, level: int, message: str):
        """Internal method to be implemented by subclasses."""
        pass

class LoggerConsoleHandler(LoggerHandlerBase):
    """Handler for logging to console."""

    def __init__(self, level: int):
        super().__init__(level)
    
    def log_internal(self, level: int, message: str):
        timestamp = get_timestamp()
        formatted_message = format_message(timestamp, level, message)
        print(formatted_message, file=sys.stderr)

class LoggerFileHandler(LoggerHandlerBase):
    """Handler for logging to a file."""
    
    def __init__(self, level: int, filename: str):
        super().__init__(level)

        self.filename = filename
        self.file = open(filename, 'w')

    def __del__(self):
        if hasattr(self, 'file'):
            self.file.close()
    
    def log_internal(self, level: int, message: str):
        timestamp = get_timestamp()
        formatted_message = format_message(timestamp, level, message)
        self.file.write(formatted_message + "\n")
        self.file.flush()

class Logger:
    """Simple logger that dispatches to multiple handlers."""
    
    def __init__(self, handlers: list[LoggerHandlerBase]):
        self.handlers = handlers
    
    def log(self, level: int, message: str):
        for handler in self.handlers:
            handler.log(level, message)

    def trace(self, message: str):
        self.log(LogLevel.TRACE, message)

    def debug(self, message: str):
        self.log(LogLevel.DEBUG, message)

    def info(self, message: str):
        self.log(LogLevel.INFO, message)

    def warning(self, message: str):
        self.log(LogLevel.WARN, message)

    def error(self, message: str):
        self.log(LogLevel.ERROR, message)

    def command(
        self,
        args,
        shell=False,
        check=True,
    ):
        result = command(
            args,
            shell=shell,
            check=check,
            output='none'
        )

        result_stdout = result.stdout.splitlines()
        for line in result_stdout:
            self.debug(line)

        result_stderr = result.stderr.splitlines()
        for line in result_stderr:
            self.error(line)

        return result

def get_timestamp() -> str:
    """Get the current timestamp as a string."""
    return datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

def format_message(timestamp: str, level: int, message: str) -> str:
    """Format the log message."""
    return f"[{timestamp}] [{log_level_to_string(level):<5}] {message}"

def log_level_to_string(level: int) -> str:
    """Convert log level integer to string."""
    match level:
        case LogLevel.TRACE:
            return "TRACE"
        case LogLevel.DEBUG:
            return "DEBUG"
        case LogLevel.INFO:
            return "INFO"
        case LogLevel.WARN:
            return "WARN"
        case LogLevel.ERROR:
            return "ERROR"
        case _:
            return level.__str__()

# Example usage:
# logger = Logger([ConsoleHandler(), FileHandler("app.log")])
# logger.info("This is an info message.")
# logger.error("This is an error message.")