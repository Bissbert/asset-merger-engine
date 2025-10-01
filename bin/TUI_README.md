# Terminal User Interface (TUI) for Asset Merger

## Overview
The TUI Operator provides an interactive terminal-based interface for comparing and merging asset data between Zabbix and Topdesk systems. It processes `.dif` (difference) files and generates `.apl` (apply) files based on user selections.

## Available Implementations

### 1. **tui_operator.sh** - Dialog-based TUI
- **Requirements**: `dialog` command
- **Features**: Full-featured interface with advanced dialog controls
- **Best for**: Desktop Linux systems with dialog installed
- **Install dialog**:
  ```bash
  # macOS
  brew install dialog

  # Ubuntu/Debian
  sudo apt-get install dialog

  # RHEL/CentOS
  sudo yum install dialog
  ```

### 2. **tui_whiptail.sh** - Whiptail-based TUI
- **Requirements**: `whiptail` command (part of newt)
- **Features**: Lightweight, good compatibility
- **Best for**: Server environments, SSH sessions
- **Install whiptail**:
  ```bash
  # macOS
  brew install newt

  # Ubuntu/Debian
  sudo apt-get install whiptail

  # RHEL/CentOS
  sudo yum install newt
  ```

### 3. **tui_pure_shell.sh** - Pure POSIX Shell TUI
- **Requirements**: None (pure POSIX shell)
- **Features**: Basic but functional interface
- **Best for**: Minimal environments, maximum portability
- **Colors**: Automatic (uses tput if available)

### 4. **tui_launcher.sh** - Smart Launcher
- Automatically detects available TUI implementations
- Provides installation instructions for missing dependencies
- Can auto-select the best available option

## Usage

### Quick Start
```bash
# Use the launcher (recommended)
./bin/tui_launcher.sh

# Auto-select best available TUI
./bin/tui_launcher.sh --auto

# Direct execution (if dependencies are met)
./bin/tui_operator.sh      # Dialog version
./bin/tui_whiptail.sh      # Whiptail version
./bin/tui_pure_shell.sh    # Pure shell version
```

### Workflow
1. **Launch TUI**: Run the launcher or a specific TUI implementation
2. **Select Asset**: Choose a difference file to process
3. **Compare Fields**: For each field with differences:
   - View Zabbix value
   - View Topdesk value
   - Select preferred value or enter custom
4. **Review Selections**: Check your choices before saving
5. **Generate APL**: Create the apply file with your selections

## File Structure

### Input Files (.dif)
Location: `output/differences/`

Format:
```json
{
  "field_name": {
    "zabbix": "value_from_zabbix",
    "topdesk": "value_from_topdesk"
  }
}
```

### Output Files (.apl)
Location: `output/apply/`

Format:
```json
[
  {
    "asset_id": "asset_identifier",
    "fields": {
      "field_name": "selected_value"
    }
  }
]
```

## Features

### Field Comparison
- **Matching values**: Auto-selected (shown in green)
- **Conflicting values**: User selection required (shown in red)
- **Empty values**: Displayed as "(empty)"
- **Custom values**: Option to enter your own value

### Navigation

#### Dialog/Whiptail versions:
- Arrow keys: Navigate menus
- Enter: Select option
- Escape: Go back/cancel
- Space: Toggle selection (where applicable)

#### Pure Shell version:
- Number keys: Select menu options
- z/t/c/s: Zabbix/Topdesk/Custom/Skip for field selection
- Enter: Confirm selection
- q: Quit

### Session Management
- **Auto-save**: Selections are saved immediately
- **Resume**: Can continue from where you left off
- **Clear**: Option to reset all selections
- **Logging**: All actions logged to `var/log/`

## Color Coding

| Color   | Meaning                     |
|---------|----------------------------|
| Green   | Matching values / Success  |
| Red     | Conflicting values / Error |
| Yellow  | Field names / Warnings     |
| Blue    | Headers / Information      |
| Cyan    | Zabbix values             |
| Magenta | Topdesk values            |

## Keyboard Shortcuts

### Main Menu
- `1` - Process difference files
- `2` - View current selections
- `3` - Generate APL file
- `4` - Clear selections
- `5` - View logs
- `h` - Help
- `q` - Quit

### Field Selection
- `z` - Use Zabbix value
- `t` - Use Topdesk value
- `c` - Enter custom value
- `s` - Skip field

## Troubleshooting

### No TUI commands available
Use the pure shell version:
```bash
./bin/tui_pure_shell.sh
```

### Colors not displaying
- Check terminal support: `echo $TERM`
- Try setting: `export TERM=xterm-256color`
- Use pure shell version for basic colors

### Dialog/Whiptail not found
Run the launcher for installation instructions:
```bash
./bin/tui_launcher.sh
# Then select option 4 for installation help
```

### Corrupt display
- Resize terminal window
- Press Ctrl+L to refresh (in some TUIs)
- Restart the TUI

## Performance Considerations

- **Large datasets**: Pure shell may be slower
- **SSH sessions**: Whiptail recommended
- **Local use**: Dialog provides best experience
- **Minimal systems**: Pure shell always works

## Examples

### Process single asset
```bash
# Launch TUI
./bin/tui_launcher.sh

# Select option 1 (Process difference files)
# Choose asset from list
# Make selections for each field
# Generate APL when done
```

### Batch processing workflow
```bash
# Process multiple assets
for dif in output/differences/*.dif; do
    # TUI will handle each file
    ./bin/tui_pure_shell.sh
done
```

### Review and export
```bash
# View selections
./bin/tui_launcher.sh
# Select option 2 (View selections)

# Generate final APL
# Select option 3 (Generate APL file)
```

## Log Files
- Dialog TUI: `var/log/tui_operator.log`
- Whiptail TUI: `var/log/tui_whiptail.log`
- Pure Shell TUI: `var/log/tui_pure_shell.log`

## Support
- Check logs for detailed error information
- Ensure difference files are properly formatted JSON
- Verify output directories exist and are writable
- Use launcher script for dependency checking