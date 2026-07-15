#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCHIVE_FILE="${ARCHIVE_FILE:-${SCRIPT_DIR}/db/docugarden.archive}"
DB_CONTAINER="${DB_CONTAINER:-docugarden-db}"

usage() {
  cat <<EOF
Usage: $0 [--drop]

Restore the bundled MongoDB archive into the DocuGarden database.
The database container (${DB_CONTAINER}) must already be running.

Options:
  --drop    Drop existing collections before restoring (destructive).

Environment:
  ARCHIVE_FILE    Path to the MongoDB archive (default: ${ARCHIVE_FILE})
  DB_CONTAINER    Name of the database container (default: ${DB_CONTAINER})
EOF
}

if [ "${1:-}" = "--drop" ]; then
  export SEED_FORCE=1
  shift
elif [ -n "${1:-}" ]; then
  usage >&2
  exit 1
fi

if [ ! -f "$ARCHIVE_FILE" ]; then
  echo "Archive file not found: $ARCHIVE_FILE" >&2
  exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -qx "$DB_CONTAINER"; then
  echo "Database container is not running: $DB_CONTAINER" >&2
  exit 1
fi

echo "Starting archive restore from $ARCHIVE_FILE..."

docker run --rm \
  --network "container:${DB_CONTAINER}" \
  -v "${ARCHIVE_FILE}:/seed-data/archive:ro" \
  -v "${SCRIPT_DIR}/secrets:/secrets:ro" \
  -e SEED_FORCE \
  mongo:7.0 \
  sh -c '
    set -e
    DB=$(cat /secrets/mongodb-database.txt)
    USER=$(cat /secrets/mongodb-username.txt)
    PASS=$(cat /secrets/mongodb-password.txt)
    DROP_FLAG=${SEED_FORCE:+--drop}
    echo "Restoring archive into $DB"
    exec mongorestore \
      --archive=/seed-data/archive \
      --db="$DB" \
      --host="127.0.0.1" \
      --port="27017" \
      --username="$USER" \
      --password="$PASS" \
      --authenticationDatabase=admin \
      $DROP_FLAG
  '
