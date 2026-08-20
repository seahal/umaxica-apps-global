# VS Code Dev Containers on Rootless Podman

This repository uses the VS Code Dev Containers extension with rootless Podman.
It intentionally has no project-specific launcher or bootstrap script. VS Code
delegates the lifecycle to the standard Dev Containers CLI.

## One-Time Host Configuration

Install Podman 5 or newer, `podman-compose`, VS Code, and the recommended Dev
Containers extension. Then set these application-scoped VS Code user settings:

```jsonc
{
  "dev.containers.dockerPath": "/usr/bin/podman",
  "dev.containers.dockerComposePath": "/usr/bin/podman-compose"
}
```

These settings belong in **User Settings (JSON)**, not
`.vscode/settings.json`. The extension declares them with `application` scope,
so a workspace value does not select the engine used to create that workspace.

Pin the provider used by `podman compose` in
`~/.config/containers/containers.conf`:

```toml
[engine]
compose_providers = ["/usr/bin/podman-compose"]
```

The provider setting is required even when
`dev.containers.dockerComposePath` is set. The Dev Containers CLI can invoke
`podman compose`, and Podman otherwise prefers an installed `docker-compose`
provider over `podman-compose`.

## Starting from VS Code

1. Open the repository folder in VS Code as the normal rootless Podman user.
2. Run **Dev Containers: Rebuild and Reopen in Container** from the Command
   Palette.
3. After the first successful build, use **Dev Containers: Reopen in
   Container** for routine starts.

VS Code reads `.devcontainer/devcontainer.json`, combines the three declared
Compose files, provisions the configured features, runs the lifecycle commands,
and opens `/home/global/workspace` as user `global`.

## CLI Equivalent

For diagnostics or automation, the equivalent command from the repository root
is:

```sh
PODMAN_COMPOSE_PROVIDER=/usr/bin/podman-compose \
devcontainer up \
  --docker-path /usr/bin/podman \
  --docker-compose-path /usr/bin/podman-compose \
  --workspace-folder .
```

To open a CLI shell afterward:

```sh
devcontainer exec --docker-path /usr/bin/podman --workspace-folder . -- bash -l
```

## Why the CLI Selectors Are Required

`--docker-path /usr/bin/podman` selects the engine. The Dev Containers CLI
shells out to `docker` for every lifecycle query. A development host may also
have a real Docker installation, so omitting this flag does not fail loudly; it
silently drives the wrong engine, and the resulting container has none of the
rootless properties this project depends on.

`PODMAN_COMPOSE_PROVIDER=/usr/bin/podman-compose` selects the Compose
implementation, and it is not optional. Once the engine is Podman, the CLI
invokes the `podman compose` subcommand, which delegates to an external provider
that prefers `docker-compose` when one is installed. Docker Compose cannot
attach this stack's external Podman secrets. This is a security requirement, not
a convenience: see [Container Engine Notes](container-engine-podman-notes.md).

`--docker-compose-path /usr/bin/podman-compose` is kept because the CLI still
uses it on the paths where it invokes a standalone Compose binary rather than
the subcommand. It does not substitute for the environment variable.

None of these have a `devcontainer.json` equivalent. VS Code supplies the two
CLI flags from its application-scoped user settings; the Podman user
configuration supplies the provider choice. Keep the complete command together
when using the CLI directly.

`--workspace-folder .` names the folder explicitly. The command must be run
from the repository root.

## What the Configuration Already Does

`devcontainer.json` runs
`.devcontainer/write-host-ids.sh && bin/setup-dev-secrets` as
`initializeCommand`. The first writes the real `UID` and `GID` into the
gitignored repository-root `.env`, because `$UID` and `$GID` are bash builtins
rather than exported variables and Compose cannot read them directly. The
second registers the external Podman secrets — `dev_postgres_writer`,
`dev_postgres_replication`, `dev_rustfs_access_key`,
`dev_rustfs_secret_key`, and `dev_rustfs_rpc_secret` — before any service
starts. `postCreateCommand` then runs `bundle install && pnpm install`.

The Podman-specific properties are Compose concerns and need no flags:
`userns_mode: keep-id`, `user: !reset null`, the `bind.selinux: Z` labels on
the workspace and on the read-only `/etc/timezone`, `./.github`, `./bin`, and
`./.devcontainer` binds, the `DOCKER_UID`/`DOCKER_GID` build arguments, the
stable `container_name` values including `global-devcontainer-core`, the
`host.docker.internal:host-gateway` extra host, and the published ports.

## Safety Contract

Run as the normal rootless Podman user. Never `sudo devcontainer` or
`sudo podman` — the container's security model assumes a user namespace owned
by your account. Confirm with
`podman info --format '{{.Host.Security.Rootless}}'`, which must print `true`.

Do not add `--mount`, `--secrets-file`, `--remote-env`, `--config`, or
`--override-config`. Each reaches past the repository's security boundary and
injects host state the image is built to exclude.

If `global-devcontainer-core` exists in Created or Exited state, use **Dev
Containers: Rebuild and Reopen in Container**. For the CLI recovery path,
append `--remove-existing-container` to `devcontainer up`. Do not use either
rebuild path for routine starts because it recreates the Dev Container.

## Related

- [Dev Container CLI](https://github.com/devcontainers/cli#dev-container-cli)
- [Dev Container JSON reference](https://containers.dev/implementors/json_reference/)
- [Podman Compose provider selection](https://docs.podman.io/en/latest/markdown/podman-compose.1.html)
- [Container Engine Notes (Podman / Docker)](container-engine-podman-notes.md)
- [Development Container Targets](development-container-targets.md)
- [Development Host Port Exposure](development-host-port-exposure.md)
