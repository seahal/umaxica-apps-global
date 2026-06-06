# Container Engine Notes (Podman / Docker)

The compose stack at `compose.yaml` is primarily exercised with Docker. It is
intended to work with Podman (4.1+) as well, but rootless Podman has a few
operational requirements that Docker users do not have to think about. This
document captures those so a contributor running Podman does not lose hours
to silent misconfiguration.

## Restart policies

Several services use `restart: always` or `restart: unless-stopped`. Under
rootless Podman, restart policies are honored only while the user session is
alive unless the user-level restart service is enabled:

```bash
systemctl --user enable --now podman-restart.service
```

Without it, containers do not come back after logout, reboot, or session
restart, even though `podman ps` shows the restart policy. Docker users on
systemd hosts get this for free via the system Docker daemon.

## Container socket for the `alloy` service

`alloy` mounts the engine's container socket to collect container telemetry.
The compose file expects an env override on Podman:

| Mode             | `CONTAINER_SOCKET` value                            |
| ---------------- | --------------------------------------------------- |
| Docker (default) | (unset — defaults to `/var/run/docker.sock`)        |
| Rootless Podman  | `${XDG_RUNTIME_DIR}/podman/podman.sock`             |
| Rootful Podman   | `/run/podman/podman.sock`                           |

Enable the Podman socket once per user session:

```bash
systemctl --user enable --now podman.socket   # rootless
sudo systemctl enable --now podman.socket     # rootful
```

## Image UID / GID build args

The `core` image bakes the host's UID/GID at build time via the `DOCKER_UID`
and `DOCKER_GID` build args (sourced from `${UID}` / `${GID}`). Consequences:

- The image is **not portable** across users whose host UID differs from the
  UID the image was built against. Sharing a prebuilt image with another
  developer whose UID is different requires a rebuild.
- Always run `docker compose build` (or `podman compose build`) from the
  account that will run the container. Do not build as root and run rootless.
- When switching accounts on a workstation, rebuild the `core` image rather
  than reusing the cached one.

The devcontainer adds `userns_mode: keep-id` in `.devcontainer/compose.override.yml`,
which maps the in-container UID back to the host UID at runtime. This keeps
bind-mount ownership consistent even if the build UID differs slightly from
the runtime UID. Pinning `user:` on the compose service is intentionally
cleared in the override because pinning would double-map under `keep-id` and
break ownership.

## Postgres tmpfs sizing

Primary and replica DBs run on `tmpfs`. The sizes (`POSTGRES_PRIMARY_TMPFS_SIZE`,
`POSTGRES_REPLICA_TMPFS_SIZE`) are billed against the user's memory cgroup
under rootless Podman. On hosts with constrained `memory.max` for the user
slice, set lower values in `.env`:

```bash
POSTGRES_PRIMARY_TMPFS_SIZE=24g
POSTGRES_REPLICA_TMPFS_SIZE=16g
```

Reducing these caps cuts the maximum number of parallel test workers the DBs
can fan out to before evicting.

## SELinux

On Fedora, RHEL, and other SELinux-enforcing hosts, bind-mounted host paths
must be labeled before the container can read them. The compose file marks
read-only config bind mounts with `:z` (shared label). The workspace bind in
the devcontainer is intentionally **not** labeled so SELinux does not
relabel the host source tree.

If a service fails to read a mounted file with "permission denied" on an
SELinux host even though POSIX permissions look correct, relabel manually:

```bash
chcon -Rt container_file_t docker/<service>/
```

## Devcontainer overrides

`.devcontainer/compose.override.yml` makes the stack Podman-friendly:

- `userns_mode: keep-id` for UID mapping.
- `user: !reset null` so the in-image UID wins instead of double-mapping.
- `tmpfs: !reset null` because rootless Podman has historically been
  unreliable with the workspace `tmp/` and `log/` paths on tmpfs.

Run the devcontainer with the override layered on the base compose file:

```bash
podman compose -f compose.yaml -f .devcontainer/compose.override.yml up
```
