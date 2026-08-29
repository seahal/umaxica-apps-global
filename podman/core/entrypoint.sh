#!/bin/bash -p
set -euo pipefail

readonly PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
unset BASH_ENV ENV CDPATH

readonly WORKLOAD_USER=${CORE_WORKLOAD_USER:?CORE_WORKLOAD_USER must be set}
readonly WORKLOAD_GROUP=${CORE_WORKLOAD_GROUP:?CORE_WORKLOAD_GROUP must be set}

if ! WORKLOAD_UID=$(id -u "${WORKLOAD_USER}"); then
  echo "core-entrypoint: workload user ${WORKLOAD_USER} does not exist" >&2
  exit 78
fi
readonly WORKLOAD_UID

if ! WORKLOAD_GID=$(getent group "${WORKLOAD_GROUP}" | cut -d: -f3) ||
   [[ -z "${WORKLOAD_GID}" ]]
then
  echo "core-entrypoint: workload group ${WORKLOAD_GROUP} does not exist" >&2
  exit 78
fi
readonly WORKLOAD_GID

if (( EUID == WORKLOAD_UID )); then
  # No root control plane in play: `userns_mode: keep-id` already maps this
  # process to the host-shaped workload user directly, so there is nothing
  # left to chown or drop privilege from. Run the workload as-is.
  exec "$@"
fi

if (( EUID != 0 )); then
  echo "core-entrypoint: effective UID must be 0 (root) or ${WORKLOAD_UID} (${WORKLOAD_USER}), got ${EUID}" >&2
  exit 77
fi

normalize_runtime_directory() {
  local path=$1

  if [[ ! -d "${path}" || -L "${path}" ]]; then
    echo "core-entrypoint: runtime path must be a directory, not a symlink: ${path}" >&2
    exit 79
  fi

  chown --no-dereference "${WORKLOAD_UID}:${WORKLOAD_GID}" "${path}"
}

# Only normalize fixed runtime paths. The explicit symlink rejection prevents
# a writable workspace from redirecting a root chown to another location.
normalize_runtime_directory /tmp
normalize_runtime_directory "/home/${WORKLOAD_USER}/workspace/tmp"
normalize_runtime_directory "/home/${WORKLOAD_USER}/workspace/tmp/pids"
normalize_runtime_directory "/home/${WORKLOAD_USER}/workspace/log"

exec /usr/bin/setpriv \
  --reuid="${WORKLOAD_UID}" \
  --regid="${WORKLOAD_GID}" \
  --init-groups \
  -- "$@"
