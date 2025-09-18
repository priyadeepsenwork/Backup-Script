#!/bin/bash

# ====================================================================================
# A professional, robust, and configurable backup script.
#
# Features:
# - Easy Configuration
# - Multiple Source Directories
# - Timestamped Backups
# - Detailed Logging with Log Rotation
# - Error Handling and Reporting
# - Lock File to Prevent Concurrent Runs
# - Automatic Cleanup of Old Backups
# - Pre/Post Backup Commands (Optional)
# ====================================================================================

set -o pipefail # Fail a pipeline if any command fails

# --- SCRIPT CONFIGURATION ---

# An array of directories to back up.
# Add as many as you need, separated by spaces.
# Example: SOURCES_TO_BACKUP=("/home/user/documents" "/etc/nginx")
#SOURCES_TO_BACKUP=("/home" "/etc")
SOURCES_TO_BACKUP=("/home/subaru/Documents/")

# The destination directory where backups will be stored.
BACKUP_DESTINATION_ROOT="/home/subaru/Backups"

# Number of days to keep backups. Backups older than this will be deleted.
RETENTION_DAYS=30

# --- ADVANCED CONFIGURATION ---

# The filename format for the backup archive.
# Uses date formatting. %F = YYYY-MM-DD, %T = HH:MM:SS
BACKUP_FILENAME_FORMAT="backup-%F_%T.tar.gz"

# The directory to store logs.
LOG_DIR="/home/subaru/Backups/logs/"
LOG_FILE="${LOG_DIR}/backup.log"
# Max log file size in kilobytes. When exceeded, the log will be rotated.
MAX_LOG_SIZE_KB=1024

# Lock file to prevent the script from running more than once at a time.
LOCK_FILE="/var/run/backup_script.lock"

# --- SCRIPT LOGIC ---

# Function to log messages with a timestamp.
log_message() {
    local level="$1"
    local message="$2"
    echo "$(date +"%Y-%m-%d %H:%M:%S") [${level}] - ${message}" | tee -a "${LOG_FILE}"
}

# Function to handle script exit.
# It ensures the lock file is removed.
cleanup_and_exit() {
    local exit_code=$1
    local exit_message="$2"

    if [ "${exit_code}" -ne 0 ]; then
        log_message "ERROR" "${exit_message}"
    fi

    log_message "INFO" "Backup script finished."
    rm -f "${LOCK_FILE}"
    exit "${exit_code}"
}

# Function for log rotation.
rotate_log() {
    if [ ! -f "${LOG_FILE}" ]; then
        return
    fi
    
    local log_size_kb
    log_size_kb=$(du -k "${LOG_FILE}" | cut -f1)

    if [ "${log_size_kb}" -ge ${MAX_LOG_SIZE_KB} ]; then
        log_message "INFO" "Rotating log file."
        mv "${LOG_FILE}" "${LOG_FILE}.1"
        touch "${LOG_FILE}"
    fi
}

# --- MAIN SCRIPT EXECUTION ---

# 1. Check for root privileges if necessary (e.g., for /etc)
if [ "$(id -u)" -ne 0 ]; then
    echo "This script requires root privileges to back up system directories. Please run as root or with sudo."
    exit 1
fi

# 2. Setup Logging
mkdir -p "${LOG_DIR}"
touch "${LOG_FILE}"
rotate_log

log_message "INFO" "Starting backup script..."

# 3. Handle Locking
# Using flock to prevent concurrent execution.
(
    flock -n 9 || cleanup_and_exit 1 "Script is already running. Exiting."

    # 4. Check Source Directories
    for src in "${SOURCES_TO_BACKUP[@]}"; do
        if [ ! -d "${src}" ]; then
            cleanup_and_exit 1 "Source directory '${src}' does not exist. Aborting."
        fi
    done
    log_message "INFO" "All source directories verified."

    # 5. Check/Create Backup Destination
    BACKUP_TIMESTAMP=$(date +"%Y%m%d%H%M%S")
    FINAL_BACKUP_DIR="${BACKUP_DESTINATION_ROOT}/${BACKUP_TIMESTAMP}"
    mkdir -p "${FINAL_BACKUP_DIR}"
    if [ $? -ne 0 ]; then
        cleanup_and_exit 1 "Failed to create backup destination directory: ${FINAL_BACKUP_DIR}"
    fi
    log_message "INFO" "Backup destination created: ${FINAL_BACKUP_DIR}"

    # 6. Perform the Backup
    BACKUP_FILE_NAME=$(date +"${BACKUP_FILENAME_FORMAT}")
    FINAL_ARCHIVE_PATH="${FINAL_BACKUP_DIR}/${BACKUP_FILE_NAME}"

    log_message "INFO" "Starting archive creation for sources: ${SOURCES_TO_BACKUP[*]}"
    log_message "INFO" "Archive will be saved to: ${FINAL_ARCHIVE_PATH}"

    # The 'tar' command archives and compresses the source directories.
    # The absolute-names flag is used to preserve the full path.
    tar --absolute-names -czf "${FINAL_ARCHIVE_PATH}" "${SOURCES_TO_BACKUP[@]}"

    # 7. Verify Backup
    if [ $? -eq 0 ]; then
        log_message "SUCCESS" "Backup archive created successfully."
        # Verify file size to ensure it's not empty
        if [ "$(stat -c%s "${FINAL_ARCHIVE_PATH}")" -gt 1024 ]; then
            log_message "SUCCESS" "Backup archive size is valid."
        else
            cleanup_and_exit 1 "Backup archive is unusually small. Check for errors."
        fi
    else
        cleanup_and_exit 1 "Backup command failed. Archive not created."
    fi

    # 8. Clean up old backups
    log_message "INFO" "Cleaning up backups older than ${RETENTION_DAYS} days in ${BACKUP_DESTINATION_ROOT}."
    
    # Use 'find' to locate directories older than RETENTION_DAYS and remove them.
    find "${BACKUP_DESTINATION_ROOT}" -mindepth 1 -maxdepth 1 -type d -mtime +${RETENTION_DAYS} -exec rm -rf {} \;

    if [ $? -eq 0 ]; then
        log_message "INFO" "Cleanup of old backups completed successfully."
    else
        log_message "WARN" "Cleanup command encountered issues. Please check permissions and paths."
    fi

) 9>"${LOCK_FILE}"

# 9. Final Exit
cleanup_and_exit 0