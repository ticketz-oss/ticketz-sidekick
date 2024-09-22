#!/bin/bash

# Configuration variables
BACKUP_DIR="/backups"          # Directory visible outside the container
DATA_DIRS=("/backend-public" "/backend-private")  # List of directories with the files
DB_NAME="${DB_NAME-ticketz}"           # Database name
DB_USER="${DB_USER-ticketz}"           # Database user
DB_HOST="${DB_HOST-postgres}"          # Database host
DB_PORT="${DB_PORT-5432}"              # Database port
TIMESTAMP=$(date +"%Y%m%d%H%M%S")
BACKUP_BASENAME="ticketz-backup"
BACKUP_FILE="${BACKUP_DIR}/${BACKUP_BASENAME}-${TIMESTAMP}.tar.gz"
RETENTION_FILES=${RETENTION_FILES-7}           # Number of files to keep

# Wait for progress to be available
wait_for_postgres() {
    for i in {1..30}
    do
        if psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" -c '\q' -q; then
            echo "Postgres is up - executing command"
			return
        else
            echo "Postgres is unavailable - sleeping"
            sleep 1
        fi
    done

    echo "Postgres is still unavailable after 30 seconds - exiting"
    exit 1
}

# Database and folders backup function
backup() {
    # Wait for Postgres to become available
    wait_for_postgres

    echo "Starting backup..."

    # Postgres database dump
    pg_dump -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" "${DB_NAME}" > "${BACKUP_DIR}/db_dump.sql"

    # Compress database and all data folders
    tar -czf "${BACKUP_FILE}" "${BACKUP_DIR}/db_dump.sql" $(printf " %s" "${DATA_DIRS[@]}")

    # Remove the sql dump after compressing
    rm "${BACKUP_DIR}/db_dump.sql"

    echo "Backup completed: ${BACKUP_FILE}"

    # Cleanup of old backups
    cleanup
}

# Function to restore the database and files
restore() {
    # Check if there are backup files
    if [ -z "$(ls -A ${BACKUP_DIR}/${BACKUP_BASENAME}-*.tar.gz 2>/dev/null)" ]; then
        echo "No backup files found. Exiting."
        exit 1
    fi

    # Wait for Postgres to become available
    wait_for_postgres

    # Check if the database is empty
    DB_COUNT=$(psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';" -q)

    if [ "${DB_COUNT}" -gt 0 ]; then
        echo "The database already has tables. Will not restore."
        return
    fi

    # Check if the directories are empty
    for dir in "${DATA_DIRS[@]}"; do
        if [ "$(ls -A ${dir})" ]; then
            echo "Directory ${dir} is not empty. Will not restore."
            return
        fi
    done

    echo "Starting restoration..."

    # Restore files from the last backup
    tar -xzf $(ls -t ${BACKUP_DIR}/${BACKUP_BASENAME}-*.tar.gz | head -n 1) -C /

    echo "Restoring database..."
    psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" -q < "${BACKUP_DIR}/db_dump.sql"

    echo "Restoration completed."
}

# Function for cleanup of old backups
cleanup() {
    echo "Running cleanup of old backups..."

    # List all backup files, sort by modification time, and remove files exceeding the retention limit
    ls -t ${BACKUP_DIR}/${BACKUP_BASENAME}-*.tar.gz | tail -n +$((${RETENTION_FILES} + 1)) | /usr/bin/xargs -d '\n' rm -f --

    echo "Cleanup completed."
}

# Choice of operation according to the passed command
case "$1" in
    backup)
        backup
        ;;
    restore)
        restore
        ;;
    *)
        echo "Unrecognized command. Use 'backup' or 'restore'."
        exit 1
        ;;
esac
