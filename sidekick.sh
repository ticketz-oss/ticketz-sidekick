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

BASEDIR=${PWD}

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
    tar -xzf $(ls -t ${BACKUP_DIR}/${BACKUP_BASENAME}-*.tar.gz | head -n 1) -C / || exit 1

    echo "Restoring database..."
    psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DB_NAME}" -q < "${BACKUP_DIR}/db_dump.sql" &> /dev/null || exit 1

    echo "Restoration completed."
}


# Function to retrieve specified tables and fields from a second database
retrieve() {
    if [ -z "$3" ]; then
        echo -e "\nSyntax:\n\n\t$0 retrieve <dbhost> <dbname> <dbuser> [dbpass] [outputfolder]\n\n"
        exit 1
    fi

    SECOND_DB_HOST=$1
    SECOND_DB_NAME=$2
    SECOND_DB_USER=$3
    SECOND_DB_PASS=$4
    OUTPUT_DIR="${5-/retrieve}"  # Directory to store the CSV files
    ARCHIVE_NAME="retrieved_data.tar.gz" # Name of the final tar.gz file


    # Load tables and field lists if not defined
    . "${BASEDIR}/retrieve-tables.sh"

    # Ensure the output directory exists
    mkdir -p "$OUTPUT_DIR"

    # Loop over each table and generate \COPY command for each
    for key in "${!RETRIEVE_TABLES[@]}"; do
        # Get the fields for the current table
        fields=${RETRIEVE_TABLES[$key]}

        # Extract the table name from the key by removing the prefix
        table=${key#*-}

        # Define the output file with the counter and table name (e.g., 001-users.csv, 002-orders.csv)
        output_file="$OUTPUT_DIR/${key}.csv"

        # Generate the \COPY command to export the table with the selected fields to CSV
        echo "Exporting table '$table'"
        PGPASSWORD="${SECOND_DB_PASS}" psql -h "${SECOND_DB_HOST}" -U "${SECOND_DB_USER}" -d "${SECOND_DB_NAME}" -c "\COPY (SELECT $fields FROM \"$table\") TO '$output_file' WITH CSV HEADER" &> "${output_file}.log"

        if [ $? -gt 0 ]; then
           echo "Error exporting $table: "
           cat "${output_file}.log"
           exit 1
        fi
 
        rm "${output_file}.log"


        # Check if the export was successful
        if [[ $? -eq 0 ]]; then
            echo "Table '$table' exported successfully to $output_file."
        else
            echo "Error exporting table '$table'."
        fi
    done

    # After all exports are done, create a tar.gz archive with all CSV files
    echo "Creating tar.gz archive with all CSV files..."
    cd "$OUTPUT_DIR"
    
    tar -czf "$ARCHIVE_NAME" *.csv

    # Check if the tar.gz creation was successful
    if [[ $? -eq 0 ]]; then
        echo "Archive '$ARCHIVE_NAME' created successfully in $OUTPUT_DIR."
        rm *.csv
    else
        echo "Error creating archive."
    fi
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
    retrieve)
        shift
        retrieve $*
        ;;
    *)
        echo "Unrecognized command. Use 'backup', 'restore' or 'retrieve'."
        exit 1
        ;;
esac
