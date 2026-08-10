#!/bin/bash -p
set -uo pipefail

readonly PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
unset BASH_ENV ENV CDPATH

readonly WORKLOAD_MAX_BACKOFF_SECONDS=30
readonly WORKLOAD_BACKOFF_RESET_SECONDS=30

workload_pid=""
workload_started_at=0
workload_restarts=0
stop_requested=0

log() {
  printf 'core-dev-supervisor: %s\n' "$*" >&2
}

process_is_running() {
  local pid=$1

  [[ "${pid}" =~ ^[0-9]+$ ]] && kill -0 "${pid}" 2>/dev/null
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

shutdown() {
  stop_requested=1
  trap - TERM INT
  log "shutdown requested"
  terminate_process_group development-workload "${workload_pid}" || true

  if [[ -n "${workload_pid}" ]]; then
    wait "${workload_pid}" 2>/dev/null || true
  fi

  exit 0
}

trap shutdown TERM INT

start_workload() {
  # Foreman signals its complete process group when any Procfile process
  # exits. Keep that group separate from PID 1 so Foreman's shutdown cannot
  # terminate this supervisor before it has reaped the workload.
  setsid "$@" &
  workload_pid=$!
  workload_started_at=$(date +%s)
  log "started development workload process ${workload_pid}: $*"
}

if (( $# == 0 )); then
  log "development workload command is required"
  exit 64
fi

start_workload "$@"

while (( stop_requested == 0 )); do
  if ! process_is_running "${workload_pid}"; then
    wait "${workload_pid}"
    workload_status=$?

    workload_uptime=$(( $(date +%s) - workload_started_at ))
    if (( workload_uptime >= WORKLOAD_BACKOFF_RESET_SECONDS )); then
      workload_restarts=0
    fi
    workload_restarts=$((workload_restarts + 1))

    workload_backoff=$(( 1 << (workload_restarts - 1) ))
    if (( workload_backoff > WORKLOAD_MAX_BACKOFF_SECONDS )); then
      workload_backoff=${WORKLOAD_MAX_BACKOFF_SECONDS}
    fi

    # The workload's failure does not tear down this supervisor: the
    # container's own liveness must not depend on any single Procfile.dev
    # process (web/vite/jobs) staying up -- foreman kills its whole group
    # when one of them exits, but that should not take the container down.
    log "development workload exited with status ${workload_status} (restart #${workload_restarts}); retrying in ${workload_backoff}s"

    sleep "${workload_backoff}" &
    wait $!

    if (( stop_requested == 1 )); then
      break
    fi

    start_workload "$@"
  fi

  sleep 1 &
  wait $!
done
