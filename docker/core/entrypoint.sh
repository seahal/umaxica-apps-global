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

# Remote SSH endpoint for the Mac Codex App (docs/operations/
# remote-codex-over-tailscale.md). Opt-in: only the devcontainer override sets
# REMOTE_SSHD=1; base compose and production never reach this block.
if [ "${REMOTE_SSHD:-0}" = "1" ]; then
  SSHD_CONFIG=/etc/umaxica/sshd_config
  AUTHORIZED_KEYS=/etc/ssh/authorized_keys.d/global
  HOST_KEY=/var/lib/remote-sshd/ssh_host_ed25519_key
  GLOBAL_USER_ID=$(id -u global)

  if [ ! -x /usr/sbin/sshd ]; then
    echo "REMOTE_SSHD=1 but /usr/sbin/sshd is missing (development image only)" >&2
    exit 1
  fi
  if [ ! -r "${SSHD_CONFIG}" ]; then
    echo "REMOTE_SSHD=1 but ${SSHD_CONFIG} is not mounted" >&2
    exit 1
  fi
  if [ ! -f "${AUTHORIZED_KEYS}" ] || [ ! -s "${AUTHORIZED_KEYS}" ]; then
    echo "REMOTE_SSHD=1 but ${AUTHORIZED_KEYS} is missing or empty" >&2
    exit 1
  fi
  if [ ! -r "${AUTHORIZED_KEYS}" ]; then
    echo "REMOTE_SSHD=1 but ${AUTHORIZED_KEYS} is not readable by global" >&2
    exit 1
  fi

  AUTHORIZED_KEYS_OWNER=$(sudo stat -c %u "${AUTHORIZED_KEYS}")
  AUTHORIZED_KEYS_MODE=$(sudo stat -c %a "${AUTHORIZED_KEYS}")
  if [ "${AUTHORIZED_KEYS_OWNER}" != "0" ] \
    && [ "${AUTHORIZED_KEYS_OWNER}" != "${GLOBAL_USER_ID}" ]; then
    echo "REMOTE_SSHD=1 but ${AUTHORIZED_KEYS} must be owned by root or global" >&2
    exit 1
  fi
  if (( (8#${AUTHORIZED_KEYS_MODE} & 8#022) != 0 )); then
    echo "REMOTE_SSHD=1 but ${AUTHORIZED_KEYS} is group- or other-writable" >&2
    exit 1
  fi

  # sshd's privilege-separation directory must exist and be root-owned 0755.
  sudo install -d -m 0755 -o root -g root /run/sshd

  # The host key lives on the remote-sshd volume so the client's known_hosts
  # entry survives container recreation; it is never baked into the image.
  sudo install -d -m 0700 -o root -g root "$(dirname "${HOST_KEY}")"
  if ! sudo test -f "${HOST_KEY}"; then
    sudo ssh-keygen -q -t ed25519 -N "" -f "${HOST_KEY}"
  fi
  sudo chown root:root "${HOST_KEY}"
  sudo chmod 0600 "${HOST_KEY}"
  if sudo test -f "${HOST_KEY}.pub"; then
    sudo chown root:root "${HOST_KEY}.pub"
    sudo chmod 0644 "${HOST_KEY}.pub"
  fi

  # Entrypoint reruns (container restart) must not double-start sshd.
  SSHD_PID=""
  if sudo test -f /run/sshd/sshd.pid; then
    SSHD_PID=$(sudo cat /run/sshd/sshd.pid)
  fi
  if [[ "${SSHD_PID}" =~ ^[0-9]+$ ]] \
    && sudo kill -0 "${SSHD_PID}" 2>/dev/null \
    && [ "$(sudo cat "/proc/${SSHD_PID}/comm" 2>/dev/null)" = "sshd" ]; then
    echo "sshd already running (pid ${SSHD_PID}); skipping start"
  else
    sudo rm -f /run/sshd/sshd.pid
    sudo /usr/sbin/sshd -t -f "${SSHD_CONFIG}"
    sudo /usr/sbin/sshd -f "${SSHD_CONFIG}"
  fi
fi

exec "$@"
