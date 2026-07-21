# Local RustFS Object Storage

RustFS is an opt-in local development dependency. It provides an S3-compatible endpoint for
explicit integration tasks; normal Rails startup and the regular test suite do not require it.
There is no object-storage data migration because the previous references were unused historical
configuration.

## Architecture

```text
Rails core container
    |  S3-compatible API (http://rustfs:9000)
RustFS container (UID/GID 10001:10001)
    |
Four persistent Podman named volumes
```

The `rustfs-permissions` helper uses the fixed `alpine:3.24.1` image to set ownership on the four
volume roots. RustFS starts only after that idempotent helper succeeds. The volumes intentionally
remain separate so a later erasure-coded bucket-versioning evaluation has the required disk
layout.

## Configure

Copy the development examples from `.env.example` into the ignored `.env` file. Replace both
secret examples and keep `RUSTFS_RPC_SECRET` different from
`OBJECT_STORAGE_SECRET_ACCESS_KEY`. These values are only for local development; production must
use its platform credential provider and must not set a RustFS endpoint override.

All commands below use the base Compose file and the devcontainer override:

```sh
COMPOSE="podman compose -f compose.yaml -f .devcontainer/compose.override.yml"
```

The shell variable is only a documentation shorthand. If the Compose provider does not accept a
command stored in a variable, write the full `podman compose -f ...` prefix instead.

## Linux Host Gate

First confirm that the normal Compose project remains independent of object storage. An explicit
empty env file prevents a developer's `.env` from satisfying this negative gate accidentally:

```sh
env -u OBJECT_STORAGE_BUCKET \
  -u OBJECT_STORAGE_ACCESS_KEY_ID \
  -u OBJECT_STORAGE_SECRET_ACCESS_KEY \
  -u RUSTFS_RPC_SECRET \
  $COMPOSE --env-file /dev/null config
```

Then require the local profile variables in the host shell and validate the enabled profile:

```sh
: "${OBJECT_STORAGE_BUCKET:?must be set}"
: "${OBJECT_STORAGE_ACCESS_KEY_ID:?must be set}"
: "${OBJECT_STORAGE_SECRET_ACCESS_KEY:?must be set}"
: "${RUSTFS_RPC_SECRET:?must be set}"
$COMPOSE --profile object-storage config
```

Compose interpolation deliberately permits empty object-storage values. The RustFS container
entrypoint and the Rails tasks enforce required non-empty values only when those operations run.
This keeps the normal profile usable without object-storage credentials.

Start the optional profile:

```sh
$COMPOSE --profile object-storage up -d rustfs
$COMPOSE --profile object-storage ps rustfs
$COMPOSE --profile object-storage logs rustfs-permissions rustfs
```

The Compose healthcheck covers the S3 API readiness endpoint. Check the S3 API and console
independently from the host:

```sh
curl --fail --silent --show-error http://127.0.0.1:${RUSTFS_API_HOST_PORT:-9000}/health/ready
curl --fail --silent --show-error http://127.0.0.1:${RUSTFS_CONSOLE_HOST_PORT:-9001}/rustfs/console/health
```

## Prepare the Bucket and Run the Rails Smoke Test

Run both operations inside the Rails container so service-name DNS, credentials, and the internal
endpoint are exercised:

```sh
$COMPOSE --profile object-storage exec -T core bin/rails object_storage:prepare
$COMPOSE --profile object-storage exec -T core bin/rails object_storage:smoke
```

The prepare task treats an existing bucket as success. The smoke task writes a unique
`smoke/<uuid>` object, checks its size and body, deletes it, and verifies that it no longer exists.
Unexpected S3 errors are not suppressed and produce a non-zero command exit.

## Stop or Reset

Stop RustFS while retaining all data volumes:

```sh
$COMPOSE --profile object-storage stop rustfs
```

Stop the complete Compose project while retaining named volumes:

```sh
$COMPOSE --profile object-storage down
```

To completely reset the Compose project, including the four RustFS volumes, run:

```sh
$COMPOSE --profile object-storage down --volumes
```

The last command is destructive: it removes every named volume belonging to this Compose project,
not only RustFS data. It also removes local database, Valkey, observability, and dependency-cache
volumes managed by the same project.

## Deferred Compatibility Work

This local gate does not validate IAM roles, KMS, detailed bucket policies, presigned URL edge
cases, multipart-upload boundaries, Amazon S3 checksum behavior, version IDs, or delete markers.
FDW, Aurora PostgreSQL integration, production Amazon S3 configuration, a database object-reference
model, full bucket-versioning validation, and tests against Amazon S3 are intentionally deferred.
