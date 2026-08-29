#!/usr/bin/env bash
# `tailscale` for interactive shells in this container.
#
# Baked at /usr/local/bin/tailscale, which PATH puts ahead of the real client at
# /usr/bin/tailscale. The real CLI, run bare, dials the system socket of a
# root tailscaled that this container can never run: no systemd, `cap_drop: ALL`
# and `no-new-privileges` (so no sudo either). This wrapper points every
# invocation at the user-space daemon instead — running as the login account,
# `--tun=userspace-networking`, no capability needed — and starts that daemon on
# first use, so a plain `tailscale up` works in a fresh shell.
#
# The remote-access overlay's entrypoint starts the same daemon on the same
# socket itself; when it has, the probe below sees it alive and this wrapper is
# only the CLI pass-through.
set -euo pipefail

state=${HOME}/.local/state/tailscale
socket=${state}/tailscaled.sock

# `version --daemon` round-trips to the daemon and fails when the socket is
# missing OR stale — a leftover socket file from a stopped container would make
# a bare socket test lie.
if ! /usr/bin/tailscale --socket="${socket}" version --daemon > /dev/null 2>&1; then
  mkdir -p "${state}"
  chmod 0700 "${state}"
  echo 'tailscale: starting user-space tailscaled (log: ~/.local/state/tailscale/tailscaled.log)' >&2
  nohup /usr/sbin/tailscaled \
    --tun=userspace-networking \
    --statedir="${state}" \
    --socket="${socket}" \
    >> "${state}/tailscaled.log" 2>&1 &
  for _ in $(seq 1 50); do
    /usr/bin/tailscale --socket="${socket}" version --daemon > /dev/null 2>&1 && break
    sleep 0.2
  done
  if ! /usr/bin/tailscale --socket="${socket}" version --daemon > /dev/null 2>&1; then
    echo "tailscale: tailscaled did not come up; see ${state}/tailscaled.log" >&2
    exit 69
  fi
fi

exec /usr/bin/tailscale --socket="${socket}" "$@"
