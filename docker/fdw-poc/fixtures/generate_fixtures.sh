#!/usr/bin/env bash
# Generates tiny CSV/JSONL/Parquet fixture objects and uploads them to fakecloud S3 for
# the disposable FDW PoC. Run from the host (or any shell with network access to
# the fakecloud host port). Not part of the Rails application; deleted at Gate 2c.
# See docs/experiments/postgres-s3-fdw-poc.md for the full runbook.
#
# Requires: bash, an S3-compatible `aws` CLI, and (optionally) the `duckdb` CLI to
# generate the Parquet fixture.
set -euo pipefail

: "${OBJECT_STORAGE_ENDPOINT:?set to the fakecloud S3 endpoint reachable from this shell, e.g. http://127.0.0.1:4566}"
: "${OBJECT_STORAGE_ACCESS_KEY_ID:?must be set}"
: "${OBJECT_STORAGE_SECRET_ACCESS_KEY:?must be set}"
FDW_POC_BUCKET="${FDW_POC_BUCKET:-fdw-poc-bucket}"

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

cat > "${workdir}/sample.csv" <<'CSV'
id,name,amount
1,alpha,10.50
2,beta,20.25
3,gamma,30.00
CSV

cat > "${workdir}/sample.jsonl" <<'JSONL'
{"id": 1, "name": "alpha", "amount": 10.50}
{"id": 2, "name": "beta", "amount": 20.25}
{"id": 3, "name": "gamma", "amount": 30.00}
JSONL

if command -v duckdb >/dev/null 2>&1; then
  duckdb -c "COPY (SELECT * FROM read_csv_auto('${workdir}/sample.csv')) TO '${workdir}/sample.parquet' (FORMAT PARQUET);"
else
  echo "duckdb CLI not found (https://duckdb.org/docs/installation/)." >&2
  echo "Generate ${workdir}/sample.parquet with an equivalent tool (e.g. Python pyarrow)" >&2
  echo "and re-run with SKIP_GENERATE=1, or install duckdb and re-run without it." >&2
  if [ "${SKIP_GENERATE:-0}" != "1" ]; then
    exit 1
  fi
fi

export AWS_ACCESS_KEY_ID="${OBJECT_STORAGE_ACCESS_KEY_ID}"
export AWS_SECRET_ACCESS_KEY="${OBJECT_STORAGE_SECRET_ACCESS_KEY}"
export AWS_DEFAULT_REGION="us-east-1"

aws --endpoint-url "${OBJECT_STORAGE_ENDPOINT}" s3 mb "s3://${FDW_POC_BUCKET}" || true
aws --endpoint-url "${OBJECT_STORAGE_ENDPOINT}" s3 cp "${workdir}/sample.csv" "s3://${FDW_POC_BUCKET}/fixtures/sample.csv"
aws --endpoint-url "${OBJECT_STORAGE_ENDPOINT}" s3 cp "${workdir}/sample.jsonl" "s3://${FDW_POC_BUCKET}/fixtures/sample.jsonl"
if [ -f "${workdir}/sample.parquet" ]; then
  aws --endpoint-url "${OBJECT_STORAGE_ENDPOINT}" s3 cp "${workdir}/sample.parquet" "s3://${FDW_POC_BUCKET}/fixtures/sample.parquet"
fi

echo "Fixtures uploaded to s3://${FDW_POC_BUCKET}/fixtures/"
