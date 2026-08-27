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

readonly SSHD_BIN=/usr/sbin/sshd
readonly SSHD_CONFIG=/etc/umaxica/sshd_config
readonly SSHD_AUTHORIZED_KEYS=/home/${WORKLOAD_USER}/.config/umaxica/authorized_keys
readonly SSHD_HOST_KEY=/home/${WORKLOAD_USER}/.local/state/umaxica-sshd/ssh_host_ed25519_key
readonly SSHD_PID_FILE=/home/${WORKLOAD_USER}/workspace/tmp/pids/sshd.pid

# Inbound remote-access endpoint for the Codex App
# (docs/operations/remote-codex-over-tailscale.md). Opt-in: only the developer
# overlay sets REMOTE_SSHD=1, so base compose and production never reach this.
#
# This sshd runs as ${WORKLOAD_USER}, not root, because `userns_mode: keep-id`
# leaves no root in the container and the image ships no sudo. That is why it
# binds 2222 rather than 22; the Tailscale sidecar forwards tailnet 22 to it.
# Every failure below is fatal: a container that silently comes up without its
# remote-access path looks healthy while being unreachable.
start_remote_sshd() {
  if [[ ! -x "${SSHD_BIN}" ]]; then
    echo "core-entrypoint: REMOTE_SSHD=1 but ${SSHD_BIN} is missing (development image only)" >&2
    exit 80
  fi

  if [[ ! -r "${SSHD_CONFIG}" ]]; then
    echo "core-entrypoint: REMOTE_SSHD=1 but ${SSHD_CONFIG} is not readable" >&2
    exit 80
  fi

  if [[ ! -f "${SSHD_AUTHORIZED_KEYS}" || ! -s "${SSHD_AUTHORIZED_KEYS}" ]]; then
    echo "core-entrypoint: REMOTE_SSHD=1 but ${SSHD_AUTHORIZED_KEYS} is missing or empty" >&2
    exit 80
  fi

  if [[ ! -r "${SSHD_AUTHORIZED_KEYS}" ]]; then
    echo "core-entrypoint: REMOTE_SSHD=1 but ${SSHD_AUTHORIZED_KEYS} is not readable" >&2
    exit 80
  fi

  # sshd's StrictModes rejects these too, but it does so per connection and only
  # in its own log. Naming the problem at startup keeps it a visible failure.
  local authorized_keys_owner authorized_keys_mode
  authorized_keys_owner=$(stat -c %u "${SSHD_AUTHORIZED_KEYS}")
  authorized_keys_mode=$(stat -c %a "${SSHD_AUTHORIZED_KEYS}")

  if [[ "${authorized_keys_owner}" != "0" && "${authorized_keys_owner}" != "${WORKLOAD_UID}" ]]; then
    echo "core-entrypoint: ${SSHD_AUTHORIZED_KEYS} must be owned by root or ${WORKLOAD_USER}" >&2
    exit 80
  fi

  if (( (8#${authorized_keys_mode} & 8#022) != 0 )); then
    echo "core-entrypoint: ${SSHD_AUTHORIZED_KEYS} is group- or other-writable" >&2
    exit 80
  fi

  mkdir -p "$(dirname "${SSHD_HOST_KEY}")" "$(dirname "${SSHD_PID_FILE}")"
  chmod 0700 "$(dirname "${SSHD_HOST_KEY}")"

  # The host key lives on a named volume so the client's known_hosts entry
  # survives container recreation. It is generated here, never baked into an
  # image layer, and never printed.
  if [[ ! -f "${SSHD_HOST_KEY}" ]]; then
    ssh-keygen -q -t ed25519 -N "" -f "${SSHD_HOST_KEY}"
  fi
  chmod 0600 "${SSHD_HOST_KEY}"
  if [[ -f "${SSHD_HOST_KEY}.pub" ]]; then
    chmod 0644 "${SSHD_HOST_KEY}.pub"
  fi

  # A container restart re-runs this entrypoint; do not start a second sshd.
  local running_pid=""
  if [[ -f "${SSHD_PID_FILE}" ]]; then
    running_pid=$(cat "${SSHD_PID_FILE}")
  fi

  if [[ "${running_pid}" =~ ^[0-9]+$ ]] &&
     kill -0 "${running_pid}" 2>/dev/null &&
     [[ "$(cat "/proc/${running_pid}/comm" 2>/dev/null)" == "sshd" ]]
  then
    echo "core-entrypoint: sshd already running (pid ${running_pid}); leaving it alone" >&2
    return 0
  fi

  rm -f "${SSHD_PID_FILE}"
  "${SSHD_BIN}" -t -f "${SSHD_CONFIG}"
  "${SSHD_BIN}" -f "${SSHD_CONFIG}"
  echo "core-entrypoint: sshd listening on 2222 as ${WORKLOAD_USER}" >&2
}

if (( EUID == WORKLOAD_UID )); then
  # No root control plane in play: `userns_mode: keep-id` already maps this
  # process to the host-shaped workload user directly, so there is nothing
  # left to chown or drop privilege from. Run the workload as-is.
  if [[ "${REMOTE_SSHD:-0}" == "1" ]]; then
    start_remote_sshd
  fi

  exec "$@"
fi

if [[ "${REMOTE_SSHD:-0}" == "1" ]]; then
  # The sshd path owns its files as ${WORKLOAD_USER}. Starting it from the root
  # branch would create a root-owned host key and PID file that the workload
  # user cannot manage on the next start, so refuse instead of half-working.
  echo "core-entrypoint: REMOTE_SSHD=1 requires the keep-id path (EUID ${WORKLOAD_UID}), got ${EUID}" >&2
  exit 80
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
