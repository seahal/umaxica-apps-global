# This file is sourced by login shells inside the development container.
# Tailscale SSH intentionally starts sessions with a minimal environment, so
# copy the development workload environment from PID 1 for remote development.
if [ -z "${BASH_VERSION:-}" ]; then
  return 0
fi

if [[ -n "${SSH_CONNECTION:-}" && -r /proc/1/environ ]]; then
  while IFS= read -r -d '' assignment; do
    name=${assignment%%=*}

    [[ "${name}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue

    case "${name}" in
      TS_AUTH* | TAILSCALE_AUTH* | TUNNEL_TOKEN* | CLOUDFLARED_TOKEN*)
        continue
        ;;
    esac

    export "${assignment}" 2>/dev/null || true
  done < /proc/1/environ

  unset assignment name
fi
