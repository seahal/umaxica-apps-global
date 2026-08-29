# Development Credential Provisioning

No credential material is tracked in this repository. The encrypted Rails credential payloads
(`config/credentials/*.yml.enc`) are committed, but the keys that decrypt them are not, and neither
is the repository-root `.env`. A fresh clone therefore cannot boot the application or run the test
suite until the missing pieces are supplied out of band. This document lists what is missing, where
each item belongs, and who issues it.

## What is not in git

| Item              | Location              | Ignore rule in `.gitignore` |
| :---------------- | :-------------------- | :-------------------------- |
| `development.key` | `config/credentials/` | `/config/credentials/*.key` |
| `test.key`        | `config/credentials/` | `/config/credentials/*.key` |
| `.env`            | repository root       | `.env`                      |
| `.secrets/`       | repository root       | `.secrets/`                 |

`.secrets/` is no longer written by anything in this repository -- development service passwords are
generated inside the stack, as described below. The ignore rules stay so that a directory created by
hand, or left over from an earlier checkout, can never enter a commit or a build context.

`config/credentials/development.yml.enc` and `config/credentials/test.yml.enc` are tracked, and are
unreadable without the matching `.key` file. Committing a `.key` file defeats the encryption of the
payload it unlocks, so no key file may ever enter a commit, a branch, an issue, or a pull request.

## Rails credential keys

Two key files are required for local work:

- `config/credentials/development.key` — needed to boot the application.
- `config/credentials/test.key` — needed to run `bin/rails test`.

**Obtain both from the development lead** (the Tech Lead / Architect role defined in `docs/srs.md`).
They are shared over an encrypted channel and are never sent by plain email or chat.

Do not generate these keys locally. `bin/rails credentials:edit` creates a new key when none is
present, which silently replaces the key for the committed `.yml.enc` payload and makes that payload
undecryptable for everyone else. If decryption fails, request the correct key rather than
regenerating one.

Place each file at its exact path under `config/credentials/` and restrict its mode:

```bash
chmod 600 config/credentials/development.key config/credentials/test.key
```

Rails reads only `config/credentials/<environment>.key`. A copy at the repository root has no effect
and is not covered by the `config`-scoped ignore rules, so it is a leak risk with no benefit.

Verify the keys work without printing secret values to a shared terminal:

```bash
bin/rails credentials:show --environment development
bin/rails credentials:show --environment test
```

A missing or wrong key surfaces as `ActiveSupport::MessageEncryptor::InvalidMessage` during boot or
during a test run. That error means the key does not match the payload; it does not mean the
committed payload is corrupt.

CI does not use these files. GitHub Actions supplies the key through the `RAILS_MASTER_KEY` secret
(`.github/workflows/ci.yml`).

## Repository-root `.env`

Compose reads the repository-root `.env`. It currently carries three settings:

| Key                 | Source                                        |
| :------------------ | :-------------------------------------------- |
| `UID`               | written by hand: your host `id -u`            |
| `GID`               | written by hand: your host `id -g`            |
| `CLOUDFLARED_TOKEN` | Cloudflare dashboard, or the development lead |

`UID` and `GID` feed the `DOCKER_UID`/`DOCKER_GID` build args, which decide the workload UID baked
into the `core` image. `$UID`/`$GID` are bash builtins rather than exported variables, so Compose
never sees them from the environment; write them into `.env` once per machine:

```bash
printf 'UID=%s\nGID=%s\n' "$(id -u)" "$(id -g)" >> .env
```

Appending is safe as long as no earlier `UID=`/`GID=` line exists — Compose takes the last
occurrence, but a duplicate is confusing to read. Leaving them out is not silent: Compose falls back
to `1000`, and on a host whose user is not `1000:1000` every bind-mounted repository file appears
with the wrong owner inside the container.

`CLOUDFLARED_TOKEN` is tunnel-scoped. Retrieve it yourself from the Cloudflare dashboard following
`docs/operations/cloudflare-private-origin.md`; **request it from the development lead when you do
not have dashboard access.** A missing token fails during Compose resolution with an explicit
message, and there is no anonymous fallback.

There is no committed `.env.example` template. Do not add one — a template invites secret values to
be filled in next to tracked defaults. Restrict the file after creating it:

```bash
chmod 600 .env
```

## Provider credentials for staging, production, and individual environments

This covers AWS, Cloudflare, Fastly, and every other content-delivery or infrastructure provider.

No staging or production provider credential is stored in this repository in any form, encrypted or
otherwise, and none is issued self-service. The same applies to credentials scoped to one
developer's own environment.

**Request them from the development lead.** State:

- the provider and the account or zone involved,
- the environment (staging, production, or a named individual environment),
- the scope or permissions required,
- what the credential is for and how long it is needed.

The development lead either issues a scoped credential or performs the operation on the requester's
behalf. Broad or long-lived credentials are not issued for convenience.

A credential you receive stays out of the repository. Put it in the gitignored `.env`, in Rails
encrypted credentials, or in the provider's own secret store. Never place it in a tracked file, a
Compose file, a container image, a plan under `plans/`, or a note under `notes/`. When a credential
is no longer needed, or may have been exposed, tell the development lead so it can be revoked.

## Development service passwords: the `dev-credentials` service

PostgreSQL and RustFS passwords are generated inside the stack, not on the host. The
`dev-credentials` Compose service runs to completion before `core`, `primary`, `replica`, and
`rustfs` start, and writes five files into the `dev-credentials` named volume:

| File                   | Read by                      |
| :--------------------- | :--------------------------- |
| `postgres-writer`      | `core`, `primary`, `replica` |
| `postgres-replication` | `primary`, `replica`         |
| `rustfs-access-key`    | `core`, `rustfs`             |
| `rustfs-secret-key`    | `core`, `rustfs`             |
| `rustfs-rpc-secret`    | `rustfs`                     |

Every consumer mounts the volume read-only at `/run/dev-credentials` and reads the value through a
`*_PASSWORD_FILE` / `*_FILE` environment variable. There is no host-side bootstrap command and no
Podman Secret registration: a fresh clone only needs `.env` and the Rails credential keys.

Each file is written once and then reused, because PostgreSQL bakes the superuser password into
`primary-data` at initdb time. To rotate, remove the `dev-credentials`, `primary-data`, and
`replica-data` volumes together — dropping only `dev-credentials` leaves the databases holding the
previous password, and `primary` then refuses its own credential.

This covers development service passwords only. It does not write `.env`, and it does not supply
Rails credential keys or any provider credential. Running it will not resolve a decryption failure
or a missing `CLOUDFLARED_TOKEN`.

## Related documents

- `docs/operations/cloudflare-private-origin.md` — obtaining and placing `CLOUDFLARED_TOKEN`.
- `docs/operations/development-container-targets.md` — bringing up the development containers.
- `docs/hld.md` — the environment-variable catalog and the `.env` boundary.
- `docs/reference/repository-language-policy.md` — language rules for repository prose.
