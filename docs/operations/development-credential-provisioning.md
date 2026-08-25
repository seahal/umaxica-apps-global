# Development Credential Provisioning

No credential material is tracked in this repository. The encrypted Rails credential payloads
(`config/credentials/*.yml.enc`) are committed, but the keys that decrypt them are not, and neither
is the repository-root `.env`. A fresh clone therefore cannot boot the application or run the test
suite until the missing pieces are supplied out of band. This document lists what is missing, where
each item belongs, and who issues it.

## What is not in git

| Item | Location | Ignore rule in `.gitignore` |
| :--- | :--- | :--- |
| `development.key` | `config/credentials/` | `/config/credentials/*.key` |
| `test.key` | `config/credentials/` | `/config/credentials/*.key` |
| `.env` | repository root | `.env` |
| `.secrets/` | repository root | `.secrets/` |

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

| Key | Source |
| :--- | :--- |
| `UID` | written automatically by `.devcontainer/write-host-ids.sh` |
| `GID` | written automatically by `.devcontainer/write-host-ids.sh` |
| `CLOUDFLARED_TOKEN` | Cloudflare dashboard, or the development lead |

`UID` and `GID` need no manual action: `.devcontainer/devcontainer.json` runs
`.devcontainer/write-host-ids.sh` as its `initializeCommand`, and that script preserves any existing
`CLOUDFLARED_TOKEN` line.

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

## What `bin/setup-dev-secrets` does and does not do

`bin/setup-dev-secrets` runs as part of the devcontainer `initializeCommand`. It generates dev-only
service passwords (PostgreSQL roles, HMAC salts, RustFS keys, and similar) into `.secrets/` and
registers them as Podman secrets.

It does not write `.env`, and it does not supply Rails credential keys or any provider credential.
Its own header comment scopes user credentials out. Running it will not resolve a decryption failure
or a missing `CLOUDFLARED_TOKEN`.

## Related documents

- `docs/operations/cloudflare-private-origin.md` — obtaining and placing `CLOUDFLARED_TOKEN`.
- `docs/operations/development-container-targets.md` — bringing up the development containers.
- `docs/hld.md` — the environment-variable catalog and the `.env` boundary.
- `docs/reference/repository-language-policy.md` — language rules for repository prose.
