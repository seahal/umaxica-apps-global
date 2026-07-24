#!/usr/bin/env bash
set -uo pipefail

readonly TAILSCALE_BIN=/usr/local/bin/tailscale
readonly TAILSCALED_BIN=/usr/local/bin/tailscaled
readonly TAILSCALE_SOCKET=/run/tailscale/tailscaled.sock
readonly TAILSCALE_STATE_DIR=/var/lib/tailscale-core
readonly LOGIN_ENVIRONMENT_SOURCE=/home/global/workspace/.devcontainer/tailscale-core-login-environment.sh
readonly LOGIN_ENVIRONMENT_TARGET=/etc/profile.d/umaxica-core-development.sh
readonly MAX_TAILSCALED_RESTARTS=3

workload_pid=""
tailscaled_pid=""
tailscaled_restarts=0
stop_requested=0

log() {
  printf 'tailscale-core: %s\n' "$*" >&2
}

process_is_running() {
  local pid=$1

  [[ "${pid}" =~ ^[0-9]+$ ]] && sudo -n kill -0 "${pid}" 2>/dev/null
}

terminate_process() {
  local name=$1
  local pid=$2
  local remaining=10

  if ! process_is_running "${pid}"; then
    return 0
  fi

  log "stopping ${name} process ${pid}"
  if ! sudo -n kill -TERM "${pid}"; then
    log "failed to send TERM to ${name} process ${pid}"
    return 1
  fi

  while process_is_running "${pid}" && (( remaining > 0 )); do
    sleep 1
    remaining=$((remaining - 1))
  done

  if process_is_running "${pid}"; then
    log "${name} process ${pid} did not stop after 10 seconds; sending KILL"
    sudo -n kill -KILL "${pid}" || log "failed to send KILL to ${name} process ${pid}"
  fi
}

terminate_process_group() {
  local name=$1
  local leader_pid=$2
  local remaining=10

  if ! process_is_running "${leader_pid}"; then
    return 0
  fi

  log "stopping ${name} process group ${leader_pid}"
  if ! kill -TERM -- "-${leader_pid}"; then
    log "failed to send TERM to ${name} process group ${leader_pid}"
    return 1
  fi

  while process_is_running "${leader_pid}" && (( remaining > 0 )); do
    sleep 1
    remaining=$((remaining - 1))
  done

  if process_is_running "${leader_pid}"; then
    log "${name} process group ${leader_pid} did not stop after 10 seconds; sending KILL"
    kill -KILL -- "-${leader_pid}" ||
      log "failed to send KILL to ${name} process group ${leader_pid}"
  fi
}

stop_tailscaled() {
  terminate_process tailscaled "${tailscaled_pid}" || true
  if [[ -n "${tailscaled_pid}" ]]; then
    wait "${tailscaled_pid}" 2>/dev/null || true
  fi
  tailscaled_pid=""
}

shutdown() {
  stop_requested=1
  trap - TERM INT
  log "shutdown requested"
  terminate_process_group development-workload "${workload_pid}" || true
  stop_tailscaled

  if [[ -n "${workload_pid}" ]]; then
    wait "${workload_pid}" 2>/dev/null || true
  fi

  exit 0
}

trap shutdown TERM INT

start_tailscaled() {
  local remaining=20

  if [[ ! -x "${TAILSCALE_BIN}" || ! -x "${TAILSCALED_BIN}" ]]; then
    log "Tailscale tools are unavailable; local development remains available"
    return 1
  fi
  if ! sudo -n install -d -m 0755 -o root -g root /run/tailscale; then
    log "failed to prepare /run/tailscale; local development remains available"
    return 1
  fi
  if ! sudo -n install -d -m 0700 -o root -g root "${TAILSCALE_STATE_DIR}"; then
    log "failed to secure ${TAILSCALE_STATE_DIR}; local development remains available"
    return 1
  fi

  sudo -n "${TAILSCALED_BIN}" \
    --tun=userspace-networking \
    --socket="${TAILSCALE_SOCKET}" \
    --statedir="${TAILSCALE_STATE_DIR}" &
  tailscaled_pid=$!
  log "started userspace tailscaled process ${tailscaled_pid}"

  while (( remaining > 0 )); do
    if ! process_is_running "${tailscaled_pid}"; then
      wait "${tailscaled_pid}" 2>/dev/null
      local status=$?
      log "tailscaled exited during startup with status ${status}"
      tailscaled_pid=""
      return 1
    fi
    if sudo -n test -S "${TAILSCALE_SOCKET}"; then
      log "tailscaled is ready; authenticate interactively with the documented tailscale up command"
      return 0
    fi
    sleep 1
    remaining=$((remaining - 1))
  done

  log "tailscaled socket was not ready after 20 seconds"
  stop_tailscaled
  return 1
}

install_login_environment() {
  if ! sudo -n install -m 0644 -o root -g root \
    "${LOGIN_ENVIRONMENT_SOURCE}" "${LOGIN_ENVIRONMENT_TARGET}"; then
    log "failed to install the remote development login environment; local development remains available"
    return 1
  fi
}

if (( $# == 0 )); then
  log "development workload command is required"
  exit 64
fi

install_login_environment || true

# Foreman signals its complete process group when any Procfile process exits.
# Keep that group separate from PID 1 so Foreman's shutdown cannot terminate
# this supervisor before it has reaped the workload and stopped tailscaled.
setsid "$@" &
workload_pid=$!
log "started development workload process ${workload_pid}: $*"

if ! start_tailscaled; then
  tailscaled_restarts=1
fi

while (( stop_requested == 0 )); do
  if ! process_is_running "${workload_pid}"; then
    wait "${workload_pid}"
    workload_status=$?
    log "development workload exited with status ${workload_status}; stopping Tailscale"
    stop_tailscaled
    if (( workload_status == 0 )); then
      exit 1
    fi
    exit "${workload_status}"
  fi

  if [[ -n "${tailscaled_pid}" ]] && ! process_is_running "${tailscaled_pid}"; then
    wait "${tailscaled_pid}" 2>/dev/null
    tailscaled_status=$?
    log "tailscaled exited with status ${tailscaled_status}"
    tailscaled_pid=""
    tailscaled_restarts=$((tailscaled_restarts + 1))
  fi

  if [[ -z "${tailscaled_pid}" && ${tailscaled_restarts} -lt ${MAX_TAILSCALED_RESTARTS} ]]; then
    retry_delay=$((tailscaled_restarts + 1))
    log "retrying tailscaled in ${retry_delay} seconds"
    sleep "${retry_delay}"
    if ! start_tailscaled; then
      tailscaled_restarts=$((tailscaled_restarts + 1))
    fi
  elif [[ -z "${tailscaled_pid}" && ${tailscaled_restarts} -eq ${MAX_TAILSCALED_RESTARTS} ]]; then
    log "tailscaled restart limit reached; remote access is degraded but local development remains available"
    tailscaled_restarts=$((tailscaled_restarts + 1))
  fi

  sleep 1 &
  wait $!
done
