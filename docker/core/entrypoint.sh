#!/usr/bin/env bash
set -euo pipefail

# Use current user/group IDs
USER_ID=$(id -u)
GROUP_ID=$(id -g)

# Fix ownership under HOME (dotfiles, caches, tmpfs mounts, etc.).
# Skip the workspace bind mount to avoid traversing the entire project tree.
sudo chown "${USER_ID}:${GROUP_ID}" "${HOME}"
sudo find "${HOME}" -maxdepth 1 -mindepth 1 ! -name workspace -exec chown -R "${USER_ID}:${GROUP_ID}" {} +

# Workspace subdirectories that might be tmpfs or need correct ownership
# The paths are relative to HOME/workspace
sudo chown "${USER_ID}:${GROUP_ID}" "${HOME}/workspace/tmp" "${HOME}/workspace/log"

exec "$@"
