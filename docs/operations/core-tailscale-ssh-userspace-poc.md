# Core Tailscale SSH Userspace PoC

## Status and scope

This is a development-only proof of concept. It starts `tailscaled` inside the
actual `core` container with userspace networking and without `/dev/net/tun`,
additional Linux capabilities, or privileged mode. It does not replace the
existing `tailscale-codex` sidecar or its OpenSSH and HTTPS Serve paths.

The repository implementation proves local startup and daemon lifecycle only.
It is not accepted as a complete remote-access implementation until an operator
completes Tailnet registration, policy installation, an external Tailscale SSH
login, and the rebuild gates below.

The implementation is limited to:

- `.devcontainer/devcontainer.json`
- `compose.custom.yaml`
- `.devcontainer/tailscale-core-supervisor.sh`
- `.devcontainer/tailscale-core-status.sh`
- the development-only OpenSSH branch in `docker/core/entrypoint.sh`
- dedicated `tailscale-core-tools` and `tailscale-core-state` volumes

No application code or production image stage depends on Tailscale.

## Architecture

```text
external Tailscale client
  -> Tailnet policy: tag:umaxica-core tcp:22
  -> core userspace tailscaled and Tailscale SSH
  -> existing Linux user global in the core PID, mount, and network namespaces

existing compatibility path
  -> tailscale-codex userspace node and TCP Serve port 22
  -> core OpenSSH port 22
```

The `tailscale-core-tools` one-shot service copies pinned binaries from the
official Tailscale image into a read-only mount in `core`. The state volume is
separate from `tailscale-codex`; never share the two state directories.

Use the Podman provider explicitly for manual Compose operations:

```sh
podman compose \
  -f compose.yaml \
  -f .devcontainer/compose.override.yml \
  -f compose.custom.yaml \
  config
```

Do not substitute a separately installed Docker daemon for this project.

## Fail-open local behavior

The supervisor is PID 1 and owns daemon restart, signal forwarding, and bounded
retry behavior. An unauthenticated node, an unavailable control plane, or a
failed `tailscaled` does not stop the local development container. The failure
is logged and the status probe returns a non-zero, distinguishable result.

The custom overlay sets `REMOTE_SSHD_REQUIRED=0`. A valid mounted authorized
keys file still starts legacy OpenSSH. A missing or empty file disables only
legacy OpenSSH and is reported explicitly. Invalid ownership, mode, config, or
host-key setup remains fatal rather than silently weakening SSH validation.

## Operator-owned bootstrap

Do not store an auth key in Compose, the container environment, shell history,
or this repository. Supply it privately on standard input to the Tailscale CLI.
The following command intentionally reads the key from standard input; the
operator must choose a secure secret source and must not print it:

```sh
secure-secret-source | podman exec -i global-devcontainer-core \
  sudo /opt/tailscale/tailscale \
  --socket=/run/tailscale/tailscaled.sock up \
  --auth-key=file:/dev/stdin \
  --hostname=umaxica-global-core-poc \
  --advertise-tags=tag:umaxica-core \
  --accept-dns=false

podman exec global-devcontainer-core \
  sudo /opt/tailscale/tailscale \
  --socket=/run/tailscale/tailscaled.sock set \
  --accept-dns=false \
  --ssh
```

Use a non-ephemeral, preauthorized key only if Tailnet policy permits the tag.
Revoke the bootstrap key after registration. The key is not needed on later
starts while `tailscale-core-state` is retained and the node remains approved.

The implementation deliberately leaves container DNS unchanged. MagicDNS name
resolution from remote clients is a client and Tailnet configuration concern;
it does not require replacing the `core` container's resolver.

## Policy boundary

Network reachability and SSH login authorization are separate, additive policy
decisions. Replace all placeholders before use. Existing broad grants can make
a narrow grant ineffective as a restriction and must be audited separately.

```json
{
  "grants": [
    {
      "src": ["<operator-identity-or-group>"],
      "dst": ["tag:umaxica-core"],
      "ip": ["tcp:22"]
    }
  ],
  "ssh": [
    {
      "action": "check",
      "src": ["<operator-identity-or-group>"],
      "dst": ["tag:umaxica-core"],
      "users": ["global"]
    }
  ]
}
```

Use `check` when periodic reauthentication is acceptable. Use `accept` only
when uninterrupted long-lived sessions are more important than that additional
verification. Test Claude Code, VS Code Remote SSH, concurrent sessions, and
session duration against the selected action before adoption.

## Readiness and failure diagnosis

Run the safe readiness probe without printing peer names or state contents:

```sh
podman exec global-devcontainer-core \
  /home/global/workspace/.devcontainer/tailscale-core-status.sh
```

Exit meanings:

| Exit | Meaning |
| ---: | --- |
| 0 | Backend running, node online, and Tailscale SSH enabled |
| 10 | Tailscale tools unavailable |
| 11 | daemon socket unavailable |
| 12 | daemon not authenticated and online |
| 13 | node online but Tailscale SSH disabled |

`tailscale status` alone is not an acceptance test. The probe also checks the
daemon preferences for `WantRunning` and `RunSSH`.

## Acceptance gates

After registration and policy approval, connect from an existing Tailnet Mac or
Linux client:

```sh
ssh global@umaxica-global-core-poc
```

Raw Tailscale SSH starts in the Linux user's home directory. Change to the
workspace before Rails and Git checks:

```sh
hostname
whoami
cat /proc/1/cmdline
pwd
cd /home/global/workspace
git rev-parse --show-toplevel
ps -ef
bin/rails runner 'puts Rails.version'
```

The result must identify `core`, user `global`, the supervisor as PID 1, and the
same workspace and Git changes as the Dev Container. It must not identify the
`tailscale-codex` container.

Before adoption, repeat the readiness and external SSH checks after each of:

1. `podman restart global-devcontainer-core`
2. Compose `--force-recreate` with all three Compose files
3. Dev Container rebuild
4. host restart

Do not delete `tailscale-core-state` during these tests. Confirm that the same
Tailnet device identity returns and no duplicate node is created.

Also test each failure independently: no registration, control-plane outage,
missing state, invalid auth key, unauthorized tag, pending device approval,
SSH-policy rejection, missing Linux user, and forced daemon termination. Every
case must remain locally usable and produce a distinguishable error.

## State transitions

| Event | State volume | Expected result |
| --- | --- | --- |
| Container restart | retained | same node identity; daemon and SSH preference restored |
| Container recreation | retained | same node identity |
| Image rebuild | retained | same node identity; pinned binaries refreshed only by the tools service |
| Compose down/up | retained | same node identity |
| Host restart | retained | same node identity after Podman starts the project |
| State volume loss | lost | new registration and usually a new node identity required |
| Auth key expiry/revocation | retained | existing registered node continues; key cannot bootstrap a replacement |
| Device approval removed | retained | identity persists locally but Tailnet access is blocked pending approval |
| Node key expiry | retained | reauthentication is required according to Tailnet policy |

## Rollback

Rollback does not require deleting state or stopping the compatibility sidecar:

1. Remove the `core` command, environment, and two volume mounts from
   `compose.custom.yaml`.
2. Remove the `tailscale-core-tools` service and the two dedicated volume
   declarations after deciding whether state retention is still needed.
3. Restore the prior Dev Container command behavior.
4. Remove the two `.devcontainer/tailscale-core-*.sh` scripts and this document.
5. Rebuild the Dev Container only after the existing sidecar OpenSSH route is
   verified.

Volume deletion is a separate destructive operation and is not part of routine
rollback. Tailnet device and policy removal are operator-owned external steps.
