#!/usr/bin/env bash
set -euo pipefail

USER_ID=$(id -u)
GROUP_ID=$(id -g)

# tmpfs mounts come up root-owned on each boot; only those need normalization.
# Do NOT chown ${HOME} or its dotfile subdirs: under rootless podman without
# `userns_mode: keep-id` honored at runtime, that rewrites bind-mounted host
# files (~/.ssh, ~/.gitconfig, ~/.codex, ...) to a subuid the host user can no
# longer access.
# In devcontainer mode workspace/tmp and workspace/log are bind-mounted (not
# tmpfs) so they are already owned correctly; the chown is a no-op but safe.
# /tmp and workspace/tmp/pids are always tmpfs so they always need normalization.
sudo chown "${USER_ID}:${GROUP_ID}" \
  /tmp \
  "${HOME}/workspace/tmp" \
  "${HOME}/workspace/tmp/pids" \
  "${HOME}/workspace/log"

exec "$@"
