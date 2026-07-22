#!/bin/bash

set -e

PGPASSWORD="${POSTGRES_PASSWORD}" psql \
  -v ON_ERROR_STOP=1 \
  -v replication_user="${POSTGRES_REPLICATION_USER}" \
  -v replication_password="${POSTGRES_REPLICATION_PASSWORD}" \
  --username "$POSTGRES_USER" \
  --dbname "$POSTGRES_DB" <<-EOSQL
  CREATE USER :"replication_user" WITH REPLICATION ENCRYPTED PASSWORD :'replication_password';
  SELECT * FROM pg_create_physical_replication_slot('replication_slot_slave1');
  CREATE EXTENSION IF NOT EXISTS pg_cron;
EOSQL

# pg_cron's own job-execution connections are ordinary TCP client connections
# to cron.host (default: localhost) authenticating as the job's owning role,
# not a privileged in-process call -- they go through the same
# scram-sha-256-only pg_hba.conf as any other client. Without a credential
# source, every scheduled job fails with "connection failed" even though the
# launcher itself runs fine. Give the OS user running the launcher a .pgpass
# so job execution can authenticate. Local-only workaround: Aurora PostgreSQL
# does not expose OS-level file access, so this specific mechanism does not
# carry over to Aurora and must be re-verified there separately.
cat > "${HOME}/.pgpass" <<-EOF
localhost:5432:${POSTGRES_DB}:${POSTGRES_USER}:${POSTGRES_PASSWORD}
EOF
chmod 600 "${HOME}/.pgpass"
