#!/bin/bash

# ====================================================================================
# Automated Backup Script
#
# Description: A robust script that creates versioned backups from an external
#              config file, provides detailed logging, handles errors, manages
#              concurrency with a lock file, and sends email notifications.
#
# ====================================================================================

set -o errexit  # Exit immediately if a command exits with a non-zero status.
set -o nounset  # Treat unset variables as an error when substituting.
set -o pipefail # Return value of a pipeline is the value of the last command to exit with a non-zero status.

# --- GLOBAL VARIABLES ---
readonly SCRIPT_NAME=$(basename "$0")
readonly LOG_DIR="/var/log/backup_script"
readonly LOG_FILE="${LOG_DIR}/backup.log"
readonly LOCK_FILE="/var/run/${SCRIPT_NAME}.lock"
readonly HOME_DIR="/home/subaru/Linux_Projects/Backup_Script"
readonly CONFIG_FILE="${HOME_DIR}/backup.conf"

# --- LOGGING AND ERROR HANDLING ---

# Function to log messages with a timestamp.
log_message() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ${message}" | sudo tee -a "${LOG_FILE}"
}

# Function to handle errors, log them, and clean up.
handle_error() {
    local exit_code=$?
    local line_number=$1
    log_message "ERROR: Script failed on line ${line_number} with exit code ${exit_code}."
    
    # Send failure email notification
    if [[ "${ENABLE_EMAIL_NOTIFICATIONS:-no}" == "yes" && -n "${EMAIL_RECIPIENT:-}" ]]; then
        local subject="❌ Backup FAILED on $(hostname)"
        local body="The backup script encountered a critical error on line ${line_number}. Please check the log file for details: ${LOG_FILE}"
        send_email_notification "$subject" "$body"
    fi

    cleanup
    exit "${exit_code}"
}

# Function to send email notifications using ssmtp
send_email_notification() {
    local subject="$1"
    local body="$2"
    
    if ! command -v ssmtp &> /dev/null; then
        log_message "WARNING: 'ssmtp' command not found. Cannot send email notification."
        return
    fi

    log_message "Sending email notification to ${EMAIL_RECIPIENT}."
    (
        echo "To: ${EMAIL_RECIPIENT}"
        echo "From: $(hostname)-backup-script"
        echo "Subject: ${subject}"
        echo
        echo "${body}"
    ) | ssmtp "${EMAIL_RECIPIENT}"
}


# Function to clean up the lock file on exit.
cleanup() {
    if ! rm -f "${LOCK_FILE}"; then
        log_message "WARNING: Could not remove lock file: ${LOCK_FILE}."
    fi
    log_message "Cleanup complete. Script finished."
}

# Trap errors and call the handle_error function, passing the line number.
trap 'handle_error $LINENO' ERR
trap cleanup EXIT

# --- SCRIPT LOGIC ---

# Main function to orchestrate the backup process.
main() {
    local start_time
    start_time=$(date +%s)

    # 0. Create log directory if it doesn't exist.
    sudo mkdir -p "${LOG_DIR}"
    sudo touch "${LOG_FILE}"
    sudo chown root:root "${LOG_DIR}" "${LOG_FILE}"
    sudo chmod 640 "${LOG_FILE}"

    log_message "================== Backup Script Started =================="

    # 1. Source the configuration file
    if [[ -f "${CONFIG_FILE}" ]]; then
        source "${CONFIG_FILE}"
        log_message "Successfully loaded configuration from ${CONFIG_FILE}."
    else
        log_message "CRITICAL: Configuration file not found at ${CONFIG_FILE}. Exiting."
        exit 1
    fi

    # 2. Check for root privileges.
    if [[ "${EUID}" -ne 0 ]]; then
        log_message "CRITICAL: This script must be run as root. Please use sudo. Exiting."
        exit 1
    fi



    # 3. Check for and handle existing lock file.
    if [[ -e "${LOCK_FILE}" ]]; then
        log_message "WARNING: Lock file exists: ${LOCK_FILE}. Another instance may be running. Exiting."
        exit 1
    else
        touch "${LOCK_FILE}"
    fi

    # 4. Validate that source directories exist.
    for src in "${SOURCES_TO_BACKUP[@]}"; do
        if [[ ! -d "${src}" ]]; then
            log_message "CRITICAL: Source directory '${src}' does not exist. Exiting."
            exit 1
        fi
    done
    log_message "All source directories verified."

    # 5. Create backup destination directory.
    local timestamp
    timestamp=$(date +%Y%m%d%H%M%S)
    local current_backup_dir="${BACKUP_DESTINATION_ROOT}/${timestamp}"
    mkdir -p "${current_backup_dir}"
    log_message "Created backup directory: ${current_backup_dir}"

    # 6. Create the compressed tarball archive.
    local archive_filename="backup-${timestamp}.tar.gz"
    local final_archive_path="${current_backup_dir}/${archive_filename}"
    log_message "Creating archive: ${final_archive_path}..."
    tar -cpzf "${final_archive_path}" "${SOURCES_TO_BACKUP[@]}"
    log_message "Archive created successfully."

    # 7. Verify the archive's integrity.
    log_message "Verifying archive integrity..."
    if gzip -t "${final_archive_path}"; then
        log_message "SUCCESS: Archive integrity check passed."
    else
        log_message "CRITICAL: Archive is corrupt! Backup failed."
        exit 1
    fi
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local archive_size
    archive_size=$(du -sh "${final_archive_path}" | awk '{print $1}')

    log_message "Backup completed in ${duration} seconds. Archive size: ${archive_size}."
    
    # 8. Send success email
    if [[ "${ENABLE_EMAIL_NOTIFICATIONS}" == "yes" ]]; then
        local subject="✅ Backup SUCCESSFUL on $(hostname)"
        local body
        body=$(cat <<-EOF
		Backup process completed successfully.

		Summary:
		- Hostname: $(hostname)
		- Archive Path: ${final_archive_path}
		- Archive Size: ${archive_size}
		- Duration: ${duration} seconds
		- Log File: ${LOG_FILE}
		EOF
		)
        send_email_notification "$subject" "$body"
    fi

    # 9. Clean up old backups based on retention policy.
    if [[ ${RETENTION_DAYS} -gt 0 ]]; then
        log_message "Cleaning up backups older than ${RETENTION_DAYS} days..."
        find "${BACKUP_DESTINATION_ROOT}" -mindepth 1 -maxdepth 1 -type d -mtime "+${RETENTION_DAYS}" -exec rm -rf {} \;
        log_message "Cleanup of old backups complete."
    fi
}

# Execute the main function.
main

