#!/bin/bash

# Configuration variables
BACKUP_DIR="/backups"          # Directory visible outside the container
DATA_DIRS=("/backend-public" "/backend-private")  # List of directories with the files
DB_NAME="${TICKETZ_DB_NAME-ticketz}"           # Database name
DB_USER="${TICKETZ_DB_USER-ticketz}"           # Database user
DB_HOST="${TICKETZ_DB_HOST-postgres}"          # Database host
DB_PORT="${TICKETZ_DB_PORT-5432}"              # Database port
TIMESTAMP=$(date +"%Y%m%d%H%M%S")
BACKUP_FILE="$BACKUP_DIR/backup-$TIMESTAMP.tar.gz"
RETENTION_FILES=${RETENTION_FILES-7}           # Number of files to keep

# Database and folders backup function
backup() {
    echo "Starting backup..."

    # Postgres database dump
    pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$DB_NAME" > "$BACKUP_DIR/db_dump.sql"

    # Compress database and all data folders
    tar -czf "$BACKUP_FILE" "$BACKUP_DIR/db_dump.sql" $(printf " %s" "${DATA_DIRS[@]}")

    # Remove the sql dump after compressing
    rm "$BACKUP_DIR/db_dump.sql"

    echo "Backup completed: $BACKUP_FILE"

    # Cleanup of old backups
    cleanup
}

# Function to restore the database and files
restore() {
    echo "Starting restoration..."

    # Restore files from the last backup
    tar -xzf $(ls -t $BACKUP_DIR/*.tar.gz | head -n 1) -C /

    # Check if the database is empty
    DB_COUNT=$(psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';")

    if [ "$DB_COUNT" -eq 0 ]; then
        echo "Restoring database..."
        psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" < "$BACKUP_DIR/db_dump.sql"
    else
        echo "The database already has tables."
    fi

    echo "Restoration completed."
}

# Function for cleanup of old backups
cleanup() {
    echo "Running cleanup of old backups..."

    # List all backup files, sort by modification time, and remove files exceeding the retention limit
    ls -t $BACKUP_DIR/*.tar.gz | tail -n +$(($RETENTION_FILES + 1)) | /usr/bin/xargs -d '\n' rm -f --

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
