# PostgreSQL → RustFS S3 FDW Proof of Concept — Audit and Host Execution Gate

## Context

`docker/fdw-poc/` and `docs/experiments/postgres-s3-fdw-poc.md` are committed prior work
(`2e4fb60d8`) that was authored but never executed — the authoring environment had no `podman`. This
is not a new PoC: it is unexecuted work that must be audited against current requirements, corrected
where stale or host-dependent, and then actually run by the user on a Linux host that has Podman and
the project's Compose provider. No rollback happens until after that real execution and after the
durable doc is updated with observed facts.

## Audit of the existing scaffold

**PostgreSQL version.** `primary` (the project's actual PostgreSQL service) builds from
`docker/psql-pub/Dockerfile`, `FROM docker.io/library/postgres:17.7-bookworm`. The existing
`docker/fdw-poc/Dockerfile` pins `postgres:16-bookworm` with the stated reason "Wrappers' PostgreSQL
17 support was unconfirmed at authoring time." That reasoning is now checked against the two
candidates directly (see below) — the PG16 pin is **stale**, not merely cautious: a suitable,
actively maintained candidate supports PG17 directly, so there is no reason left to run the PoC on a
different major version than the project.

**Exact Wrappers implementation in the existing scaffold.** `docker/fdw-poc/Dockerfile` builds
`supabase/wrappers` at `WRAPPERS_REF=v0.4.5` via
`cargo pgrx install --pg-config "$(pg_config)" --no-default-features --features s3_fdw`,
`CARGO_PGRX_VERSION=0.12.9`, `--pg16`. Current upstream `supabase/wrappers` release is v0.6.2
(2026-06-17) — the pin is also stale by five minor releases. The S3 wrapper (`s3_fdw` in that repo)
is **read-only** (SELECT only; no INSERT/UPDATE/DELETE/TRUNCATE) and handles CSV, JSON Lines, and
Parquet.

**Comparison against `pgspider/parquet_s3_fdw` and other candidates.**

|                                                 | `parquet_s3_fdw` (pgspider, v1.1.1, 2024-10-10)                                                                                                                                                        | `wrappers` `s3_fdw` (supabase, v0.6.2, 2026-06-17)                                 |
| ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------- |
| PG versions                                     | 13, 14, 15, 16, 17 — **matches `primary` (17.7) directly**                                                                                                                                             | PG16 confirmed workable at the pinned v0.4.5; PG17 support unconfirmed at that pin |
| Formats                                         | Parquet only                                                                                                                                                                                           | CSV, JSON Lines, Parquet                                                           |
| Read                                            | Yes                                                                                                                                                                                                    | Yes                                                                                |
| Write                                           | INSERT/UPDATE/DELETE on tables with key columns                                                                                                                                                        | No — read-only by design                                                           |
| Custom/S3-compatible endpoint                   | `endpoint` option (default `127.0.0.1:9000`, no scheme), `use_minio 'true'` flag                                                                                                                       | `endpoint_url`, `path_style_url`                                                   |
| Credentials                                     | AWS env vars for access, `user`/`password` via `CREATE USER MAPPING`                                                                                                                                   | Server-option creds or Vault (`vault_access_key_id`/`vault_secret_access_key`)     |
| Transactions                                    | Upstream docs state explicitly: **not supported**; concurrent writes to the same object are inconsistent                                                                                               | N/A (read-only, so no write-transaction question)                                  |
| Native build deps                               | CMake 3.29.3, C++11 compiler, Apache Arrow 16.1.0, AWS SDK for C++ 1.11.335, libcurl/openssl/uuid dev headers — build from source, upstream warns against precompiled binaries (linker/GCC mismatches) | Rust stable toolchain, `cargo-pgrx`                                                |
| License                                         | BSD-style                                                                                                                                                                                              | Apache 2.0                                                                         |
| Aurora PostgreSQL 17.x supported-extension list | Not listed                                                                                                                                                                                             | Not listed                                                                         |
| `pg_tle`-hostable                               | No (native C++ shared library; TLE requires trusted, non-native languages)                                                                                                                             | No (native Rust cdylib)                                                            |

No other actively maintained S3-capable FDW with a materially better fit surfaced during research
(checked GitHub, official PostgreSQL extension registry references, and Aurora's own extension docs
for any `s3_fdw`-named or generic S3-FDW entry beyond `aws_s3`, which is an import/export function
set, not a foreign data wrapper).

**Selected candidate: `parquet_s3_fdw`.** It runs on the project's actual PostgreSQL major version
without downgrading, it deals only in Parquet objects (matching the task's stated architecture:
"Temporary Parquet object"), and its write support is required to actually exercise Phase 6's
write/update/delete/transaction/concurrency checks — Wrappers' read-only `s3_fdw` cannot exercise
those at all. Its cost is a materially heavier native build (Arrow + AWS SDK for C++ compiled from
source); this must be reported honestly (build duration, image size, whether the build actually
completed without vendored/precompiled shortcuts) rather than glossed over. The existing candidate
was not retained merely because files already existed — it is replaced for a documented technical
reason.

**Aurora verdict, settled independently of local execution.** Confirmed directly against
`docs.aws.amazon.com/AmazonRDS/latest/AuroraPostgreSQLReleaseNotes/AuroraPostgreSQL.Extensions.html`
(fetched this session): neither `parquet_s3_fdw` nor `wrappers`/`s3_fdw` appears in Aurora
PostgreSQL 17.x's supported-extension list. Aurora's only S3-related extensions are `aws_s3` and
`aws_commons` — an import/export function set (`aws_s3.query_export_to_s3`,
`aws_s3.table_import_from_s3`), not a foreign data wrapper, and not usable as a live queryable
foreign table. `pg_tle` is present on Aurora but cannot host either candidate because both require
native compiled shared libraries, and TLE is restricted to trusted, non-native languages. Verdict:
**`AURORA_UNSUPPORTED`**, independent of whatever the local PostgreSQL result turns out to be.

## Host dependency removal

Constraint: the Linux host running this PoC must need only Podman and the existing Compose provider
— no host-installed `aws`, `duckdb`, `psql`, C/C++ toolchain, or language runtime.

- `docker/fdw-poc/fixtures/generate_fixtures.sh` currently shells out to a host `aws` CLI and a host
  `duckdb` CLI purely to hand-build one Parquet sample file. This is removed entirely. Since
  `parquet_s3_fdw` supports INSERT, the sample Parquet object is created **through the FDW itself**
  from inside the `fdw-poc` PostgreSQL container
  (`CREATE FOREIGN TABLE ...; INSERT INTO ... VALUES ...;`), which needs no external file-generation
  tool at all.
- The one remaining host-adjacent need is bucket creation/independent verification against RustFS
  (the task requires confirming written objects independently of the FDW). This is done with a
  **pinned, disposable `aws-cli` container**, invoked only via `podman compose run --rm`, never
  installed on the host: a new one-off service in `docker/fdw-poc/compose.fdw-poc.yml` using image
  `public.ecr.aws/aws-cli/aws-cli:<pinned digest/tag>`, attached to the `backend` network only, with
  `network_mode` scoped, no ports, profile `fdw-poc`, credentials passed at invocation time via
  `--env` flags from the invoking shell (never baked into the compose file or committed).
- `docker/fdw-poc/smoke/run_smoke_checks.sql` already runs via
  `podman compose exec -T fdw-poc psql ...` — no host `psql` needed; this pattern is kept.
- Result: the host execution gate (below) requires only `podman` + the project's Compose provider,
  one shell, and the ability to set environment variables. No package installs.

## Files to change (audit corrections, not a new PoC)

1. `docker/fdw-poc/Dockerfile` — rebase to `postgres:17.7-bookworm` (matches `primary` exactly).
   Multi-stage build: build Apache Arrow 16.1.0 and AWS SDK for C++ 1.11.335 from source per
   upstream's pinned-version guidance, then build `parquet_s3_fdw` against PG17 headers from the
   PGDG apt repo (same pattern already used in `docker/psql-pub/Dockerfile` for
   `postgresql-17-cron`). Pin every dependency version explicitly; record image size and build
   duration as part of Phase 3 reporting, not as a silent afterthought.
2. `docker/fdw-poc/compose.fdw-poc.yml` — point the build at the corrected Dockerfile (no path
   change expected, context is already `../../docker/fdw-poc`); add the pinned `aws-cli` one-off
   verification service under the same `fdw-poc` profile, `backend` network only, no host port.
   Confirm `fdw-poc` itself still uses tmpfs PGDATA, `restart: "no"`,
   `security_opt: no-new-privileges:true`, and depends on `rustfs` being `service_healthy` —
   unchanged from the existing, already-correct scaffold.
3. `docker/fdw-poc/fixtures/generate_fixtures.sh` — **removed**. Fixture creation is folded into the
   smoke SQL / host execution gate as an FDW-driven `INSERT`, eliminating the `duckdb`/`aws` host
   dependency at the source rather than working around it.
4. `docker/fdw-poc/smoke/run_smoke_checks.sql` — rewritten for `parquet_s3_fdw` syntax:
   `CREATE EXTENSION parquet_s3_fdw;` →
   `CREATE SERVER parquet_s3_srv FOREIGN DATA WRAPPER parquet_s3_fdw OPTIONS (use_minio 'true', endpoint 'rustfs:9000');`
   →
   `CREATE USER MAPPING FOR fdw_poc SERVER parquet_s3_srv OPTIONS (user '<placeholder>', password '<placeholder>');`
   → `CREATE FOREIGN TABLE ... OPTIONS (filename 's3://fdw-poc-bucket/fixtures/sample.parquet');`.
   Adds, in explicit read-only-vs-read-write-capable order: bootstrap INSERT (doubles as the write
   check), `SELECT`, projection, filter, `COUNT`, `EXPLAIN (VERBOSE, COSTS, BUFFERS)`, `UPDATE`,
   `DELETE`, a `BEGIN; INSERT; ROLLBACK;` block, a documented two-session concurrent-write procedure
   (two separate `psql` invocations — cannot be expressed as one script; the host execution gate
   spells out both commands to run in two terminals), and the four failure modes (bad credentials
   via a second server/user-mapping pair with a deliberately wrong password, missing object,
   malformed/mismatched declared schema, RustFS made unreachable mid-query via
   `podman compose stop rustfs` with a strict `statement_timeout`). Credential placeholders are
   substituted at run time by the host execution gate (e.g. via a local, gitignored `.env` read by
   the shell before invoking `psql -v`), never committed with real values.
5. `docs/experiments/postgres-s3-fdw-poc.md` — the task's required final path is
   `docs/experiments/postgresql-s3-fdw-poc.md` (note "postgresql" vs the existing file's
   "postgres"). To avoid two overlapping docs, this is a **rename-in-place with content update**,
   not a new file: same document, corrected filename, corrected candidate section, corrected version
   table, and two new required sections:
   - **Host Execution Gate** — the exact, copy-pasteable command sequence (below).
   - **Required Result Capture** — an explicit list of what output must be pasted back for each
     Results-table row, so "pending" is never silently reinterpreted as "success." The existing
     document's honest "Pending manual execution" framing, its explicit distinction between planned
     and observed behavior, and its Aurora "not verified" caveat are preserved — only strengthened
     with the now-confirmed Aurora extension-list check and the corrected candidate/version facts.
     No result cell is changed from `pending` until the user returns real command output.

## Static validation (everything not requiring Podman)

Before finalizing, validate without running containers:

- YAML: `docker/fdw-poc/compose.fdw-poc.yml` parses, service/network/profile names match
  `compose.yaml` (`backend` network, `rustfs` service name, `object-storage` /`fdw-poc` profiles)
  exactly; confirm the normal `podman compose -f compose.yaml ... up` (no
  `-f docker/fdw-poc/compose.fdw-poc.yml`, no `fdw-poc` profile) is structurally unaffected — the
  overlay file must not be referenced anywhere in the base compose set. the overlay adds only
  additive services under its own profile.
- Shell: the smoke-check invocation wrapper and any remaining helper script use `set -euo pipefail`,
  no unquoted host-path assumptions, safe to re-run (idempotent `CREATE ... IF NOT EXISTS` /
  `DROP ... IF EXISTS` where SQL supports it).
- SQL: every `CREATE SERVER`/`CREATE USER MAPPING`/`CREATE FOREIGN TABLE` option name is checked
  against `parquet_s3_fdw`'s README/source rather than assumed; every referenced bucket/object key
  matches what the bootstrap `INSERT` step actually writes.
- Dockerfile: every `FROM`, `ARG` version, and apt/PGDG source line is checked for internal
  consistency (PG17 headers matching PG17.7 runtime).
- Endpoint check: confirm every in-container reference to RustFS uses the service name `rustfs`
  (e.g. `rustfs:9000`), never `localhost`/`127.0.0.1`, since those only resolve correctly from the
  host via the devcontainer's published loopback ports, not from other containers on the `backend`
  network.

## Host Execution Gate (added to the doc, drafted here first)

Single Linux host session, requires only `podman` + Compose:

```sh
# 0. Baseline state
git status --short > /tmp/fdw-poc-baseline-status.txt
git diff --stat >> /tmp/fdw-poc-baseline-status.txt

COMPOSE="podman compose -f compose.yaml -f .devcontainer/compose.override.yml"
FDW_COMPOSE="podman compose -f compose.yaml -f docker/fdw-poc/compose.fdw-poc.yml"

# 1. RustFS health
$COMPOSE --profile object-storage up -d rustfs-permissions rustfs
$COMPOSE --profile object-storage exec -T rustfs curl -fsS http://127.0.0.1:9000/health/ready

# 2. Build the PoC image
export FDW_POC_POSTGRES_PASSWORD="$(openssl rand -hex 24)"   # local-only, never reused
time $FDW_COMPOSE -f docker/fdw-poc/compose.fdw-poc.yml \
  --profile object-storage --profile fdw-poc build fdw-poc
podman images --filter reference='*fdw-poc*'   # record image size

# 3. Start the temporary FDW PostgreSQL
$FDW_COMPOSE --profile object-storage --profile fdw-poc up -d fdw-poc
$FDW_COMPOSE --profile fdw-poc exec -T fdw-poc getent hosts rustfs

# 4. Extension availability
$FDW_COMPOSE --profile fdw-poc exec -T fdw-poc psql -U fdw_poc -d fdw_poc -c \
  "SELECT * FROM pg_available_extensions WHERE name = 'parquet_s3_fdw';"

# 5. Bucket creation (disposable, pinned aws-cli container; credentials via env, not committed)
$FDW_COMPOSE --profile fdw-poc run --rm \
  -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY \
  fdw-poc-awscli --endpoint-url http://rustfs:9000 s3 mb s3://fdw-poc-bucket

# 6. Run the smoke checklist (extension/server/mapping/table, bootstrap INSERT, read, write,
#    update, delete, EXPLAIN, transaction rollback, failure modes)
$FDW_COMPOSE --profile fdw-poc exec -T fdw-poc \
  psql -U fdw_poc -d fdw_poc -v ON_ERROR_STOP=0 -f /dev/stdin \
  < docker/fdw-poc/smoke/run_smoke_checks.sql | tee docker/fdw-poc/smoke-results.txt

# 6b. Concurrent-write check (run in a SECOND terminal while a first psql session is open
#     mid-transaction on the same object — documented as two explicit commands, not scripted)

# 7. Independent verification against RustFS
$FDW_COMPOSE --profile fdw-poc run --rm \
  -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY \
  fdw-poc-awscli --endpoint-url http://rustfs:9000 s3 ls s3://fdw-poc-bucket/fixtures/ --recursive

# 8. Log collection (credential-safe — no full request params, no secrets)
$FDW_COMPOSE --profile fdw-poc logs fdw-poc > docker/fdw-poc/postgres-log.txt
$COMPOSE --profile object-storage logs rustfs > docker/fdw-poc/rustfs-log.txt

# --- STOP HERE. Return docker/fdw-poc/smoke-results.txt, the build/image-size output,
#     and both log files for interpretation before any cleanup runs. ---
```

Cleanup (Phase 9) is deliberately **not** part of this gate — it runs only after results are
captured and the doc is updated, per the user's explicit instruction.

## What I need back after you run this

- Full text of `docker/fdw-poc/smoke-results.txt`.
- Build step output: duration, final image size, any compilation warnings.
- `docker/fdw-poc/postgres-log.txt` and `docker/fdw-poc/rustfs-log.txt`.
- The result of the manual concurrent-write check (step 6b), described in your own words if not
  captured to a file.
- Confirmation of whether step 5 (bucket creation) and step 4 (extension availability) succeeded
  before the rest ran.

## Verification (of this preparation work, not of the PoC itself)

- `docker/fdw-poc/compose.fdw-poc.yml` is valid YAML and every service/network/profile name matches
  `compose.yaml`.
- `podman compose -f compose.yaml config` (no fdw-poc overlay) is unaffected — diff against its
  output before this session's edits should be empty.
- No file under `docker/fdw-poc/` references `localhost` or `127.0.0.1` for RustFS.
- No committed file contains a real credential value — only placeholders substituted at invocation
  time.
- `rg -n 'duckdb|aws ' docker/fdw-poc` finds no remaining host-CLI invocation outside the pinned,
  containerized `aws-cli` one-off service defined in the compose overlay.
