# Retire `.devcontainer/compose.override.yml`

Date: 2026-08-27

`docs/operations/development-container-targets.md` and `compose.yaml` already
state that the repository has exactly two Compose files: `compose.yaml` and
`compose.custom.yaml`. `.devcontainer/compose.override.yml` was a third overlay
that duplicated project-common `core` settings already in `compose.yaml`.

The unique host timezone bind (`/etc/localtime`) moved to `compose.custom.yaml`.
Workspace binds, loopback ports, `keep-id`, build UID/GID args, and container
names stay in `compose.yaml`. `devcontainer.json` now loads only
`../compose.yaml` then `../compose.custom.yaml`.

Do not reintroduce `.devcontainer/compose.override.yml`.
