# Development Container Targets

The repository uses one multi-stage `Containerfile` with three outcome images:

- `development` is the normal Rails development image.
- `workspace` derives from `development` and adds nested rootless Podman for a
  persistent coding workspace.
- `production` is the deployable runtime image.

The final Containerfile stage aliases `production`, so omitting `--target` does not
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

## Compose file layout

The repository keeps exactly two Compose files:

- `compose.yaml` — the project-common definition, including the workspace bind mount,
  the loopback host publications, `userns_mode: keep-id`, and the build target knob.
- `compose.custom.yaml` — the developer-owned overlay for anything specific to one
  machine or one person: the Cloudflare connector, host devices, personal tooling.

`.devcontainer/devcontainer.json` loads both, in that order. Do not add a third overlay.

## Start normal development

`compose.yaml` maps the image's `DOCKER_UID`/`DOCKER_GID` build args from
`${UID:-1000}`/`${GID:-1000}`. `$UID`/`$GID` are bash builtins, not exported
environment variables, so Compose only sees real values if something writes
them into the environment first. The Dev Containers CLI does this
automatically via `initializeCommand` (`.devcontainer/write-host-ids.sh`, which
writes the repo-root `.env` that Compose auto-loads). Manual `podman compose`
runs must run that script once first:

```sh
.devcontainer/write-host-ids.sh
```

Host port publication is loopback-only and is decided in `compose.yaml`;
`docs/operations/development-host-port-exposure.md` is the contract.

The default build target is `development`:

```sh
podman compose \
  -f compose.yaml \
  -f compose.custom.yaml \
  up --build
```

## Start the workspace target

The workspace target is an explicit, per-developer opt-in with two steps.

1. Set the build target in the repository-local, gitignored `.env`:

   ```sh
   CORE_BUILD_TARGET=workspace
   ```

2. Give `core` the FUSE device in your own `compose.custom.yaml`. It is not
   committed there because not every host exposes `/dev/fuse`, and a device
   Compose cannot resolve makes the whole project fail to start:

   ```yaml
   services:
     core:
       devices:
         - /dev/fuse:/dev/fuse
   ```

Then start the stack with the same two-file command as above. Inner Podman data
persists in the `workspace-podman-storage` volume, which `compose.yaml` already
mounts at `/home/global/.local/share/containers` (inert on the `development`
target). On SELinux hosts, add `security_opt: [label=nested]` only when audit
evidence shows that the nested label is required.

The inner Podman process runs as `global` and uses subordinate UID/GID ranges.
UID 0 inside a container created by that inner Podman instance is subordinate
to `global`; it is not UID 0 in `core` or on the host.

The outer Podman socket is not mounted, and the workspace target does not add
`privileged` mode or Linux capabilities. A coding agent can manage only the
inner Podman instance. The host account that owns the outer rootless Podman
remains the administrative boundary.

## Sudo-less workload

Both development targets omit `sudo` and do not assign a password to `global`.
Compose starts a root-owned fixed entrypoint to initialize tmpfs paths. Rails,
development tools, interactive Dev Container sessions, and the inner Podman
process run as `global`.

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
