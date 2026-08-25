#!/bin/bash -p
set -uo pipefail

readonly PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PATH
unset BASH_ENV ENV CDPATH

readonly TAILSCALE_BIN=/usr/bin/tailscale
readonly TAILSCALE_SOCKET=/run/tailscale/tailscaled.sock

if (( EUID != 0 )); then
  echo "tailscale-core status: effective UID 0 is required" >&2
  exit 77
fi

if [[ ! -x "${TAILSCALE_BIN}" ]]; then
  echo "tailscale-core status: tools unavailable" >&2
  exit 10
fi

if ! test -S "${TAILSCALE_SOCKET}"; then
  echo "tailscale-core status: daemon socket unavailable" >&2
  exit 11
fi

if ! "${TAILSCALE_BIN}" --socket="${TAILSCALE_SOCKET}" status --json 2>/dev/null |
  jq -e '.BackendState == "Running" and .Self.Online == true' >/dev/null
then
  echo "tailscale-core status: daemon is not authenticated and online" >&2
  exit 12
fi

if ! "${TAILSCALE_BIN}" --socket="${TAILSCALE_SOCKET}" debug prefs 2>/dev/null |
  jq -e '.WantRunning == true and .RunSSH == true' >/dev/null
then
  echo "tailscale-core status: daemon is online but Tailscale SSH is disabled" >&2
  exit 13
fi

echo "tailscale-core status: backend=running online=true want_running=true ssh=true"
