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
