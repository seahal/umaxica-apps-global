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

Credentials and non-secret settings come from two different places.

`bin/setup-dev-secrets` generates and registers the three credentials as Podman secrets, exactly as
it does for PostgreSQL. No manual step is required:

| Podman secret            | Local source file            | Consumed by                                    |
| ------------------------ | ---------------------------- | ---------------------------------------------- |
| `dev_rustfs_access_key`  | `.secrets/rustfs-access-key` | `rustfs` entrypoint, `core` Rails tasks         |
| `dev_rustfs_secret_key`  | `.secrets/rustfs-secret-key` | `rustfs` entrypoint, `core` Rails tasks         |
| `dev_rustfs_rpc_secret`  | `.secrets/rustfs-rpc-secret` | `rustfs` entrypoint only                        |

Compose mounts them at `/run/secrets/<name>`. The `rustfs` entrypoint reads the files directly, and
the `core` container receives `OBJECT_STORAGE_ACCESS_KEY_ID_FILE` and
`OBJECT_STORAGE_SECRET_ACCESS_KEY_FILE` pointing at the same paths, which
`lib/tasks/object_storage.rake` resolves. A configured `_FILE` path is authoritative: an unreadable
file aborts the task rather than falling back to an inline value.

`rustfs-access-key` is generated as uppercase hexadecimal rather than Base64. SigV4 builds its
credential scope as `<access key>/<date>/<region>/s3/aws4_request`, so a `/` inside the access key
corrupts every signed request. The `rustfs` entrypoint rejects an access key containing `/` at
startup so the failure names its cause instead of surfacing as an opaque 403.

The non-secret settings need no local configuration at all. `OBJECT_STORAGE_BUCKET` is fixed to
`umaxica-local` in the `core` service environment (`compose.yaml`), and the loopback host ports are
fixed to `9000` (S3 API) and `9001` (console) in `compose.yaml`. The ignored
repository-root `.env` carries only the Cloudflare Tunnel token and the host `UID`/`GID` that
`.devcontainer/write-host-ids.sh` writes; it holds no object-storage settings.

These values are only for local development; production must use its platform credential provider
and must not set a RustFS endpoint override.

All commands below use the base Compose file and the developer overlay:

```sh
COMPOSE="podman compose -f compose.yaml -f compose.custom.yaml"
```

The shell variable is only a documentation shorthand. If the Compose provider does not accept a
command stored in a variable, write the full `podman compose -f ...` prefix instead.

## Linux Host Gate

First confirm that the credentials are registered, since both `core` and `rustfs` now mount them
and Compose refuses to start a service whose secret is missing:

```sh
bin/setup-dev-secrets
podman secret ls --format '{{.Name}}' | grep dev_rustfs_
```

Then confirm that the object-storage configuration is self-contained in the Compose files. An
explicit empty env file prevents a developer's `.env` from satisfying this gate accidentally, and
unsetting the former interpolation variables proves nothing still reads them:

```sh
env -u OBJECT_STORAGE_BUCKET -u RUSTFS_API_HOST_PORT -u RUSTFS_CONSOLE_HOST_PORT \
  $COMPOSE --env-file /dev/null config
env -u OBJECT_STORAGE_BUCKET -u RUSTFS_API_HOST_PORT -u RUSTFS_CONSOLE_HOST_PORT \
  $COMPOSE --env-file /dev/null --profile object-storage config
```

The rendered configuration must show `OBJECT_STORAGE_BUCKET: umaxica-local` on `core` and the two
`127.0.0.1:9000` / `127.0.0.1:9001` publications on `rustfs` with no environment help.

The bucket name is now a fixed part of the `core` service contract, so the normal profile carries it
whether or not RustFS runs. The RustFS container entrypoint and the Rails tasks still enforce
required non-empty credentials only when those operations run.

Start the optional profile:

```sh
$COMPOSE --profile object-storage up -d rustfs
$COMPOSE --profile object-storage ps rustfs
$COMPOSE --profile object-storage logs rustfs-permissions rustfs
```

The Compose healthcheck covers the S3 API readiness endpoint. Check the S3 API and console
independently from the host:

```sh
curl --fail --silent --show-error http://127.0.0.1:9000/health/ready
curl --fail --silent --show-error http://127.0.0.1:9001/rustfs/console/health
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
