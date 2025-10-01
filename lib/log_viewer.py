#!/usr/bin/env python3
"""
Log viewer and analyzer utility for merger.log files.
Provides command-line interface for log analysis and visualization.
"""

import argparse
import sys
import re
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional, List
from collections import Counter
import json

# Import the LogAnalyzer from logger module
from logger import LogAnalyzer, MergerLogger


class LogViewer:
    """Interactive log viewer and analyzer."""

    def __init__(self, log_path: str):
        """Initialize the log viewer."""
        self.analyzer = LogAnalyzer(log_path)
        self.log_path = Path(log_path)

    def view_tail(self, lines: int = 50, follow: bool = False):
        """
        Display the last n lines of the log.

        Args:
            lines: Number of lines to display
            follow: Whether to follow the log (like tail -f)
        """
        if follow:
            import time
            print(f"Following {self.log_path} (Ctrl+C to stop)...\n")

            last_size = 0
            try:
                while True:
                    current_size = self.log_path.stat().st_size

                    if current_size > last_size:
                        with open(self.log_path, 'r') as f:
                            f.seek(last_size)
                            new_lines = f.read()
                            print(new_lines, end='')
                        last_size = current_size

                    time.sleep(0.5)
            except KeyboardInterrupt:
                print("\n\nStopped following log.")
        else:
            tail_lines = self.analyzer.tail(lines)
            for line in tail_lines:
                self._print_colored_line(line)

    def view_errors(self, last_n: Optional[int] = None, verbose: bool = False):
        """
        Display error entries from the log.

        Args:
            last_n: Show only the last n errors
            verbose: Show full error details
        """
        errors = self.analyzer.get_errors(last_n=last_n)

        if not errors:
            print("No errors found in the log.")
            return

        print(f"\nFound {len(errors)} error(s):\n")
        print("=" * 80)

        for error in errors:
            timestamp = error['timestamp'] if error['timestamp'] else 'Unknown'
            agent = error['agent'] if error['agent'] else 'UNKNOWN'
            message = error['message'] if error['message'] else 'No message'
            level = error['level'] if error['level'] else 'ERROR'

            # Color coding for terminal
            if level == 'CRITICAL':
                color = '\033[91m'  # Red
            else:
                color = '\033[93m'  # Yellow

            reset = '\033[0m'

            print(f"{color}[{timestamp}] [{level}] [{agent}]{reset}")
            print(f"  Line {error['line_number']}: {message}")

            if verbose and 'traceback' in error and error['traceback']:
                print(f"  Traceback:")
                for line in error['traceback']:
                    print(f"    {line}")

            print("-" * 80)

    def analyze_log(self, start_time: Optional[str] = None,
                   end_time: Optional[str] = None,
                   agent_filter: Optional[str] = None,
                   level_filter: Optional[str] = None):
        """
        Analyze log file with filters.

        Args:
            start_time: Start time in ISO format
            end_time: End time in ISO format
            agent_filter: Filter by agent name
            level_filter: Filter by log level
        """
        # Parse time filters
        start_dt = None
        end_dt = None

        if start_time:
            try:
                start_dt = datetime.fromisoformat(start_time)
            except ValueError:
                print(f"Invalid start time format: {start_time}")
                return

        if end_time:
            try:
                end_dt = datetime.fromisoformat(end_time)
            except ValueError:
                print(f"Invalid end time format: {end_time}")
                return

        # Run analysis
        results = self.analyzer.analyze(
            start_time=start_dt,
            end_time=end_dt,
            level_filter=level_filter,
            agent_filter=agent_filter
        )

        # Display results
        print("\n" + "=" * 80)
        print("LOG ANALYSIS RESULTS")
        print("=" * 80)

        print(f"\nFile: {self.log_path}")
        print(f"Total lines: {results['total_lines']}")
        print(f"Parsed lines: {results['parsed_lines']}")

        if start_time or end_time:
            print(f"\nTime range:")
            if start_time:
                print(f"  From: {start_time}")
            if end_time:
                print(f"  To: {end_time}")

        if agent_filter:
            print(f"Agent filter: {agent_filter}")
        if level_filter:
            print(f"Level filter: {level_filter}")

        print(f"\n{'Log Levels':20} {'Count':>10}")
        print("-" * 31)
        for level, count in sorted(results['by_level'].items()):
            print(f"{level:20} {count:10,}")

        print(f"\n{'Agents':20} {'Count':>10}")
        print("-" * 31)
        for agent, count in sorted(results['by_agent'].items(),
                                  key=lambda x: x[1], reverse=True)[:10]:
            print(f"{agent:20} {count:10,}")

        if results['errors']:
            print(f"\nErrors: {len(results['errors'])}")
            print("Recent errors:")
            for error in results['errors'][-5:]:
                print(f"  Line {error['line']}: [{error['agent']}] {error['message'][:60]}...")

        if results['warnings']:
            print(f"\nWarnings: {len(results['warnings'])}")
            print("Recent warnings:")
            for warning in results['warnings'][-5:]:
                print(f"  Line {warning['line']}: [{warning['agent']}] {warning['message'][:60]}...")

        if results['timeline']:
            print(f"\nActivity Timeline (hourly):")
            sorted_timeline = sorted(results['timeline'].items())
            for hour, count in sorted_timeline[-10:]:
                bar = '█' * min(50, count // 2)
                print(f"  {hour}: {bar} ({count})")

    def search_log(self, pattern: str, context: int = 0, show_line_numbers: bool = True):
        """
        Search for pattern in log file.

        Args:
            pattern: Regular expression pattern
            context: Number of context lines
            show_line_numbers: Whether to show line numbers
        """
        matches = self.analyzer.search(pattern, context_lines=context)

        if not matches:
            print(f"No matches found for pattern: {pattern}")
            return

        print(f"\nFound {len(set(m[0] for m in matches))} matching line(s):\n")
        print("=" * 80)

        last_line_num = -1
        for line_num, line in matches:
            if line_num != last_line_num + 1 and last_line_num != -1:
                print("...")

            if show_line_numbers:
                print(f"{line_num:6d}: {line}")
            else:
                print(line)

            last_line_num = line_num

    def export_errors(self, output_file: str, format: str = 'json'):
        """
        Export errors to a file.

        Args:
            output_file: Output file path
            format: Export format (json, csv, text)
        """
        errors = self.analyzer.get_errors()

        if not errors:
            print("No errors to export.")
            return

        output_path = Path(output_file)

        if format == 'json':
            with open(output_path, 'w') as f:
                json.dump(errors, f, indent=2)
        elif format == 'csv':
            import csv
            with open(output_path, 'w', newline='') as f:
                writer = csv.DictWriter(f, fieldnames=['line_number', 'timestamp',
                                                       'agent', 'level', 'message'])
                writer.writeheader()
                writer.writerows(errors)
        else:  # text
            with open(output_path, 'w') as f:
                for error in errors:
                    f.write(f"[{error['timestamp']}] [{error['level']}] "
                           f"[{error['agent']}] Line {error['line_number']}: "
                           f"{error['message']}\n")

        print(f"Exported {len(errors)} errors to {output_path}")

    def _print_colored_line(self, line: str):
        """Print a log line with color coding."""
        # Color codes for different log levels
        colors = {
            'TRACE': '\033[90m',     # Gray
            'DEBUG': '\033[36m',     # Cyan
            'INFO': '\033[32m',      # Green
            'WARNING': '\033[33m',   # Yellow
            'ERROR': '\033[91m',     # Light Red
            'CRITICAL': '\033[31m',  # Red
        }
        reset = '\033[0m'

        # Try to identify log level in line
        for level, color in colors.items():
            if f'[{level}]' in line:
                print(f"{color}{line}{reset}")
                return

        # Default: no color
        print(line)

    def show_statistics(self):
        """Display comprehensive statistics about the log file."""
        results = self.analyzer.analyze()

        print("\n" + "=" * 80)
        print("LOG FILE STATISTICS")
        print("=" * 80)

        print(f"\nFile: {self.log_path}")
        print(f"Size: {self.log_path.stat().st_size:,} bytes")
        print(f"Modified: {datetime.fromtimestamp(self.log_path.stat().st_mtime)}")
        print(f"Total lines: {results['total_lines']:,}")
        print(f"Parsed lines: {results['parsed_lines']:,}")

        # Calculate percentages
        if results['total_lines'] > 0:
            parse_rate = (results['parsed_lines'] / results['total_lines']) * 100
            print(f"Parse rate: {parse_rate:.1f}%")

        # Level distribution
        print(f"\n{'Level Distribution':30}")
        print("-" * 30)
        total_by_level = sum(results['by_level'].values())
        for level in ['TRACE', 'DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL']:
            count = results['by_level'].get(level, 0)
            if total_by_level > 0:
                pct = (count / total_by_level) * 100
                bar = '█' * int(pct / 2)
                print(f"{level:10} {count:6,} ({pct:5.1f}%) {bar}")
            else:
                print(f"{level:10} {count:6,}")

        # Top agents
        print(f"\n{'Top Agents by Activity':30}")
        print("-" * 30)
        for agent, count in sorted(results['by_agent'].items(),
                                  key=lambda x: x[1], reverse=True)[:10]:
            print(f"{agent:20} {count:8,}")

        # Error summary
        if results['errors'] or results['warnings']:
            print(f"\n{'Issues Summary':30}")
            print("-" * 30)
            print(f"Errors:   {len(results['errors']):8,}")
            print(f"Warnings: {len(results['warnings']):8,}")

        # Timeline summary
        if results['timeline']:
            print(f"\n{'Activity Summary':30}")
            print("-" * 30)
            hourly_counts = list(results['timeline'].values())
            print(f"Peak hour:    {max(hourly_counts):,} messages")
            print(f"Average/hour: {sum(hourly_counts) / len(hourly_counts):.1f} messages")
            print(f"Active hours: {len(hourly_counts)}")


def main():
    """Main entry point for the log viewer utility."""
    parser = argparse.ArgumentParser(
        description='Log viewer and analyzer for merger.log files'
    )

    parser.add_argument(
        'log_file',
        help='Path to the log file to analyze'
    )

    subparsers = parser.add_subparsers(dest='command', help='Available commands')

    # Tail command
    tail_parser = subparsers.add_parser('tail', help='View the end of the log')
    tail_parser.add_argument('-n', '--lines', type=int, default=50,
                           help='Number of lines to display (default: 50)')
    tail_parser.add_argument('-f', '--follow', action='store_true',
                           help='Follow the log file (like tail -f)')

    # Errors command
    errors_parser = subparsers.add_parser('errors', help='View error entries')
    errors_parser.add_argument('-n', '--last', type=int,
                             help='Show only the last n errors')
    errors_parser.add_argument('-v', '--verbose', action='store_true',
                             help='Show full error details')

    # Analyze command
    analyze_parser = subparsers.add_parser('analyze', help='Analyze log file')
    analyze_parser.add_argument('--start', help='Start time (ISO format)')
    analyze_parser.add_argument('--end', help='End time (ISO format)')
    analyze_parser.add_argument('--agent', help='Filter by agent name')
    analyze_parser.add_argument('--level', help='Filter by log level')

    # Search command
    search_parser = subparsers.add_parser('search', help='Search in log file')
    search_parser.add_argument('pattern', help='Regular expression pattern to search')
    search_parser.add_argument('-C', '--context', type=int, default=0,
                             help='Number of context lines to show')
    search_parser.add_argument('--no-line-numbers', action='store_true',
                             help='Do not show line numbers')

    # Export command
    export_parser = subparsers.add_parser('export', help='Export errors to file')
    export_parser.add_argument('output', help='Output file path')
    export_parser.add_argument('--format', choices=['json', 'csv', 'text'],
                             default='json', help='Export format (default: json)')

    # Stats command
    stats_parser = subparsers.add_parser('stats', help='Show comprehensive statistics')

    args = parser.parse_args()

    # Check if log file exists
    if not Path(args.log_file).exists():
        print(f"Error: Log file not found: {args.log_file}")
        sys.exit(1)

    # Create viewer
    viewer = LogViewer(args.log_file)

    # Execute command
    if args.command == 'tail':
        viewer.view_tail(lines=args.lines, follow=args.follow)
    elif args.command == 'errors':
        viewer.view_errors(last_n=args.last, verbose=args.verbose)
    elif args.command == 'analyze':
        viewer.analyze_log(
            start_time=args.start,
            end_time=args.end,
            agent_filter=args.agent,
            level_filter=args.level
        )
    elif args.command == 'search':
        viewer.search_log(
            pattern=args.pattern,
            context=args.context,
            show_line_numbers=not args.no_line_numbers
        )
    elif args.command == 'export':
        viewer.export_errors(args.output, format=args.format)
    elif args.command == 'stats':
        viewer.show_statistics()
    else:
        # Default: show statistics
        viewer.show_statistics()


if __name__ == "__main__":
    main()
