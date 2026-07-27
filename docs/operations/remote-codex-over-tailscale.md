# Direct-Core Development Access over Tailscale

## Current architecture

The development-only `core` image contains digest-pinned `tailscale` and
`tailscaled` binaries. The PID 1 wrapper starts the normal `bin/dev` workload
and a userspace-networking daemon in parallel:

```text
Tailnet client
  +-- Tailscale SSH --> core built-in Tailscale SSH --> global
  `-- HTTPS Serve --> core userspace tailscaled --> 127.0.0.1:3000

core PID 1 (root): tailscale-core-supervisor
  +-- setpriv --> global --> bin/dev --> Foreman --> Rails, Vite, jobs
  `-- tailscaled --tun=userspace-networking
```

There is no Tailscale sidecar, OpenSSH server, TCP port 22 forwarding,
`/dev/net/tun`, `NET_ADMIN`, privileged mode, or host-network mode. This is
Tailscale SSH, not OpenSSH over Tailscale. The independent Cloudflare Tunnel
sidecar remains responsible for its Web, Access, and Workers VPC paths.

The official machine name is `umaxica-global-core`. Its tailnet-only Serve URL
is configured by Tailscale and must also be supplied to Rails as the exact
`TAILSCALE_SERVE_HOST`; the application does not allow a broad `.ts.net` host
pattern.

## Image, state, and trust boundaries

The Tailscale binaries are copied from the digest-pinned official image only
after the Dockerfile enters the `development` target. Production targets do
not contain the binaries or the supervisor.

The named `tailscale-core-state` volume stores the node identity and Serve
configuration under `/var/lib/tailscale-core`. Keep it owner-only. Do not share
it with another node, copy it into an image, or delete it during ordinary
rebuilds. The interactive bootstrap credential is not stored in Compose or in
the repository.

The image does not install `sudo` or assign a password to `global`. A
root-owned entrypoint performs fixed tmpfs initialization, and the root-owned
supervisor runs `tailscaled`; both launch the development workload as `global`
with `setpriv`. The installed control-plane scripts are not loaded from the
writable workspace.

This prevents Rails, Claude Code, Codex, or arbitrary development code running
as `global` from using a general-purpose privilege-escalation command. It does
not protect the container from the host account that owns rootless Podman:
that operator can deliberately enter the container namespace as UID 0 with
`podman exec --user 0`. Credentials mounted for `global` also remain readable
by that user.

## Bootstrap and recovery

An empty state volume requires an explicit interactive login:

```sh
podman exec -it --user 0 global-devcontainer-core \
  /usr/local/bin/tailscale \
  --socket=/run/tailscale/tailscaled.sock login \
  --hostname=umaxica-global-core \
  --accept-dns=false

podman exec --user 0 global-devcontainer-core \
  /usr/local/bin/tailscale \
  --socket=/run/tailscale/tailscaled.sock set \
  --accept-dns=false \
  --ssh
```

Approve only the expected machine name and tailnet. Do not put an auth key in
Compose, `.env`, a command argument, or an image layer for this workflow.

Configure the tailnet-only Rails proxy once; `--bg` stores the configuration in
the persistent state:

```sh
podman exec --user 0 global-devcontainer-core \
  /usr/local/bin/tailscale \
  --socket=/run/tailscale/tailscaled.sock serve \
  --bg http://127.0.0.1:3000
```

Set the returned bare hostname in the shell that creates the container or in
the repository-local, gitignored `.env`:

```text
TAILSCALE_SERVE_HOST=umaxica-global-core.<tailnet>.ts.net
```

This value is a hostname, not a credential. Empty means that Rails does not add
a Tailscale host. A non-empty value that is not a bare `.ts.net` hostname makes
development boot fail rather than silently widening Host Authorization.

## Operation

Check daemon and SSH readiness without printing full Tailnet metadata:

```sh
podman exec --user 0 global-devcontainer-core \
  /usr/local/bin/tailscale-core-status

podman exec --user 0 global-devcontainer-core \
  /usr/local/bin/tailscale \
  --socket=/run/tailscale/tailscaled.sock serve status
```

Connect from an enrolled client:

```sh
ssh global@umaxica-global-core
```

Tailnet SSH policy must allow this node only as `global`; no matching rule may
allow `root`. Tailscale grants are additive, so check broad existing rules as
well as the rule written for this node.

Verify that the session is the real development container:

```sh
hostname
whoami
cat /proc/1/cmdline
cd /home/global/workspace
git rev-parse --show-toplevel
bin/rails runner 'puts Rails.version'
```

The supervisor retries an independently failed `tailscaled` with bounded
backoff. Exhausting that budget degrades remote access but leaves Rails, Vite,
jobs, Claude Code, and the local Dev Container running.

If the development workload (`bin/dev`) exits for any reason, the supervisor
does not tear down Tailscale or terminate itself. It restarts the workload with
exponential backoff (capped at 30 seconds, resetting after 30 seconds of
uptime) and retries indefinitely, so a transient failure -- missing gems,
Postgres not ready yet -- recovers automatically once the underlying cause is
fixed, without needing to recreate the container. Remote SSH access stays
available throughout so a failing workload can be diagnosed in place. TERM and
INT are fanned out and child processes are reaped only on an intentional
shutdown (container stop/recreate), not on a workload crash.

## Cloudflare independence

`cloudflare-tunnel` remains a separate Compose service on `frontend` using QUIC
and `CLOUDFLARED_TOKEN`. Removing the Tailscale sidecar does not change its
image, command, DNS/origin aliases, Access policies, Workers VPC routes, token,
or restart policy. Tailscale SSH/Serve and Cloudflare Tunnel can operate at the
same time because they have independent responsibilities.

## Rollback

During the rollback window, retain the old `tailscale-codex-state` Podman volume
and the Tailnet node renamed `umaxica-global-core-sidecar-retired`. To restore
the legacy path, revert the repository change, rename the current direct node
away from `umaxica-global-core`, recreate the sidecar with its retained state,
and rename the restored sidecar to the official name. Do not run both nodes
under the same machine name.

Removing `TAILSCALE_SERVE_HOST` disables only the Rails Host Authorization
entry. Disable Serve explicitly with `tailscale serve --https=443 off`; disable
SSH with `tailscale set --ssh=false`. Deleting `tailscale-core-state` is a
separate destructive deregistration decision.

## Verified boundary (2026-07-22)

- Rootless Podman rebuilt and recreated `core` without TUN, added capabilities,
  or privileged mode.
- Persistent identity and HTTPS Serve configuration survived recreation and a
  later restart.
- External `ssh global@umaxica-global-core` reached the recreated `core` and
  showed the expected PID 1 supervisor and `bin/dev` command.
- `bin/dev` started Foreman, Rails, Vite, and Solid Queue alongside tailscaled.
- HTTPS Serve reached the same Rails response as localhost. Rails was returning
  HTTP 500 locally at the time, so application-level HTTP success remains a
  separate local Rails issue rather than a tunnel transport failure.
- The legacy sidecar container was stopped and removed. Its state volume and
  retired Tailnet node were deliberately retained for rollback.
- The Cloudflare Tunnel sidecar remained running throughout the cutover.

Host-reboot recovery and deliberate tailscaled failure-injection remain
unverified. The sudo-less control-plane/workload split also remains unverified
against the live host until `core` is explicitly rebuilt and recreated.

## Official references

- [Tailscale SSH](https://tailscale.com/docs/features/tailscale-ssh)
- [Tailscale Serve](https://tailscale.com/docs/features/tailscale-serve)
- [Tailscale Serve CLI](https://tailscale.com/docs/reference/tailscale-cli/serve)
- [Userspace networking](https://tailscale.com/docs/concepts/userspace-networking)
- [Machine names](https://tailscale.com/docs/concepts/machine-names)
