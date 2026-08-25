#!/usr/bin/env bash
# Brings up the Dev Container stack (idempotent) and execs Claude Code Remote
# Control inside `core`. Intended to run as the ExecStart of a systemd --user
# service (see ../claude-remote-control.service.template) so systemd tracks the
# resulting process and can restart it automatically. Never run this as root or
# install any part of this directory into /etc.
#
# WS3B only: this script has no dependency on the Tailscale/Codex sidecar (WS3A).
# See docs/operations/claude-remote-control.md for the full runbook.
set -euo pipefail

WORKSPACE_FOLDER="${UMAXICA_WORKSPACE_FOLDER:?set to the absolute repository path on the host}"
HEALTH_TIMEOUT_SECONDS="${UMAXICA_REMOTE_CONTROL_HEALTH_TIMEOUT:-180}"

log() { printf '%s %s\n' "$(date -Iseconds)" "$*"; }

log "bringing up the Dev Container stack (idempotent; no-op if already running)"
devcontainer up --workspace-folder "${WORKSPACE_FOLDER}"

log "waiting for core to accept exec (timeout ${HEALTH_TIMEOUT_SECONDS}s)"
deadline=$(( $(date +%s) + HEALTH_TIMEOUT_SECONDS ))
until devcontainer exec --workspace-folder "${WORKSPACE_FOLDER}" true 2>/dev/null; do
  if [ "$(date +%s)" -ge "${deadline}" ]; then
    log "core did not become ready within ${HEALTH_TIMEOUT_SECONDS}s"
    exit 1
  fi
  sleep 3
done

log "core is ready; starting claude remote-control (server mode, --spawn=same-dir)"
exec devcontainer exec --workspace-folder "${WORKSPACE_FOLDER}" \
  claude remote-control --spawn=same-dir
