# Container Engine Notes (Podman / Docker)

## Compose provider for the Dev Container

VS Code is the primary entry point. Complete the one-time Podman user settings
in [VS Code Dev Containers on Rootless
Podman](devcontainer-cli-podman-startup.md), then run **Dev Containers: Rebuild
and Reopen in Container**.

For diagnostics or automation, use the equivalent standard CLI command from
the repository root:

```sh
PODMAN_COMPOSE_PROVIDER=/usr/bin/podman-compose \
devcontainer up \
  --docker-path /usr/bin/podman \
  --docker-compose-path /usr/bin/podman-compose \
  --workspace-folder .
```

`PODMAN_COMPOSE_PROVIDER` is not optional. Once `--docker-path` points at
Podman, the Dev Containers CLI invokes the `podman compose` subcommand, and
`podman compose` delegates to an external provider that prefers `docker-compose`
when one is installed. Docker Compose reports `unsupported external secret` for
this stack because it cannot attach external Podman secrets through the Podman
API, and on a host with no running Docker daemon it fails earlier still, against
a missing `podman.sock`. The variable is what pins the provider;
`--docker-compose-path` alone does not, because the subcommand form does not
consult it.

This is a security requirement. Do not replace external Podman secrets with
host credential bind mounts or Compose `file:` secrets. The Dev Container
`initializeCommand` registers the internal service secrets through
`bin/setup-dev-secrets` before the container starts. Global and Edge intentionally do not share a
host Podman network; Edge reaches the Rails origin through Cloudflare Workers VPC.

`--docker-path` is equally required. Without it the Dev Containers CLI runs
lifecycle queries such as `docker ps` through its default Docker executable,
which on a host that also has Docker installed silently drives the wrong engine.
Neither the flags nor the variable have a `devcontainer.json` equivalent, so
none of them can be moved into repository configuration.

There is intentionally no repository launcher. VS Code invokes the standard
Dev Containers CLI, keeping one lifecycle instead of adding a project-specific
bootstrap interface. The remaining Podman-specific properties live in Compose
configuration.

If an interrupted start leaves `global-devcontainer-core` in Created or Exited
state, use **Dev Containers: Rebuild and Reopen in Container**. The CLI
equivalent is the same `devcontainer up` command with
`--remove-existing-container`.

Compose networks are repository-managed rootless Podman networks. In
particular, `outer.external` is a YAML boolean and is not environment-variable
interpolated. Interpolation turns this field into a string; affected
podman-compose releases then fail in network argument construction with
`AttributeError: 'str' object has no attribute 'get'`.

`bin/setup-dev-secrets` reports secret names and state only; it never prints
secret values.

The compose stack at `compose.yaml` is exercised with rootless Podman. Some
Compose-compatible tooling remains useful for static validation, but it is not
the supported runtime provider when Podman-managed secrets are attached. This
document records the rootless Podman requirements that are easy to miss.

## Restart policies

Several services use `restart: always` or `restart: unless-stopped`. Under rootless Podman, restart
policies are honored only while the user session is alive unless the user-level restart service is
enabled:

```bash
systemctl --user enable --now podman-restart.service
```

Without it, containers do not come back after logout, reboot, or session restart, even though
`podman ps` shows the restart policy. Docker users on systemd hosts get this for free via the system
Docker daemon.

## Image UID / GID build args

The `core` image bakes the host's UID/GID at build time via the `DOCKER_UID` and `DOCKER_GID` build
args (sourced from `${UID}` / `${GID}`). Consequences:

- The image is **not portable** across users whose host UID differs from the UID the image was built
  against. Sharing a prebuilt image with another developer whose UID is different requires a
  rebuild.
- Always run `docker compose build` (or `podman compose build`) from the account that will run the
  container. Do not build as root and run rootless.
- When switching accounts on a workstation, rebuild the `core` image rather than reusing the cached
  one.

The devcontainer adds `userns_mode: keep-id` in `.devcontainer/compose.override.yml`, which maps the
in-container UID back to the host UID at runtime. This keeps bind-mount ownership consistent even if
the build UID differs slightly from the runtime UID. Pinning `user:` on the compose service is
intentionally cleared in the override because pinning would double-map under `keep-id` and break
ownership.

## PostgreSQL storage

Primary and replica data use named volumes. The no-tmpfs baseline is
intentional: explicit tmpfs and `shm_size` settings are not part of the current
stack. Reintroducing either requires workload and memory-pressure measurements.

## SELinux

On Fedora, RHEL, and other SELinux-enforcing hosts, bind-mounted host paths must be labeled before
the container can read them. The compose file marks read-only config bind mounts with `:z` (shared
label). The workspace bind in the devcontainer is intentionally **not** labeled so SELinux does not
relabel the host source tree.

If a service fails to read a mounted file with "permission denied" on an SELinux host even though
POSIX permissions look correct, relabel manually:

```bash
chcon -Rt container_file_t podman/<service>/
```

## Devcontainer overrides

`.devcontainer/compose.override.yml` makes the stack Podman-friendly:

- `userns_mode: keep-id` for UID mapping.
- `user: !reset null` so the in-image UID wins instead of double-mapping.
- `tmpfs: !reset null` because rootless Podman has historically been unreliable with the workspace
  `tmp/` and `log/` paths on tmpfs.

Run the devcontainer with the override layered on the base compose file:

```bash
podman compose -f compose.yaml -f .devcontainer/compose.override.yml up
```
