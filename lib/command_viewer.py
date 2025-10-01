#!/usr/bin/env python3
"""
Command log viewer utility for analyzing CLI command execution history.
Provides interactive viewing and analysis of command audit logs.
"""

import json
import sys
from pathlib import Path
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any
from collections import Counter
import argparse


class CommandLogViewer:
    """Interactive viewer for command audit logs."""

    def __init__(self, command_log_path: str):
        """
        Initialize command log viewer.

        Args:
            command_log_path: Path to command.log file
        """
        self.log_path = Path(command_log_path)
        if not self.log_path.exists():
            raise FileNotFoundError(f"Command log not found: {command_log_path}")

        self.commands = []
        self._load_commands()

    def _load_commands(self):
        """Load all commands from the log file."""
        with open(self.log_path, 'r') as f:
            for line_num, line in enumerate(f, 1):
                try:
                    cmd = json.loads(line.strip())
                    cmd['_line_num'] = line_num
                    self.commands.append(cmd)
                except json.JSONDecodeError as e:
                    print(f"Warning: Failed to parse line {line_num}: {e}", file=sys.stderr)

    def print_summary(self):
        """Print overall summary of commands."""
        if not self.commands:
            print("No commands found in log.")
            return

        total = len(self.commands)
        successful = sum(1 for c in self.commands if c.get('success'))
        failed = total - successful

        # Time range
        timestamps = [c.get('timestamp') for c in self.commands if c.get('timestamp')]
        if timestamps:
            first_time = min(timestamps)
            last_time = max(timestamps)
        else:
            first_time = last_time = "Unknown"

        # Calculate total duration
        total_duration = sum(c.get('duration', 0) for c in self.commands)

        print("\n" + "=" * 60)
        print("COMMAND LOG SUMMARY")
        print("=" * 60)
        print(f"Log file: {self.log_path}")
        print(f"Total commands: {total}")
        print(f"Successful: {successful} ({successful/total*100:.1f}%)")
        print(f"Failed: {failed} ({failed/total*100:.1f}%)")
        print(f"Time range: {first_time} to {last_time}")
        print(f"Total execution time: {total_duration:.2f}s")

        # Tools breakdown
        tools = Counter(c.get('tool', 'unknown') for c in self.commands)
        print("\nCommands by tool:")
        for tool, count in tools.most_common():
            print(f"  {tool:15s}: {count:4d} ({count/total*100:5.1f}%)")

        # Operations breakdown
        operations = Counter(c.get('operation', 'unknown') for c in self.commands)
        print("\nTop operations:")
        for op, count in operations.most_common(10):
            print(f"  {op:20s}: {count:4d}")

        # Error types
        error_types = Counter(c.get('error_type') for c in self.commands
                            if c.get('error_type'))
        if error_types:
            print("\nError types:")
            for error_type, count in error_types.most_common():
                print(f"  {error_type:20s}: {count:4d}")

    def show_failures(self, last_n: Optional[int] = None):
        """Show failed commands."""
        failed = [c for c in self.commands if not c.get('success')]

        if not failed:
            print("No failed commands found.")
            return

        if last_n:
            failed = failed[-last_n:]

        print(f"\n{'=' * 60}")
        print(f"FAILED COMMANDS ({len(failed)} total)")
        print('=' * 60)

        for i, cmd in enumerate(failed, 1):
            print(f"\n[{i}] Line {cmd['_line_num']}")
            print(f"    Time: {cmd.get('timestamp', 'Unknown')}")
            print(f"    Command: {cmd.get('command', 'Unknown')}")
            print(f"    Exit code: {cmd.get('exit_code', 'Unknown')}")
            if cmd.get('error'):
                print(f"    Error: {cmd['error']}")
            if cmd.get('stderr'):
                stderr = cmd['stderr'][:200]
                if len(cmd['stderr']) > 200:
                    stderr += '...'
                print(f"    Stderr: {stderr}")

    def show_slow_commands(self, threshold: float = 5.0):
        """Show commands that took longer than threshold seconds."""
        slow = [c for c in self.commands if c.get('duration', 0) > threshold]

        if not slow:
            print(f"No commands took longer than {threshold}s.")
            return

        # Sort by duration
        slow.sort(key=lambda x: x.get('duration', 0), reverse=True)

        print(f"\n{'=' * 60}")
        print(f"SLOW COMMANDS (>{threshold}s) - {len(slow)} total")
        print('=' * 60)

        for i, cmd in enumerate(slow[:20], 1):
            print(f"\n[{i}] Duration: {cmd.get('duration', 0):.2f}s")
            print(f"    Time: {cmd.get('timestamp', 'Unknown')}")
            print(f"    Command: {cmd.get('command', 'Unknown')}")
            print(f"    Success: {cmd.get('success', 'Unknown')}")

    def filter_commands(self, tool: Optional[str] = None,
                       operation: Optional[str] = None,
                       success: Optional[bool] = None,
                       start_time: Optional[str] = None,
                       end_time: Optional[str] = None) -> List[Dict[str, Any]]:
        """
        Filter commands by various criteria.

        Args:
            tool: Filter by tool name
            operation: Filter by operation
            success: Filter by success status
            start_time: ISO format start time
            end_time: ISO format end time

        Returns:
            Filtered list of commands
        """
        filtered = self.commands.copy()

        if tool:
            filtered = [c for c in filtered if c.get('tool') == tool]

        if operation:
            filtered = [c for c in filtered if c.get('operation') == operation]

        if success is not None:
            filtered = [c for c in filtered if c.get('success') == success]

        if start_time:
            filtered = [c for c in filtered
                       if c.get('timestamp', '') >= start_time]

        if end_time:
            filtered = [c for c in filtered
                       if c.get('timestamp', '') <= end_time]

        return filtered

    def show_timeline(self, hourly: bool = True):
        """Show command execution timeline."""
        if not self.commands:
            print("No commands to show.")
            return

        timeline = {}

        for cmd in self.commands:
            timestamp = cmd.get('timestamp')
            if not timestamp:
                continue

            try:
                dt = datetime.fromisoformat(timestamp)
                if hourly:
                    bucket = dt.strftime('%Y-%m-%d %H:00')
                else:
                    bucket = dt.strftime('%Y-%m-%d')

                if bucket not in timeline:
                    timeline[bucket] = {'total': 0, 'success': 0, 'failed': 0}

                timeline[bucket]['total'] += 1
                if cmd.get('success'):
                    timeline[bucket]['success'] += 1
                else:
                    timeline[bucket]['failed'] += 1
            except:
                continue

        print(f"\n{'=' * 60}")
        print(f"COMMAND TIMELINE ({'Hourly' if hourly else 'Daily'})")
        print('=' * 60)
        print(f"{'Time':<20} {'Total':>8} {'Success':>8} {'Failed':>8} {'Rate':>8}")
        print('-' * 60)

        for time_bucket in sorted(timeline.keys()):
            stats = timeline[time_bucket]
            success_rate = (stats['success'] / stats['total'] * 100)
            print(f"{time_bucket:<20} {stats['total']:>8} {stats['success']:>8} "
                  f"{stats['failed']:>8} {success_rate:>7.1f}%")

    def export_for_replay(self, output_file: str,
                         filter_success: bool = True):
        """
        Export commands as a shell script for replay.

        Args:
            output_file: Output shell script file
            filter_success: Only export successful commands
        """
        commands = self.commands
        if filter_success:
            commands = [c for c in commands if c.get('success')]

        with open(output_file, 'w') as f:
            f.write("#!/bin/bash\n")
            f.write("# Command replay script generated from command log\n")
            f.write(f"# Generated at: {datetime.now().isoformat()}\n")
            f.write(f"# Total commands: {len(commands)}\n\n")

            for i, cmd in enumerate(commands, 1):
                f.write(f"# Command {i} - {cmd.get('timestamp', 'Unknown')}\n")
                f.write(f"# Duration: {cmd.get('duration', 0):.2f}s\n")
                f.write(f"{cmd.get('command', '# Unknown command')}\n\n")

        print(f"Exported {len(commands)} commands to {output_file}")


def main():
    """Main entry point for command viewer."""
    parser = argparse.ArgumentParser(description='View and analyze command audit logs')
    parser.add_argument('log_file', help='Path to command.log file')
    parser.add_argument('--summary', action='store_true', help='Show summary')
    parser.add_argument('--failures', action='store_true', help='Show failed commands')
    parser.add_argument('--slow', type=float, metavar='SECONDS',
                       help='Show commands slower than N seconds')
    parser.add_argument('--timeline', action='store_true', help='Show execution timeline')
    parser.add_argument('--filter-tool', help='Filter by tool name')
    parser.add_argument('--filter-operation', help='Filter by operation')
    parser.add_argument('--export', help='Export commands to shell script')
    parser.add_argument('--last', type=int, help='Show only last N entries')

    args = parser.parse_args()

    try:
        viewer = CommandLogViewer(args.log_file)

        if args.summary or not any([args.failures, args.slow, args.timeline,
                                   args.filter_tool, args.filter_operation,
                                   args.export]):
            viewer.print_summary()

        if args.failures:
            viewer.show_failures(last_n=args.last)

        if args.slow:
            viewer.show_slow_commands(threshold=args.slow)

        if args.timeline:
            viewer.show_timeline()

        if args.filter_tool or args.filter_operation:
            filtered = viewer.filter_commands(
                tool=args.filter_tool,
                operation=args.filter_operation
            )
            print(f"\nFiltered results: {len(filtered)} commands")
            for cmd in filtered[:args.last] if args.last else filtered:
                print(f"  {cmd.get('timestamp', 'Unknown')}: "
                      f"{cmd.get('command', 'Unknown')} "
                      f"[{'OK' if cmd.get('success') else 'FAIL'}]")

        if args.export:
            viewer.export_for_replay(args.export)

    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()