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

## Development service passwords: fixed literals

The development PostgreSQL passwords are fixed literals declared inline in `compose.yaml`. They are
not generated, not rotated, and not secret:

| Variable                        | Value         | Set on                       |
| :------------------------------ | :------------ | :--------------------------- |
| `POSTGRESQL_PASSWORD`           | `development` | `core`                       |
| `POSTGRES_PASSWORD`             | `development` | `primary`, `replica`         |
| `POSTGRES_REPLICATION_PASSWORD` | `replication` | `primary`, `replica`         |

This is deliberate. The stack is development-only, every database it serves is disposable, no port
is published for `primary` or `replica`, and the values guard nothing reachable off the host. A
value the whole team can read in the file it is written in is worth more here than a random one
nobody can look up. Production credentials are unaffected and continue to come from Rails encrypted
credentials and the provider's own secret store, as described above.

Keep the three `core` values identical to the `primary` and `replica` values. PostgreSQL bakes the
password into `primary-data` at initdb time, so changing a literal without also removing the
`primary-data` and `replica-data` volumes locks the stack out of its own database. Recreate both
volumes together after any change.

There is no host-side bootstrap command, no Podman Secret registration, and no credential volume: a
fresh clone only needs `.env` (for `UID` and `GID`) and the Rails credential keys. This covers
development service passwords only; it does not supply Rails credential keys or any provider
credential, so it will not resolve a decryption failure or a missing `CLOUDFLARED_TOKEN`.

## GitHub authentication inside the development container

The container performs no GitHub login of its own. The host's existing authentication is forwarded
into `core` by the `core` block in `compose.custom.yaml`, so `ssh -T git@github.com`, `git fetch`,
and `gh` work in a freshly recreated container without `gh auth login`.

Nothing secret is stored for this. No private key, no `~/.ssh` directory, and no token literal is
written into a repository file, a Compose file, or the image. Two host-shaped values are read from
the environment that launches Compose:

| Variable         | Carries                                    | Reaches the container as                  |
| :--------------- | :----------------------------------------- | :---------------------------------------- |
| `SSH_AUTH_SOCK`  | the path of the host `ssh-agent` socket    | a bind mount at `/ssh-agent`              |
| `GH_TOKEN`       | a GitHub API token                         | the `GH_TOKEN` environment variable       |

`${HOME}/.ssh/known_hosts` is additionally bound read-only at `/home/global/.ssh/known_hosts`. It
holds public host keys only, and ssh needs it to verify `github.com`.

Signing stays in the host agent: the container sends a challenge over the socket and receives a
signature, so the private key never crosses the boundary. `GH_TOKEN` also reaches git, because the
container's `/home/global/.gitconfig` routes `https://github.com` through
`gh auth git-credential` — the `origin` remote stays on HTTPS and is not rewritten.

### Host setup

Both variables must be exported in the shell or session that starts Podman or VS Code. Compose
interpolates them from the process environment; the repository-root `.env` is not consulted for
them, and a token must never be written there.

```bash
# A stable agent socket path. A per-login /tmp/ssh-XXXX/agent.N path changes on every
# login, and the container would need recreating each time to follow it.
systemctl --user enable --now ssh-agent.socket
echo 'export SSH_AUTH_SOCK=$XDG_RUNTIME_DIR/ssh-agent.socket' >> ~/.bash_profile

ssh-add ~/.ssh/id_ed25519
ssh-add -l                     # must list the key
ssh -T git@github.com          # must greet you by username

export GH_TOKEN="$(gh auth token)"   # or a personal access token
```

Run `ssh -T git@github.com` on the host before the first `up`. Besides proving the agent works, it
guarantees `~/.ssh/known_hosts` exists: Podman creates a missing bind source as a *directory*, and a
directory at `~/.ssh/known_hosts` breaks ssh on the host as well.

Both variables tolerate absence. With no `GH_TOKEN`, gh falls back to whatever
`~/.config/gh/hosts.yml` holds inside the container, which is usually a stale token; with no
`SSH_AUTH_SOCK`, the placeholder mount makes ssh report `Error connecting to agent` rather than
failing Compose resolution. Neither degrades silently into a working-looking state.

### Verification

Recreate the container — mounts and `security_opt` are creation-time settings — then, inside it:

```bash
ssh-add -l                 # lists the host key, proving the socket forwarded
ssh -T git@github.com      # authenticates as your GitHub user
git fetch                  # HTTPS via GH_TOKEN and the gh credential helper
gh auth status             # reports the token as coming from GH_TOKEN
gh repo view
```

`gh auth status` naming `GH_TOKEN` is the point of the check: it confirms the environment token took
precedence over any token left in the container's `hosts.yml`.

### SELinux

The host is expected to be SELinux-enforcing. Both new mounts carry `selinux: Z`, matching every
other bind in this project, so Podman relabels them to `container_file_t` at the container's MCS
level. `compose.custom.yaml` pins that level to `s0:c101,c202`, the same value
`.devcontainer/compose.override.yml` pins, so the Dev Container path and the plain
`podman compose -f compose.yaml -f compose.custom.yaml up -d core` path agree; without the pin each
CLI run would allocate a fresh category pair and lock the other path out of the relabelled files.

Relabelling `~/.ssh/known_hosts` is visible on the host. A normal RHEL login user runs as
`unconfined_u` and keeps reading the file; a confined login user may not.

If `ssh -T git@github.com` fails inside the container, read the actual denial on the host:

```bash
sudo ausearch -m AVC -ts recent
```

and apply only the fix that denial names. Do not reach for `label=disable`, `privileged`, a wider
`:Z`, or a private-key mount — each defeats the boundary this arrangement exists to keep.

## Related documents

- `docs/operations/cloudflare-private-origin.md` — obtaining and placing `CLOUDFLARED_TOKEN`.
- `docs/operations/development-container-targets.md` — bringing up the development containers.
- `docs/operations/container-engine-podman-notes.md` — rootless Podman and SELinux behaviour.
- `docs/hld.md` — the environment-variable catalog and the `.env` boundary.
- `docs/reference/repository-language-policy.md` — language rules for repository prose.
