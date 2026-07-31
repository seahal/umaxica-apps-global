# Development Container Targets

The repository uses one multi-stage `Dockerfile` with three outcome images:

- `development` is the normal Rails development image.
- `workspace` derives from `development` and adds nested rootless Podman for a
  persistent coding workspace.
- `production` is the deployable runtime image.

The final Dockerfile stage aliases `production`, so omitting `--target` does not
accidentally produce a development image.

## Build an image directly

```sh
podman build --target development \
  --tag umaxica-core:development .

podman build --target workspace \
  --tag umaxica-core:workspace .

podman build --target production \
  --tag umaxica-core:production .
```

## Start normal development

`.devcontainer/compose.override.yml` maps the image's `DOCKER_UID`/`DOCKER_GID`
build args from `${UID:-1000}`/`${GID:-1000}`. `$UID`/`$GID` are bash builtins,
not exported environment variables, so Compose only sees real values if
something writes them into the environment first. The Dev Containers CLI does
this automatically via `initializeCommand` (`.devcontainer/write-host-ids.sh`,
which writes the repo-root `.env` that Compose auto-loads). Manual
`podman compose` runs must run that script once first:

```sh
.devcontainer/write-host-ids.sh
```

The base Compose file explicitly selects `development`:

```sh
podman compose \
  -f compose.yaml \
  -f .devcontainer/compose.override.yml \
  -f compose.custom.yaml \
  up --build
```

## Start the workspace target

The workspace overlay is an explicit opt-in:

```sh
podman compose \
  -f compose.yaml \
  -f .devcontainer/compose.override.yml \
  -f compose.custom.yaml \
  -f compose.workspace.yaml \
  up --build
```

The host must provide `/dev/fuse`. The overlay mounts it into `core` and stores
inner Podman data in the dedicated `workspace-podman-storage` volume. On
SELinux hosts, add `security_opt: [label=nested]` only when audit evidence shows
that the nested label is required.

The inner Podman process runs as `global` and uses subordinate UID/GID ranges.
UID 0 inside a container created by that inner Podman instance is subordinate
to `global`; it is not UID 0 in `core` or on the host.

The outer Podman socket is not mounted, and the overlay does not add
`privileged` mode or Linux capabilities. A coding agent can manage only the
inner Podman instance. The host account that owns the outer rootless Podman
remains the administrative boundary.

## Sudo-less workload

Both development targets omit `sudo` and do not assign a password to `global`.
Compose starts a root-owned fixed entrypoint to initialize tmpfs paths and run
the Tailscale daemon. Rails, development tools, interactive Dev Container
sessions, and the inner Podman process run as `global`.

Host-side recovery remains available:

```sh
podman exec --user 0 -it global-devcontainer-core /bin/bash
```

Do not mount the outer Podman socket to make this command available inside
`core`; that would give the development workload control over the outer
container boundary.

## Official references

- [Podman rootless mode](https://docs.podman.io/en/latest/markdown/podman.1.html#rootless-mode)
- [Podman troubleshooting](https://github.com/containers/podman/blob/main/troubleshooting.md)
- [Podman run device handling](https://docs.podman.io/en/stable/markdown/podman-run.1.html)
