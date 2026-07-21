-- Disposable FDW PoC smoke checks. Read-only. See
-- docs/experiments/postgres-s3-fdw-poc.md for the full runbook and how to record
-- results. Deleted at Gate 2c along with every object created here.
--
-- Run inside the fdw-poc container, e.g.:
--   podman compose -f compose.yaml -f docker/fdw-poc/compose.fdw-poc.yml \
--     --profile object-storage --profile fdw-poc \
--     exec -T fdw-poc psql -U fdw_poc -d fdw_poc -v ON_ERROR_STOP=0 \
--     -f /dev/stdin < docker/fdw-poc/smoke/run_smoke_checks.sql | tee smoke-results.txt
--
-- Before running: replace CHANGEME_ACCESS_KEY / CHANGEME_SECRET_KEY with the same
-- OBJECT_STORAGE_ACCESS_KEY_ID / OBJECT_STORAGE_SECRET_ACCESS_KEY used for
-- generate_fixtures.sh, and confirm the CREATE SERVER / CREATE USER MAPPING option
-- names against the pinned Wrappers version's S3 FDW reference (some releases use
-- Vault-based credential storage instead of plain user-mapping options).

\timing on

-- === 0. Extension, server, user mapping ====================================
\echo '--- 0. extension / server / user mapping ---'
CREATE EXTENSION IF NOT EXISTS wrappers;

CREATE FOREIGN DATA WRAPPER IF NOT EXISTS s3_wrapper
  HANDLER s3_fdw_handler
  VALIDATOR s3_fdw_validator;

CREATE SERVER IF NOT EXISTS fdw_poc_rustfs
  FOREIGN DATA WRAPPER s3_wrapper
  OPTIONS (
    aws_region 'us-east-1',
    endpoint_url 'http://rustfs:9000'
  );

CREATE USER MAPPING IF NOT EXISTS FOR fdw_poc
  SERVER fdw_poc_rustfs
  OPTIONS (
    access_key_id 'CHANGEME_ACCESS_KEY',
    secret_access_key 'CHANGEME_SECRET_KEY'
  );

-- A second server + user mapping with a deliberately wrong secret, for the
-- invalid-credential check in section 4.
CREATE SERVER IF NOT EXISTS fdw_poc_rustfs_bad_creds
  FOREIGN DATA WRAPPER s3_wrapper
  OPTIONS (
    aws_region 'us-east-1',
    endpoint_url 'http://rustfs:9000'
  );

CREATE USER MAPPING IF NOT EXISTS FOR fdw_poc
  SERVER fdw_poc_rustfs_bad_creds
  OPTIONS (
    access_key_id 'CHANGEME_ACCESS_KEY',
    secret_access_key 'deliberately-wrong-secret'
  );

-- === 1. CSV =================================================================
\echo '--- 1. CSV: foreign table ---'
CREATE FOREIGN TABLE IF NOT EXISTS fdw_poc_csv (
  id integer,
  name text,
  amount numeric
) SERVER fdw_poc_rustfs
OPTIONS (
  uri 's3://fdw-poc-bucket/fixtures/sample.csv',
  format 'csv',
  has_header 'true'
);

\echo '--- 1a. CSV: SELECT * ---'
SELECT * FROM fdw_poc_csv ORDER BY id;

\echo '--- 1b. CSV: projection ---'
SELECT name FROM fdw_poc_csv ORDER BY id;

\echo '--- 1c. CSV: filter ---'
SELECT * FROM fdw_poc_csv WHERE amount > 15 ORDER BY id;

\echo '--- 1d. CSV: COUNT ---'
SELECT count(*) FROM fdw_poc_csv;

-- === 2. JSON Lines ===========================================================
\echo '--- 2. JSONL: foreign table ---'
CREATE FOREIGN TABLE IF NOT EXISTS fdw_poc_jsonl (
  id integer,
  name text,
  amount numeric
) SERVER fdw_poc_rustfs
OPTIONS (
  uri 's3://fdw-poc-bucket/fixtures/sample.jsonl',
  format 'jsonl'
);

\echo '--- 2a. JSONL: SELECT * ---'
SELECT * FROM fdw_poc_jsonl ORDER BY id;

\echo '--- 2b. JSONL: projection ---'
SELECT name FROM fdw_poc_jsonl ORDER BY id;

\echo '--- 2c. JSONL: filter ---'
SELECT * FROM fdw_poc_jsonl WHERE amount > 15 ORDER BY id;

\echo '--- 2d. JSONL: COUNT ---'
SELECT count(*) FROM fdw_poc_jsonl;

-- === 3. Parquet ==============================================================
\echo '--- 3. Parquet: foreign table ---'
CREATE FOREIGN TABLE IF NOT EXISTS fdw_poc_parquet (
  id integer,
  name text,
  amount numeric
) SERVER fdw_poc_rustfs
OPTIONS (
  uri 's3://fdw-poc-bucket/fixtures/sample.parquet',
  format 'parquet'
);

\echo '--- 3a. Parquet: SELECT * ---'
SELECT * FROM fdw_poc_parquet ORDER BY id;

\echo '--- 3b. Parquet: projection ---'
SELECT name FROM fdw_poc_parquet ORDER BY id;

\echo '--- 3c. Parquet: filter ---'
SELECT * FROM fdw_poc_parquet WHERE amount > 15 ORDER BY id;

\echo '--- 3d. Parquet: COUNT ---'
SELECT count(*) FROM fdw_poc_parquet;

-- === 4. Failure-mode checks ==================================================
\echo '--- 4a. missing object (expect a clear error, not silent empty result) ---'
CREATE FOREIGN TABLE IF NOT EXISTS fdw_poc_missing (
  id integer,
  name text,
  amount numeric
) SERVER fdw_poc_rustfs
OPTIONS (
  uri 's3://fdw-poc-bucket/fixtures/does-not-exist.csv',
  format 'csv',
  has_header 'true'
);
SELECT * FROM fdw_poc_missing;

\echo '--- 4b. invalid credentials (expect an authentication error) ---'
CREATE FOREIGN TABLE IF NOT EXISTS fdw_poc_bad_creds (
  id integer,
  name text,
  amount numeric
) SERVER fdw_poc_rustfs_bad_creds
OPTIONS (
  uri 's3://fdw-poc-bucket/fixtures/sample.csv',
  format 'csv',
  has_header 'true'
);
SELECT * FROM fdw_poc_bad_creds;

\echo '--- 4c. schema mismatch: declared column type conflicts with the CSV data ---'
CREATE FOREIGN TABLE IF NOT EXISTS fdw_poc_schema_mismatch (
  id integer,
  name text,
  amount integer -- sample.csv has fractional amounts (10.50); this type is wrong on purpose
) SERVER fdw_poc_rustfs
OPTIONS (
  uri 's3://fdw-poc-bucket/fixtures/sample.csv',
  format 'csv',
  has_header 'true'
);
SELECT * FROM fdw_poc_schema_mismatch;

\echo '--- 4d. schema mismatch: declared column that does not exist in the CSV header ---'
CREATE FOREIGN TABLE IF NOT EXISTS fdw_poc_missing_column (
  id integer,
  name text,
  amount numeric,
  currency text -- not present in sample.csv
) SERVER fdw_poc_rustfs
OPTIONS (
  uri 's3://fdw-poc-bucket/fixtures/sample.csv',
  format 'csv',
  has_header 'true'
);
SELECT * FROM fdw_poc_missing_column;

\echo '--- done: record every result (including errors verbatim) in the findings doc ---'
