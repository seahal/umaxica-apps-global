#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "${SCRIPT_DIR}/.."

echo "🔧 Setting up databases..."

# Wait for PostgreSQL to be ready
max_attempts=30
attempt=0

until PGPASSWORD=${POSTGRESQL_PASSWORD} psql -h primary -U ${POSTGRESQL_USER} -d postgres -c '\q' 2>/dev/null; do
  attempt=$((attempt + 1))
  if [ $attempt -ge $max_attempts ]; then
    echo "❌ PostgreSQL failed to become ready after $max_attempts attempts"
    exit 1
  fi
  echo "⏳ Waiting for PostgreSQL... (attempt $attempt/$max_attempts)"
  sleep 2
done

echo "✅ PostgreSQL is ready!"

# Create and migrate databases (idempotent)
# db:prepare will create databases if they don't exist and run migrations
echo "📦 Preparing all databases..."

# Set REGION_CODE for database operations
export REGION_CODE=${REGION_CODE:-all}

# Run db:prepare which is idempotent (safe to run multiple times)
RAILS_ENV=development bin/rails db:prepare || {
  echo "⚠️  db:prepare failed, retrying once..."
  sleep 3
  RAILS_ENV=development bin/rails db:prepare
}

echo "🧩 Enabling pg_cron on prepared databases..."
while IFS= read -r database; do
  [ -n "$database" ] || continue
  PGPASSWORD="${POSTGRESQL_PASSWORD}" psql \
    -h primary \
    -U "${POSTGRESQL_USER}" \
    -d "${database}" \
    -v ON_ERROR_STOP=1 \
    -c 'CREATE EXTENSION IF NOT EXISTS pg_cron;'
done < <(
  PGPASSWORD="${POSTGRESQL_PASSWORD}" psql \
    -h primary \
    -U "${POSTGRESQL_USER}" \
    -d postgres \
    -Atq \
    -c "select datname from pg_database where datallowconn and not datistemplate and datname <> 'postgres' order by 1"
)

echo "✨ All databases are ready!"
echo "   You can now start developing without running db:create manually."
