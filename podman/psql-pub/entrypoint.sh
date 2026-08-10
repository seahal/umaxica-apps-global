#!/bin/bash

set -euo pipefail

# Cluster-level objects the replica and pg_cron depend on.
#
# These used to live in /docker-entrypoint-initdb.d, which PostgreSQL's own
# entrypoint runs only when it initialises an empty PGDATA. A volume created
# before one of the objects was added therefore never received it, and nothing
# reported the gap -- the replica just failed pg_basebackup on every start and
# restarted forever. Applying them idempotently on every start keeps a
# long-lived volume and a fresh one in the same state, so `down`/`build`/`up`
# without discarding `primary-data` converges instead of drifting.

: "${POSTGRES_USER:?POSTGRES_USER is required}"
: "${POSTGRES_DB:?POSTGRES_DB is required}"
: "${POSTGRES_REPLICATION_USER:?POSTGRES_REPLICATION_USER is required}"
POSTGRES_PASSWORD_VALUE="$(<"${POSTGRES_PASSWORD_FILE:?POSTGRES_PASSWORD_FILE is required}")"
POSTGRES_REPLICATION_PASSWORD="$(<"${POSTGRES_REPLICATION_PASSWORD_FILE:?POSTGRES_REPLICATION_PASSWORD_FILE is required}")"

REPLICATION_SLOT_NAME="replication_slot_slave1"
# The postgres OS account's home, not PGDATA: this file has to live on the
# container filesystem so it is rewritten from the secret on every start.
POSTGRES_HOME="/var/lib/postgresql"

wait_for_local_server() {
	local attempts=120 attempt
	for ((attempt = 1; attempt <= attempts; attempt++)); do
		if PGPASSWORD="${POSTGRES_PASSWORD_VALUE}" pg_isready \
			-h 127.0.0.1 -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" >/dev/null 2>&1; then
			return 0
		fi
		sleep 1
	done
	echo "primary did not accept TCP connections within ${attempts}s" >&2
	return 1
}

ensure_cluster_objects() {
	PGPASSWORD="${POSTGRES_PASSWORD_VALUE}" psql \
		-v ON_ERROR_STOP=1 \
		-h 127.0.0.1 \
		-v replication_user="${POSTGRES_REPLICATION_USER}" \
		-v replication_password="${POSTGRES_REPLICATION_PASSWORD}" \
		-v slot_name="${REPLICATION_SLOT_NAME}" \
		--username "${POSTGRES_USER}" \
		--dbname "${POSTGRES_DB}" <<-'EOSQL'
		-- psql does not interpolate :variables inside dollar-quoted bodies, so
		-- these stay as plain statements rather than a DO block.
		SELECT format('CREATE ROLE %I WITH REPLICATION LOGIN', :'replication_user')
		WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'replication_user')
		\gexec
		-- Unconditional, so a rotated secret reaches the role instead of leaving
		-- the replica authenticating with a stale password.
		ALTER ROLE :"replication_user" WITH REPLICATION LOGIN ENCRYPTED PASSWORD :'replication_password';
		SELECT format('SELECT pg_create_physical_replication_slot(%L)', :'slot_name')
		WHERE NOT EXISTS (SELECT 1 FROM pg_replication_slots WHERE slot_name = :'slot_name')
		\gexec
		CREATE EXTENSION IF NOT EXISTS pg_cron;
	EOSQL
}

# pg_cron's job-execution connections are ordinary TCP client connections to
# cron.host (default: localhost) authenticating as the job's owning role, not a
# privileged in-process call -- they go through the same scram-sha-256-only
# pg_hba.conf as any other client. Without a credential source, every scheduled
# job fails with "connection failed" even though the launcher itself runs fine.
# Local-only workaround: Aurora PostgreSQL does not expose OS-level file access,
# so this specific mechanism does not carry over and must be re-verified there.
write_cron_pgpass() {
	local pgpass="${POSTGRES_HOME}/.pgpass"
	printf '%s\n' "localhost:5432:${POSTGRES_DB}:${POSTGRES_USER}:${POSTGRES_PASSWORD_VALUE}" >"${pgpass}"
	chmod 600 "${pgpass}"
	chown postgres:postgres "${pgpass}"
}

{
	if wait_for_local_server && ensure_cluster_objects; then
		echo "primary cluster objects are provisioned"
	else
		# Leaving the server up would hand the replica another silent
		# basebackup failure loop, so stop it and let the restart policy retry.
		echo "FATAL: could not provision primary cluster objects; stopping the server" >&2
		kill -TERM 1 || true
	fi
} &

write_cron_pgpass

exec /usr/local/bin/docker-entrypoint.sh "$@"
