# Backup Script

A professional, robust, and configurable Linux backup script designed for system administrators and advanced users. It automates directory backups with compression, logging, error handling, and retention policies.

***

### Features

- Multiple source directories support
- Timestamped backups
- Detailed logging with rotation
- Error handling and status reporting
- Lock file to prevent concurrent runs
- Automatic cleanup of old backups
- Optional pre/post backup hooks (extendable by user)

***

### Requirements

- Linux system with `bash`
- Root/sudo privileges (for system directory backups)
- Core utilities: `tar`, `flock`, `du`, `stat`, `find`

***

### Configuration

Inside the script, adjust variables as per your environment:

- **SOURCES_TO_BACKUP**: Array of directories to back up
Example:

```bash
SOURCES_TO_BACKUP=("/home" "/etc")
```

- **BACKUP_DESTINATION_ROOT**: Destination path for storing backups (default: `/backup`)
- **RETENTION_DAYS**: Number of days to keep backups (default: `7`)
- **BACKUP_FILENAME_FORMAT**: Filename format using `date`
Example: `backup-%F_%T.tar.gz` → `backup-2025-09-18_07:36:20.tar.gz`
- **LOG_DIR**: Directory to store logs (default: `/var/log/backup_script`)
- **MAX_LOG_SIZE_KB**: Maximum log file size before rotation (default: `1024 KB`)

***

### Usage

1. Make the script executable:

```bash
chmod +x backup.sh
```

2. Run as root or with sudo (required for system directories like `/etc`):

```bash
sudo ./backup.sh
```

3. To automate, add as a **cron job**:
Example: run daily at 2 AM

```bash
0 2 * * * /path/to/backup.sh
```


***

### Output

- **Backups**: Stored under `/backup/<timestamp>/backup-YYYY-MM-DD_HH:MM:SS.tar.gz`
- **Logs**: Stored at `/var/log/backup_script/backup.log`
- **Lock file**: At `/var/run/backup_script.lock`

***

### Example Workflow

1. Verify sources:

```bash
SOURCES_TO_BACKUP=("/home/user/documents" "/etc/nginx")
```

2. Run script:

```bash
sudo ./backup.sh
```

3. Backup generated at:

```
/backup/20250918073620/backup-2025-09-18_07:36:20.tar.gz
```

4. Logs written to:

```
/var/log/backup_script/backup.log
```


***

### Error Handling

- Exits if source directories are missing
- Checks for concurrent runs using a lock file
- Validates backup archive size
- Logs errors and warnings with timestamps

***

### License
This project is licensed under the MIT OpenSource License. Check the file license.txt for more details.