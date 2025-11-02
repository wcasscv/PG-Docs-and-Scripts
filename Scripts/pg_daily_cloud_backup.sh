#!/bin/bash
# PostgreSQL Daily Backup and Upload to Cloud Storage

# === CONFIGURATION ===
PGUSER="postgres"
PGDB="mydatabase"
BACKUP_DIR="/tmp/pg_backups"
DATE=$(date +%F)
FILENAME="${PGDB}_backup_${DATE}.dump"

# === Ensure backup directory exists ===
mkdir -p "$BACKUP_DIR"

# === Create PostgreSQL backup ===
pg_dump -U $PGUSER -F c -f "$BACKUP_DIR/$FILENAME" $PGDB

# === Upload to AWS S3 ===
# aws s3 cp "$BACKUP_DIR/$FILENAME" s3://your-s3-bucket-name/postgres-backups/

# === Upload to Google Cloud Storage (GCS) ===
# gsutil cp "$BACKUP_DIR/$FILENAME" gs://your-gcs-bucket-name/postgres-backups/

# === Upload to Azure Blob Storage ===
# az storage blob upload --account-name <your_storage_account> --container-name <your_container> --name "postgres-backups/$FILENAME" --file "$BACKUP_DIR/$FILENAME" --auth-mode login

# === Cleanup old backups (optional) ===
# find "$BACKUP_DIR" -type f -mtime +7 -name "*.dump" -exec rm {} \;

echo "✅ Backup completed and uploaded: $FILENAME"
