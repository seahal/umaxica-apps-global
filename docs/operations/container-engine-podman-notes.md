# Container Engine Notes (Podman / Docker)

## Compose provider for the Dev Container

Start the Dev Container with `podman/tools/dcup`. `podman compose` delegates
to an external provider and prefers `docker-compose` when both providers are
installed. Docker Compose reports `unsupported external secret` for this stack
because it cannot attach external Podman secrets through the Podman API. The
repository launcher therefore passes `/usr/bin/podman-compose` directly to the
Dev Containers CLI and registers local service secrets first.

This is a security requirement. Do not replace external Podman secrets with
host credential bind mounts or Compose `file:` secrets. The Dev Container
`initializeCommand` also registers the internal service secrets. This
repository supports the Dev Containers CLI workflow; start it through the
repository launcher:

```bash
podman/tools/dcup
```

The launcher supplies both `--docker-path /usr/bin/podman` and
`--docker-compose-path /usr/bin/podman-compose`. Both are required: selecting
only the Compose provider still leaves the Dev Containers CLI running lifecycle
queries such as `docker ps` through its default Docker executable.
These executable paths are intentionally fixed rather than configurable through
ambient environment variables. This Podman-only entry point must not silently
fall back to Docker Compose, which cannot attach the external Podman secrets.

If an interrupted start leaves `global-devcontainer-core` in Created or Exited
state, the launcher removes only that stopped container by its stable Compose
name before invoking the CLI. This prevents the CLI from adding
`compose up --no-recreate` and reusing stale health-check configuration. A
running core, other service containers, and all named volumes are preserved.

Compose networks are repository-managed rootless Podman networks. In
particular, `outer.external` is a YAML boolean and is not environment-variable
interpolated. Interpolation turns this field into a string; affected
podman-compose releases then fail in network argument construction with
`AttributeError: 'str' object has no attribute 'get'`.

The launcher and `bin/setup-dev-secrets` report secret names and state only;
they never print secret values.

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
