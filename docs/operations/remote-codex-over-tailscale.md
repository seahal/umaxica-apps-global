# Remote Codex over Tailscale

The Codex App reaches a shell inside the `core` development container over the tailnet. SSH
terminates inside `core`, so the session has the workspace, Ruby, Bundler, and pnpm directly —
no `podman exec` hop after login.

## Architecture

```text
Codex App
   |
   |  SSH over Tailscale, tailnet TCP/22
   v
tailscale-core sidecar        userspace networking, no capabilities
   |
   |  TCPForward -> core:2222        (remote-access network only)
   v
core
   +-- sshd, running as `global`
   +-- /home/global/workspace        the repository
   +-- ruby / bundle / pnpm
```

Three properties are load-bearing and should not be "simplified" away.

**Tailscale is not in `core`.** An earlier design ran `tailscaled` inside `core` under a root
PID 1 supervisor. That conflicts with `userns_mode: keep-id` and the deliberate absence of a
`user:` key in `compose.yaml`, which is why it was removed. The daemon lives in its own
container and `core` carries only OpenSSH.

**Tailscale SSH is deliberately not enabled.** `--ssh` would make the *sidecar* the login
target, giving a shell in a container that holds nothing but `tailscaled`. The OpenSSH server
in `core` is the point.

**sshd binds 2222, not 22.** `core` has no root and no `sudo`, so sshd runs as the unprivileged
`global` user and cannot bind a privileged port. The tailnet-facing port is still 22; the
sidecar's `TCPForward` bridges the two. Port 2222 is never published to the host and is
reachable only on the `remote-access` network.

## Privilege boundary

The sidecar declares no `privileged`, no `network_mode: host`, no `/dev/net/tun`, no `cap_add`,
no container-engine socket, and no `ports:`. None are needed: userspace netstack terminates the
tailnet TCP connection inside `tailscaled` and dials `core` as an ordinary socket. Tailscale's
own Docker example pairs `NET_ADMIN`/`NET_RAW` with userspace mode — that is over-provisioned;
do not copy it.

The sidecar joins only `remote-access`. It cannot resolve or reach PostgreSQL, Valkey, or Kafka.

`sshd` disables agent, TCP, and stream-local forwarding, so a compromised session cannot use the
SSH channel as a pivot into the Podman networks.

What this does **not** protect against: the host account that owns rootless Podman can always
enter `core` as UID 0 with `podman exec --user 0`. Anything readable by `global` — including the
sshd host key — is readable by that operator. This is unchanged from normal development.

## Files

| Path | Role |
| --- | --- |
| `compose.custom.yaml` | `tailscale-core` sidecar, `remote-access` network, both volumes, and the `core` overlay |
| `podman/tailscale/serve/serve.json` | `{"TCP":{"22":{"TCPForward":"core:2222"}}}` |
| `podman/core/sshd_config` | Baked to `/etc/umaxica/sshd_config`, root-owned and read-only |
| `podman/core/entrypoint.sh` | `REMOTE_SSHD=1`-gated `start_remote_sshd` |
| `.secrets/codex_authorized_keys` | The Codex App's public key; gitignored |

`docker/` holds byte-identical copies of the `podman/` control-plane files; a contract test
enforces that. Only `podman/` is built into the image.

Tailscale state lives on the `tailscale-core-state` named volume at `/var/lib/tailscale`. The
sshd host key lives on `umaxica-sshd-hostkey` at `/home/global/.local/state/umaxica-sshd`, so the
client's `known_hosts` entry survives container recreation.

## Bootstrap

Remote access is off by default. A developer who does not use it needs to do nothing, and a
plain `podman compose up` never creates, starts, or pulls the sidecar.

**1. Install the Codex App's public key.**

```sh
bin/setup-dev-secrets                      # creates .secrets/codex_authorized_keys if absent
cat >> .secrets/codex_authorized_keys      # paste the PUBLIC key, then Ctrl-D
```

**2. Create a Tailscale auth key** in the admin console with these properties:

- **one-off** (not reusable) — it is revoked immediately after registration
- **tagged** `tag:umaxica-core` — tagged nodes are exempt from user key expiry, which a
  long-lived development container needs
- **pre-approved**, if the tailnet has device approval enabled
- **not ephemeral** — an ephemeral node is deleted when it goes offline, which would destroy
  the identity this design exists to preserve

**3. Enable and start.** Add to the gitignored repository `.env`:

```text
COMPOSE_PROFILES=remote
REMOTE_SSHD=1
TS_AUTHKEY=tskey-auth-...
```

```sh
podman compose -f compose.yaml -f compose.custom.yaml up -d core tailscale-core
```

**4. Confirm registration, then remove the key.**

```sh
podman exec umaxica-apps-global-dc_tailscale-core_1 tailscale status
podman exec umaxica-apps-global-dc_tailscale-core_1 tailscale serve status
```

Once the node appears, **revoke the auth key in the admin console and blank the `TS_AUTHKEY`
line in `.env`**. `TS_AUTH_ONCE=true` means the persisted state alone is sufficient from then
on. Leaving a live key in `.env` is exactly the long-lived credential this procedure avoids.

**5. Grant tailnet access.** The ACL must allow the client machine to reach
`tag:umaxica-core:22`. Tailscale grants are additive: check existing broad rules too, and make
sure none admits `root`.

## Client configuration

```sshconfig
Host core-dev
  HostName umaxica-global-core
  User global
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
```

`HostName` may also be the full `umaxica-global-core.<tailnet>.ts.net`. No `Port` line: the
tailnet-facing port is 22.

## Verification

Confirm the session is really inside `core`, not the sidecar and not the host:

```sh
ssh core-dev
hostname                 # global-devcontainer-core
pwd                      # /home/global/workspace
cat /proc/1/cmdline      # sleep infinity  -- core's PID 1, not tailscaled
git status
ruby --version
bundle --version
pnpm --version
```

`bun` is intentionally absent: this image's JavaScript toolchain is Node 24 with pnpm.

Restart survival, which is the point of persisting state — run it with `TS_AUTHKEY` already
blank:

```sh
podman compose -f compose.yaml -f compose.custom.yaml down
podman compose -f compose.yaml -f compose.custom.yaml up -d core tailscale-core
podman exec umaxica-apps-global-dc_tailscale-core_1 tailscale status
ssh core-dev hostname
```

The node must return under the same name. A name that has drifted to
`umaxica-global-core-1` means the state volume was not preserved.

## Troubleshooting

`core` exits at startup with `core-entrypoint: REMOTE_SSHD=1 but ... is missing or empty` —
the public key was never installed. This is deliberate: a container that came up silently
without its remote path would look healthy while being unreachable. Note that `core` carries
`restart: always`, so this misconfiguration presents as a restart loop rather than a single
exit. Recover by installing the key, or by setting `REMOTE_SSHD=0` in `.env` and recreating —
the message is in `podman logs global-devcontainer-core` either way.

`ssh` connects but is refused — check the ACL grant on `tag:umaxica-core`, then confirm the
forward and the listener:

```sh
podman exec umaxica-apps-global-dc_tailscale-core_1 getent hosts core
podman exec global-devcontainer-core ss -ltn | grep 2222
```

Host key changed after recreation — the `umaxica-sshd-hostkey` volume was deleted. Remove the
stale `known_hosts` entry on the client.

Deleting `tailscale-core-state` deregisters the node and requires a fresh auth key.

## Relationship to Claude Remote Control

`docs/operations/claude-remote-control.md` describes a separate, outbound-only path that needs
no inbound port. The two are independent; neither replaces the other, and running one does not
require the other.
