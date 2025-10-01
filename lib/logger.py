#!/usr/bin/env python3
"""
Comprehensive logging system for the Topdesk-Zabbix merger tool.
Provides structured logging with levels, rotation, and analysis capabilities.
"""

import os
import sys
import json
import time
import logging
import traceback
import threading
import subprocess
import shlex
import re
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, Any, Optional, List, Tuple, Union
from logging.handlers import RotatingFileHandler
from collections import defaultdict, Counter
import inspect


class MergerLogger:
    """Main logger class for the merger tool with advanced features."""

    # Log level constants
    TRACE = 5
    DEBUG = logging.DEBUG
    INFO = logging.INFO
    WARNING = logging.WARNING
    ERROR = logging.ERROR
    CRITICAL = logging.CRITICAL
    COMMAND = 25  # New level for CLI command logging

    def __init__(
        self,
        output_dir: str = "./output",
        log_filename: str = "merger.log",
        command_log_filename: str = "command.log",
        max_bytes: int = 10 * 1024 * 1024,  # 10MB
        backup_count: int = 5,
        log_level: int = INFO,
        console_output: bool = True,
        json_format: bool = False
    ):
        """
        Initialize the merger logger.

        Args:
            output_dir: Directory to store log files
            log_filename: Name of the log file
            command_log_filename: Name of the command audit log file
            max_bytes: Maximum size before rotation
            backup_count: Number of backup files to keep
            log_level: Minimum log level to record
            console_output: Whether to mirror logs to console
            json_format: Whether to use JSON formatting
        """
        self.output_dir = Path(output_dir)
        self.log_filename = log_filename
        self.command_log_filename = command_log_filename
        self.max_bytes = max_bytes
        self.backup_count = backup_count
        self.log_level = log_level
        self.console_output = console_output
        self.json_format = json_format

        # Statistics tracking
        self.stats = {
            'total_messages': 0,
            'by_level': Counter(),
            'by_agent': Counter(),
            'errors': [],
            'commands': []  # Track CLI commands
        }
        self.stats_lock = threading.Lock()

        # Command statistics
        self.command_stats = {
            'total_commands': 0,
            'successful': 0,
            'failed': 0,
            'by_tool': Counter(),  # zbx, topdesk, etc.
            'by_operation': Counter(),  # get-asset, update-asset, etc.
            'total_duration': 0.0,
            'errors_by_type': Counter()
        }
        self.command_stats_lock = threading.Lock()

        # Create output directory if it doesn't exist
        self.output_dir.mkdir(parents=True, exist_ok=True)

        # Setup logging
        self._setup_logger()
        self._setup_command_logger()

        # Add custom log levels
        logging.addLevelName(self.TRACE, "TRACE")
        logging.addLevelName(self.COMMAND, "COMMAND")

        # Log initial startup
        self.info("SYSTEM", "Merger logger initialized")

    def _setup_logger(self):
        """Configure the logger with handlers and formatters."""
        self.logger = logging.getLogger('merger')
        self.logger.setLevel(self.TRACE)

        # Clear any existing handlers
        self.logger.handlers = []

        # File handler with rotation
        log_path = self.output_dir / self.log_filename
        file_handler = RotatingFileHandler(
            log_path,
            maxBytes=self.max_bytes,
            backupCount=self.backup_count
        )
        file_handler.setLevel(self.log_level)

        # Set formatter based on preference
        if self.json_format:
            file_handler.setFormatter(JsonFormatter())
        else:
            formatter = logging.Formatter(
                '[%(asctime)s.%(msecs)03d] [%(levelname)s] [%(agent)s] %(message)s',
                datefmt='%Y-%m-%d %H:%M:%S'
            )
            file_handler.setFormatter(formatter)

        self.logger.addHandler(file_handler)

        # Console handler if requested
        if self.console_output:
            console_handler = logging.StreamHandler(sys.stdout)
            console_handler.setLevel(self.log_level)

            if self.json_format:
                console_handler.setFormatter(JsonFormatter())
            else:
                console_formatter = logging.Formatter(
                    '%(levelname)-8s [%(agent)s] %(message)s'
                )
                console_handler.setFormatter(console_formatter)

            self.logger.addHandler(console_handler)

    def _setup_command_logger(self):
        """Setup dedicated logger for command audit trail."""
        self.command_logger = logging.getLogger('merger.commands')
        self.command_logger.setLevel(logging.DEBUG)

        # Clear any existing handlers
        self.command_logger.handlers = []

        # Command log file handler
        command_log_path = self.output_dir / self.command_log_filename
        command_handler = RotatingFileHandler(
            command_log_path,
            maxBytes=self.max_bytes,
            backupCount=self.backup_count
        )
        command_handler.setLevel(logging.DEBUG)

        # Always use JSON format for command logs
        command_handler.setFormatter(CommandJsonFormatter())
        self.command_logger.addHandler(command_handler)

    def _log(self, level: int, agent: str, message: str, **kwargs):
        """
        Internal logging method with context enrichment.

        Args:
            level: Log level
            agent: Name of the agent/component logging
            message: Log message
            **kwargs: Additional context data
        """
        # Get caller info
        frame = inspect.currentframe()
        if frame and frame.f_back and frame.f_back.f_back:
            caller_frame = frame.f_back.f_back
            caller_file = os.path.basename(caller_frame.f_code.co_filename)
            caller_func = caller_frame.f_code.co_name
            caller_line = caller_frame.f_lineno
        else:
            caller_file = "unknown"
            caller_func = "unknown"
            caller_line = 0

        # Create log record with extra context
        extra = {
            'agent': agent.upper(),
            'caller_file': caller_file,
            'caller_func': caller_func,
            'caller_line': caller_line,
            **kwargs
        }

        # Update statistics
        with self.stats_lock:
            self.stats['total_messages'] += 1
            self.stats['by_level'][logging.getLevelName(level)] += 1
            self.stats['by_agent'][agent.upper()] += 1

            if level >= self.ERROR:
                self.stats['errors'].append({
                    'timestamp': datetime.now().isoformat(),
                    'agent': agent,
                    'message': message,
                    'level': logging.getLevelName(level)
                })

        # Log the message
        self.logger.log(level, message, extra=extra)

    def trace(self, agent: str, message: str, **kwargs):
        """Log a TRACE level message for detailed execution flow."""
        self._log(self.TRACE, agent, message, **kwargs)

    def debug(self, agent: str, message: str, **kwargs):
        """Log a DEBUG level message."""
        self._log(self.DEBUG, agent, message, **kwargs)

    def info(self, agent: str, message: str, **kwargs):
        """Log an INFO level message."""
        self._log(self.INFO, agent, message, **kwargs)

    def warning(self, agent: str, message: str, **kwargs):
        """Log a WARNING level message."""
        self._log(self.WARNING, agent, message, **kwargs)

    def error(self, agent: str, message: str, exception: Optional[Exception] = None, **kwargs):
        """
        Log an ERROR level message with optional exception details.

        Args:
            agent: Name of the agent/component
            message: Error message
            exception: Optional exception object to log
            **kwargs: Additional context
        """
        if exception:
            kwargs['exception_type'] = type(exception).__name__
            kwargs['exception_message'] = str(exception)
            kwargs['traceback'] = traceback.format_exc()
            message = f"{message}: {exception}"

        self._log(self.ERROR, agent, message, **kwargs)

    def critical(self, agent: str, message: str, exception: Optional[Exception] = None, **kwargs):
        """Log a CRITICAL level message."""
        if exception:
            kwargs['exception_type'] = type(exception).__name__
            kwargs['exception_message'] = str(exception)
            kwargs['traceback'] = traceback.format_exc()
            message = f"{message}: {exception}"

        self._log(self.CRITICAL, agent, message, **kwargs)

    def log_operation(self, agent: str, operation: str, start_time: float = None, **kwargs):
        """
        Log an operation with timing information.

        Args:
            agent: Name of the agent/component
            operation: Description of the operation
            start_time: Start time from time.time()
            **kwargs: Additional context
        """
        if start_time:
            duration = time.time() - start_time
            kwargs['duration_seconds'] = round(duration, 3)
            message = f"{operation} completed in {duration:.3f}s"
        else:
            message = f"{operation} started"

        self.info(agent, message, **kwargs)

    def log_batch_operation(self, agent: str, operation: str, total: int,
                           processed: int, failed: int = 0, **kwargs):
        """
        Log batch processing results.

        Args:
            agent: Name of the agent/component
            operation: Description of the batch operation
            total: Total items to process
            processed: Successfully processed items
            failed: Failed items
            **kwargs: Additional context
        """
        success_rate = (processed / total * 100) if total > 0 else 0
        message = (f"{operation}: {processed}/{total} processed "
                  f"({success_rate:.1f}% success)")

        if failed > 0:
            message += f", {failed} failed"
            kwargs['failed_count'] = failed

        kwargs.update({
            'total_items': total,
            'processed_items': processed,
            'success_rate': success_rate
        })

        level = self.WARNING if failed > 0 else self.INFO
        self._log(level, agent, message, **kwargs)

    def get_statistics(self) -> Dict[str, Any]:
        """Get current logging statistics."""
        with self.stats_lock:
            return {
                'total_messages': self.stats['total_messages'],
                'by_level': dict(self.stats['by_level']),
                'by_agent': dict(self.stats['by_agent']),
                'recent_errors': self.stats['errors'][-10:]  # Last 10 errors
            }

    def print_statistics(self):
        """Print a formatted statistics summary."""
        stats = self.get_statistics()

        print("\n" + "=" * 50)
        print("LOGGING STATISTICS")
        print("=" * 50)
        print(f"Total Messages: {stats['total_messages']}")

        print("\nBy Level:")
        for level, count in sorted(stats['by_level'].items()):
            print(f"  {level:8s}: {count:5d}")

        print("\nBy Agent:")
        for agent, count in sorted(stats['by_agent'].items()):
            print(f"  {agent:15s}: {count:5d}")

        if stats['recent_errors']:
            print("\nRecent Errors:")
            for error in stats['recent_errors']:
                print(f"  [{error['timestamp']}] {error['agent']}: {error['message']}")

        print("=" * 50 + "\n")

    def clear_statistics(self):
        """Clear accumulated statistics."""
        with self.stats_lock:
            self.stats = {
                'total_messages': 0,
                'by_level': Counter(),
                'by_agent': Counter(),
                'errors': []
            }

    def set_level(self, level: int):
        """Change the logging level dynamically."""
        self.log_level = level
        for handler in self.logger.handlers:
            handler.setLevel(level)

        self.info("SYSTEM", f"Log level changed to {logging.getLevelName(level)}")

    def log_command(self, command: Union[str, List[str]], agent: str = "CLI",
                   stdout: Optional[str] = None, stderr: Optional[str] = None,
                   exit_code: Optional[int] = None, duration: Optional[float] = None,
                   error: Optional[Exception] = None):
        """
        Log CLI command execution with detailed information.

        Args:
            command: Command as string or list of arguments
            agent: Name of the agent executing command
            stdout: Standard output from command
            stderr: Standard error from command
            exit_code: Exit code from command
            duration: Execution time in seconds
            error: Exception if command failed
        """
        # Convert command to string if needed
        if isinstance(command, list):
            command_str = shlex.join(command)
        else:
            command_str = command

        # Mask sensitive data
        masked_command = self._mask_sensitive_data(command_str)

        # Parse command for tool and operation
        tool, operation = self._parse_command(command_str)

        # Update command statistics
        with self.command_stats_lock:
            self.command_stats['total_commands'] += 1
            self.command_stats['by_tool'][tool] += 1
            self.command_stats['by_operation'][operation] += 1

            if exit_code == 0:
                self.command_stats['successful'] += 1
            else:
                self.command_stats['failed'] += 1

            if duration:
                self.command_stats['total_duration'] += duration

            if error:
                error_type = type(error).__name__
                self.command_stats['errors_by_type'][error_type] += 1

        # Create command log entry
        command_entry = {
            'timestamp': datetime.now().isoformat(),
            'agent': agent,
            'command': masked_command,
            'tool': tool,
            'operation': operation,
            'exit_code': exit_code,
            'duration': round(duration, 3) if duration else None,
            'success': exit_code == 0 if exit_code is not None else None
        }

        # Add output if present (truncate if too long)
        if stdout:
            command_entry['stdout'] = stdout[:5000] if len(stdout) > 5000 else stdout
        if stderr:
            command_entry['stderr'] = stderr[:5000] if len(stderr) > 5000 else stderr
        if error:
            command_entry['error'] = str(error)
            command_entry['error_type'] = type(error).__name__

        # Log to command logger
        self.command_logger.info('', extra=command_entry)

        # Also log to main logger at COMMAND level
        level = self.COMMAND
        if exit_code != 0:
            level = self.ERROR

        message = f"Command executed: {masked_command}"
        if duration:
            message += f" (took {duration:.3f}s)"
        if exit_code is not None:
            message += f" [exit: {exit_code}]"

        # Remove 'agent' from command_entry to avoid conflict
        log_extra = {k: v for k, v in command_entry.items() if k != 'agent'}
        self._log(level, agent, message, **log_extra)

        # Track in stats
        with self.stats_lock:
            self.stats['commands'].append(command_entry)
            # Keep only last 100 commands in memory
            if len(self.stats['commands']) > 100:
                self.stats['commands'] = self.stats['commands'][-100:]

    def _mask_sensitive_data(self, command: str) -> str:
        """Mask sensitive data in commands (passwords, tokens, etc.)."""
        # Patterns to mask
        patterns = [
            (r'--password[= ][\S]+', '--password=***'),
            (r'--token[= ][\S]+', '--token=***'),
            (r'--api-key[= ][\S]+', '--api-key=***'),
            (r'--secret[= ][\S]+', '--secret=***'),
            (r'password=[\S]+', 'password=***'),
            (r'token=[\S]+', 'token=***'),
            (r'Bearer [\S]+', 'Bearer ***'),
        ]

        masked = command
        for pattern, replacement in patterns:
            masked = re.sub(pattern, replacement, masked, flags=re.IGNORECASE)

        return masked

    def _parse_command(self, command: str) -> Tuple[str, str]:
        """Parse command to extract tool and operation."""
        # Try to identify the tool (zbx, topdesk, etc.)
        tool = "unknown"
        operation = "unknown"

        parts = shlex.split(command)
        if parts:
            # First part is usually the tool
            tool_part = parts[0].lower()
            if 'zbx' in tool_part or 'zabbix' in tool_part:
                tool = 'zabbix'
            elif 'topdesk' in tool_part:
                tool = 'topdesk'
            elif 'git' in tool_part:
                tool = 'git'
            else:
                tool = os.path.basename(tool_part)

            # Try to find operation (usually second part or after flag)
            if len(parts) > 1:
                for i, part in enumerate(parts[1:]):
                    if not part.startswith('-'):
                        operation = part
                        break

        return tool, operation

    def execute_command(self, command: Union[str, List[str]], agent: str = "CLI",
                       timeout: Optional[int] = 30, cwd: Optional[str] = None,
                       env: Optional[Dict] = None, shell: bool = False) -> Dict[str, Any]:
        """
        Execute a command and log its execution details.

        Args:
            command: Command to execute
            agent: Agent executing the command
            timeout: Command timeout in seconds
            cwd: Working directory
            env: Environment variables
            shell: Whether to use shell execution

        Returns:
            Dictionary with command results
        """
        start_time = time.time()
        result = {
            'command': command,
            'success': False,
            'exit_code': None,
            'stdout': '',
            'stderr': '',
            'duration': 0.0,
            'error': None
        }

        try:
            # Execute command
            if isinstance(command, str) and not shell:
                command = shlex.split(command)

            proc = subprocess.run(
                command,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=timeout,
                cwd=cwd,
                env=env,
                shell=shell,
                text=True
            )

            duration = time.time() - start_time

            result.update({
                'success': proc.returncode == 0,
                'exit_code': proc.returncode,
                'stdout': proc.stdout,
                'stderr': proc.stderr,
                'duration': duration
            })

            # Log the command
            self.log_command(
                command=command,
                agent=agent,
                stdout=proc.stdout,
                stderr=proc.stderr,
                exit_code=proc.returncode,
                duration=duration
            )

        except subprocess.TimeoutExpired as e:
            duration = time.time() - start_time
            result.update({
                'error': f"Command timed out after {timeout}s",
                'duration': duration
            })
            self.log_command(
                command=command,
                agent=agent,
                exit_code=-1,
                duration=duration,
                error=e
            )

        except Exception as e:
            duration = time.time() - start_time
            result.update({
                'error': str(e),
                'duration': duration
            })
            self.log_command(
                command=command,
                agent=agent,
                exit_code=-1,
                duration=duration,
                error=e
            )

        return result

    def replay_commands(self, filter_tool: Optional[str] = None,
                       filter_success: Optional[bool] = None,
                       last_n: Optional[int] = None) -> List[Dict[str, Any]]:
        """
        Get commands from log for replay or analysis.

        Args:
            filter_tool: Filter by tool (zbx, topdesk, etc.)
            filter_success: Filter by success status
            last_n: Get only last N commands

        Returns:
            List of command entries
        """
        commands = []
        command_log_path = self.output_dir / self.command_log_filename

        if not command_log_path.exists():
            return commands

        with open(command_log_path, 'r') as f:
            for line in f:
                try:
                    entry = json.loads(line.strip())

                    # Apply filters
                    if filter_tool and entry.get('tool') != filter_tool:
                        continue
                    if filter_success is not None and entry.get('success') != filter_success:
                        continue

                    commands.append(entry)
                except json.JSONDecodeError:
                    continue

        if last_n:
            return commands[-last_n:]
        return commands

    def get_failed_commands(self, last_n: Optional[int] = 10) -> List[Dict[str, Any]]:
        """
        Get failed commands for debugging.

        Args:
            last_n: Number of recent failed commands to retrieve

        Returns:
            List of failed command entries
        """
        return self.replay_commands(filter_success=False, last_n=last_n)

    def get_command_statistics(self) -> Dict[str, Any]:
        """Get CLI command execution statistics."""
        with self.command_stats_lock:
            stats = self.command_stats.copy()

            # Calculate averages
            if stats['total_commands'] > 0:
                stats['success_rate'] = (stats['successful'] / stats['total_commands']) * 100
                stats['average_duration'] = stats['total_duration'] / stats['total_commands']
            else:
                stats['success_rate'] = 0.0
                stats['average_duration'] = 0.0

            # Convert Counters to dicts
            stats['by_tool'] = dict(stats['by_tool'])
            stats['by_operation'] = dict(stats['by_operation'])
            stats['errors_by_type'] = dict(stats['errors_by_type'])

            return stats

    def print_command_statistics(self):
        """Print formatted command execution statistics."""
        stats = self.get_command_statistics()

        print("\n" + "=" * 50)
        print("CLI COMMAND STATISTICS")
        print("=" * 50)
        print(f"Total Commands: {stats['total_commands']}")
        print(f"Successful: {stats['successful']} ({stats['success_rate']:.1f}%)")
        print(f"Failed: {stats['failed']}")
        print(f"Average Duration: {stats['average_duration']:.3f}s")

        if stats['by_tool']:
            print("\nBy Tool:")
            for tool, count in sorted(stats['by_tool'].items()):
                print(f"  {tool:15s}: {count:5d}")

        if stats['by_operation']:
            print("\nBy Operation:")
            for op, count in sorted(stats['by_operation'].items())[:10]:
                print(f"  {op:20s}: {count:5d}")

        if stats['errors_by_type']:
            print("\nErrors by Type:")
            for error_type, count in sorted(stats['errors_by_type'].items()):
                print(f"  {error_type:20s}: {count:5d}")

        print("=" * 50 + "\n")


class JsonFormatter(logging.Formatter):
    """Custom JSON formatter for structured logging."""

    def format(self, record):
        """Format log record as JSON."""
        log_obj = {
            'timestamp': datetime.fromtimestamp(record.created).isoformat(),
            'level': record.levelname,
            'agent': getattr(record, 'agent', 'UNKNOWN'),
            'message': record.getMessage(),
            'filename': getattr(record, 'caller_file', record.filename),
            'function': getattr(record, 'caller_func', record.funcName),
            'line_number': getattr(record, 'caller_line', record.lineno)
        }

        # Add any extra fields
        for key, value in record.__dict__.items():
            if key not in ['name', 'msg', 'args', 'created', 'filename',
                          'funcName', 'levelname', 'levelno', 'lineno', 'module',
                          'msecs', 'message', 'pathname', 'process', 'processName',
                          'relativeCreated', 'thread', 'threadName', 'agent',
                          'caller_file', 'caller_func', 'caller_line', 'exc_info',
                          'exc_text', 'stack_info']:
                log_obj[key] = value

        # Add exception info if present
        if record.exc_info:
            log_obj['exception'] = {
                'type': record.exc_info[0].__name__,
                'message': str(record.exc_info[1]),
                'traceback': traceback.format_exception(*record.exc_info)
            }

        return json.dumps(log_obj)


class CommandJsonFormatter(logging.Formatter):
    """JSON formatter specifically for command audit logs."""

    def format(self, record):
        """Format command log record as JSON."""
        # Extract all the command-specific fields from extra
        command_obj = {}
        for key in ['timestamp', 'agent', 'command', 'tool', 'operation',
                   'exit_code', 'duration', 'success', 'stdout', 'stderr',
                   'error', 'error_type']:
            if hasattr(record, key):
                command_obj[key] = getattr(record, key)

        # If no timestamp in extra, add it
        if 'timestamp' not in command_obj:
            command_obj['timestamp'] = datetime.fromtimestamp(record.created).isoformat()

        return json.dumps(command_obj)


class LogAnalyzer:
    """Utility class for analyzing log files."""

    def __init__(self, log_path: str):
        """
        Initialize log analyzer.

        Args:
            log_path: Path to the log file to analyze
        """
        self.log_path = Path(log_path)
        if not self.log_path.exists():
            raise FileNotFoundError(f"Log file not found: {log_path}")

    def parse_log_line(self, line: str) -> Optional[Dict[str, Any]]:
        """Parse a single log line."""
        # Try JSON format first
        try:
            return json.loads(line)
        except json.JSONDecodeError:
            pass

        # Try text format
        import re
        pattern = r'\[([\d-]+\s[\d:]+\.[\d]+)\]\s+\[(\w+)\]\s+\[(\w+)\]\s+(.*)'
        match = re.match(pattern, line)
        if match:
            return {
                'timestamp': match.group(1),
                'level': match.group(2),
                'agent': match.group(3),
                'message': match.group(4)
            }

        return None

    def analyze(self,
                start_time: Optional[datetime] = None,
                end_time: Optional[datetime] = None,
                level_filter: Optional[str] = None,
                agent_filter: Optional[str] = None) -> Dict[str, Any]:
        """
        Analyze log file with optional filters.

        Args:
            start_time: Filter logs after this time
            end_time: Filter logs before this time
            level_filter: Only include this log level
            agent_filter: Only include logs from this agent

        Returns:
            Analysis results
        """
        results = {
            'total_lines': 0,
            'parsed_lines': 0,
            'errors': [],
            'warnings': [],
            'by_level': Counter(),
            'by_agent': Counter(),
            'timeline': defaultdict(int)
        }

        with open(self.log_path, 'r') as f:
            for line_num, line in enumerate(f, 1):
                results['total_lines'] += 1

                parsed = self.parse_log_line(line.strip())
                if not parsed:
                    continue

                results['parsed_lines'] += 1

                # Apply filters
                if level_filter and parsed.get('level') != level_filter:
                    continue
                if agent_filter and parsed.get('agent') != agent_filter:
                    continue

                # Time filtering
                if start_time or end_time:
                    try:
                        if 'timestamp' in parsed:
                            if isinstance(parsed['timestamp'], str):
                                log_time = datetime.fromisoformat(
                                    parsed['timestamp'].replace(' ', 'T')
                                )
                            else:
                                log_time = datetime.fromtimestamp(parsed['timestamp'])

                            if start_time and log_time < start_time:
                                continue
                            if end_time and log_time > end_time:
                                continue
                    except:
                        pass

                # Collect statistics
                level = parsed.get('level', 'UNKNOWN')
                agent = parsed.get('agent', 'UNKNOWN')

                results['by_level'][level] += 1
                results['by_agent'][agent] += 1

                # Collect errors and warnings
                if level == 'ERROR':
                    results['errors'].append({
                        'line': line_num,
                        'agent': agent,
                        'message': parsed.get('message', '')
                    })
                elif level == 'WARNING':
                    results['warnings'].append({
                        'line': line_num,
                        'agent': agent,
                        'message': parsed.get('message', '')
                    })

                # Timeline analysis (hourly buckets)
                try:
                    if 'timestamp' in parsed:
                        if isinstance(parsed['timestamp'], str):
                            log_time = datetime.fromisoformat(
                                parsed['timestamp'].replace(' ', 'T')
                            )
                        else:
                            log_time = datetime.fromtimestamp(parsed['timestamp'])

                        hour_bucket = log_time.strftime('%Y-%m-%d %H:00')
                        results['timeline'][hour_bucket] += 1
                except:
                    pass

        return results

    def search(self, pattern: str, context_lines: int = 0) -> List[Tuple[int, str]]:
        """
        Search for pattern in log file.

        Args:
            pattern: Regular expression pattern to search
            context_lines: Number of context lines before/after match

        Returns:
            List of (line_number, line_content) tuples
        """
        import re
        regex = re.compile(pattern, re.IGNORECASE)
        matches = []

        with open(self.log_path, 'r') as f:
            lines = f.readlines()

        for i, line in enumerate(lines):
            if regex.search(line):
                # Add context lines
                start = max(0, i - context_lines)
                end = min(len(lines), i + context_lines + 1)

                for j in range(start, end):
                    matches.append((j + 1, lines[j].rstrip()))

        return matches

    def tail(self, n: int = 50) -> List[str]:
        """Get the last n lines from the log file."""
        with open(self.log_path, 'r') as f:
            lines = f.readlines()

        return [line.rstrip() for line in lines[-n:]]

    def get_errors(self, last_n: Optional[int] = None) -> List[Dict[str, Any]]:
        """Extract error entries from the log."""
        errors = []

        with open(self.log_path, 'r') as f:
            for line_num, line in enumerate(f, 1):
                parsed = self.parse_log_line(line.strip())
                if parsed and parsed.get('level') in ['ERROR', 'CRITICAL']:
                    errors.append({
                        'line_number': line_num,
                        'timestamp': parsed.get('timestamp'),
                        'agent': parsed.get('agent'),
                        'message': parsed.get('message'),
                        'level': parsed.get('level')
                    })

        if last_n:
            return errors[-last_n:]
        return errors

    def analyze_commands(self, command_log_path: Optional[str] = None) -> Dict[str, Any]:
        """
        Analyze command audit log.

        Args:
            command_log_path: Path to command.log file (if different from main log)

        Returns:
            Command analysis results
        """
        if command_log_path:
            log_path = Path(command_log_path)
        else:
            # Try to find command.log in same directory as main log
            log_dir = self.log_path.parent
            log_path = log_dir / 'command.log'

        if not log_path.exists():
            return {'error': f'Command log not found: {log_path}'}

        results = {
            'total_commands': 0,
            'successful': 0,
            'failed': 0,
            'by_tool': Counter(),
            'by_operation': Counter(),
            'errors': [],
            'slow_commands': [],  # Commands taking > 5s
            'recent_failures': []
        }

        with open(log_path, 'r') as f:
            for line in f:
                try:
                    cmd = json.loads(line.strip())
                    results['total_commands'] += 1

                    # Count success/failure
                    if cmd.get('success'):
                        results['successful'] += 1
                    else:
                        results['failed'] += 1
                        results['recent_failures'].append({
                            'command': cmd.get('command'),
                            'error': cmd.get('error', 'Unknown error'),
                            'timestamp': cmd.get('timestamp')
                        })

                    # Track by tool and operation
                    results['by_tool'][cmd.get('tool', 'unknown')] += 1
                    results['by_operation'][cmd.get('operation', 'unknown')] += 1

                    # Find slow commands
                    duration = cmd.get('duration', 0)
                    if duration > 5.0:
                        results['slow_commands'].append({
                            'command': cmd.get('command'),
                            'duration': duration,
                            'timestamp': cmd.get('timestamp')
                        })

                    # Collect errors
                    if cmd.get('error'):
                        results['errors'].append({
                            'command': cmd.get('command'),
                            'error': cmd.get('error'),
                            'error_type': cmd.get('error_type'),
                            'timestamp': cmd.get('timestamp')
                        })

                except json.JSONDecodeError:
                    continue

        # Calculate success rate
        if results['total_commands'] > 0:
            results['success_rate'] = (results['successful'] / results['total_commands']) * 100
        else:
            results['success_rate'] = 0

        # Keep only recent items
        results['recent_failures'] = results['recent_failures'][-10:]
        results['slow_commands'] = sorted(results['slow_commands'],
                                         key=lambda x: x['duration'],
                                         reverse=True)[:10]
        results['errors'] = results['errors'][-20:]

        return results

    def filter_by_commands(self, pattern: str = None,
                          tool: str = None,
                          success_only: bool = False) -> List[str]:
        """
        Filter log entries related to CLI commands.

        Args:
            pattern: Regex pattern to match in command
            tool: Filter by specific tool (zbx, topdesk)
            success_only: Only show successful commands

        Returns:
            List of matching log lines
        """
        matches = []
        command_pattern = re.compile(r'Command executed:', re.IGNORECASE)

        if pattern:
            user_pattern = re.compile(pattern, re.IGNORECASE)

        with open(self.log_path, 'r') as f:
            for line in f:
                # Check if it's a command log line
                if command_pattern.search(line):
                    # Apply filters
                    if tool and tool.lower() not in line.lower():
                        continue
                    if success_only and '[exit: 0]' not in line:
                        continue
                    if pattern and not user_pattern.search(line):
                        continue

                    matches.append(line.rstrip())

        return matches


# Singleton logger instance
_logger_instance: Optional[MergerLogger] = None


def get_logger(output_dir: str = "./output", **kwargs) -> MergerLogger:
    """
    Get or create the singleton logger instance.

    Args:
        output_dir: Output directory for logs
        **kwargs: Additional configuration options

    Returns:
        MergerLogger instance
    """
    global _logger_instance
    if _logger_instance is None:
        _logger_instance = MergerLogger(output_dir=output_dir, **kwargs)
    return _logger_instance


def setup_logger(config: Dict[str, Any]) -> MergerLogger:
    """
    Setup logger from configuration dictionary.

    Args:
        config: Configuration dictionary

    Returns:
        Configured MergerLogger instance
    """
    logger_config = config.get('logging', {})

    return get_logger(
        output_dir=logger_config.get('output_dir', './output'),
        log_filename=logger_config.get('filename', 'merger.log'),
        max_bytes=logger_config.get('max_bytes', 10 * 1024 * 1024),
        backup_count=logger_config.get('backup_count', 5),
        log_level=getattr(logging, logger_config.get('level', 'INFO')),
        console_output=logger_config.get('console_output', True),
        json_format=logger_config.get('json_format', False)
    )
