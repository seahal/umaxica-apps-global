#!/usr/bin/env bash
set -euo pipefail

USER_ID=$(id -u)
GROUP_ID=$(id -g)

# tmpfs mounts come up root-owned on each boot; only those need normalization.
# Do NOT chown ${HOME} or its dotfile subdirs: under rootless podman without
# `userns_mode: keep-id` honored at runtime, that rewrites bind-mounted host
# files (~/.ssh, ~/.gitconfig, ~/.codex, ...) to a subuid the host user can no
# longer access.
sudo chown "${USER_ID}:${GROUP_ID}" "${HOME}/workspace/tmp" "${HOME}/workspace/log"

exec "$@"
