# Dev Alias Manager

[中文](README_zh.md) | [日本語](README_ja.md)

Dev Alias Manager is a Bash script tool for managing USB device aliases. It allows users to listen for new devices, view recorded devices, display detailed device information, delete device records, and rename device aliases.

## Features

- Listen for new (USB) device connections
- Assign aliases to new devices
- View list of recorded devices
- Display detailed device information
- Delete device records
- Rename device aliases
- Multi-language support (English, Chinese, Japanese)
- Automatic language detection
- Configurable settings
- Logging functionality
- Backup management for udev rules

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/XKHoshizora/dev-mgmt-tools.git
   ```
2. Enter the project directory:
   ```bash
   cd dev-mgmt-tools
   ```
3. Ensure the script has execution permissions:
   ```bash
   chmod +x dev_alias_manager.sh
   ```

## Usage

Run the script:

```bash
sudo ./dev_alias_manager.sh
```

Note: Some operations (such as modifying udev rules) require `root` privileges, so it's recommended to run the script with `sudo`.

Follow the on-screen prompts to select an operation:

1. Listen for new devices
2. View recorded devices
3. Show detailed device information
4. Delete device record
5. Rename device alias
6. Exit

## Configuration

The configuration file is located at `config/dev_alias_manager.conf`. You can customize the following settings:

- `MAX_RETRIES`: Maximum number of retries for symlink creation
- `TIMEOUT`: Timeout for device operations
- `DEVICE_RECORD_FILE`: Location of the udev rules file
- `LOG_LEVEL`: Logging level (DEBUG, INFO, WARNING, ERROR)
- `AUTO_NAMING`: Enable/disable automatic device naming
- `AUTO_NAME_PREFIX`: Prefix for automatically generated names
- `LANGUAGE`: Force a specific language (en, zh, ja)
- `MAX_BACKUPS`: Maximum number of backup files to keep

A default configuration file `dev_alias_manager.conf.default` is provided as a template.

## Logs

Log files are located at `logs/dev_alias_manager.log`.

## Language Support

The script automatically detects your system language and displays messages in English, Chinese, or Japanese accordingly. If your system language is not one of these, English will be used as the default. You can also set the language manually in the configuration file.

## Backups

The script creates backups of the udev rules file before making changes. Backups are stored in the `backups` directory. The number of backups kept is configurable.

## Notes

- This script modifies system udev rules. Use with caution.
- The script creates a backup of the udev rules file before any operation.
- Check the log file for more information if you encounter any issues.
- The script uses a lock file to prevent multiple instances from running simultaneously.

## Contributing

Issues and Pull Requests are welcome to help improve this project.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.