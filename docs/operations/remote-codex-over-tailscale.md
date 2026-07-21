# Remote Codex over Tailscale

This runbook connects the macOS Codex App to the `core` Rails development
container without installing OpenSSH, Tailscale, or Codex on the Linux host.
It does not publish SSH on the host and does not mount a Podman or Docker
socket into either container.

## Architecture

```text
Mac Codex App, OpenSSH client, Tailscale client, dedicated private key
  |
  | SSH over the tailnet
  v
tailscale-codex sidecar
  | userspace Tailscale networking; TCP relay only
  | remote-access Podman bridge
  v
OpenSSH server in the core development container
  | public-key login as global
  v
Codex App Server in /home/global/workspace
```

SSH terminates in `core`. The sidecar does not run an SSH server, and
Tailscale SSH is not enabled. The setup does not attach to an existing Codex
CLI TUI. The Codex App starts and manages a remote Codex App Server through
the SSH connection.

The remote components are declared only in
`.devcontainer/compose.override.yml`. Base `compose.yaml` does not declare the
sidecar, `remote-access` network, or remote state volumes. Only the Dockerfile
development target installs `openssh-server`; production targets do not
inherit the development target.

## Security boundaries

- The Linux host receives no port 22 listener, OpenSSH daemon, Tailscale
  daemon, Codex installation, wrapper, or container socket mount.
- `tailscale-codex` uses Tailscale userspace networking without a TUN device,
  host networking, published ports, or requested capabilities.
- SSH permits only `global` with public-key authentication. Root, passwords,
  keyboard-interactive authentication, agent forwarding, X11, tunnels, TCP
  forwarding, and stream-local forwarding are disabled.
- The Mac private key remains on the Mac. The Linux host file
  `agent-authorized-keys` contains public keys only.
- The Linux host's `~/.ssh` directory is not mounted into `core`.
- General host configuration and guarded workspace paths use Compose
  long-syntax read-only bind mounts. Gate C must verify that the selected
  Podman Compose provider preserves the effective read-only flags.
- `~/.codex`, `~/.claude`, and `~/.claude.json` remain writable host bind
  mounts because those tools update authentication and state. A compromised
  `core` process can read or modify those files and the writable workspace.
- A compromised sidecar can connect to any listener in `core` on the shared
  `remote-access` bridge, including Rails or Vite when they listen on all
  interfaces. The bridge does not provide per-port filtering. The sidecar is
  not attached to database, frontend, observability, or outer networks.
- The `tailscale-codex-state` volume contains the long-lived Tailscale node
  identity. The `remote-sshd` volume contains the SSH host private key. Treat
  both as credentials even though neither enters Git or an image layer.
- Rootless Podman reduces privilege but does not make the residual risk zero.
  The Linux kernel, container runtime, container images, Dev Container
  Features, host bind mounts, and agents running in `core` remain trust
  boundaries.

## Repository and external state

Repository files:

| Path | Purpose |
|---|---|
| `.devcontainer/compose.override.yml` | Dev-only SSH mounts, `remote-access`, named volumes, and the profile-gated sidecar |
| `.devcontainer/devcontainer.json` | Dev Container Features and intentionally writable tool state mounts |
| `Dockerfile` | OpenSSH package and mount-point directories in the development target only |
| `docker/core/entrypoint.sh` | Fail-fast SSH prerequisites, persistent host-key creation, validation, and startup |
| `docker/core/sshd_config` | Complete custom OpenSSH server policy |
| `docker/tailscale/serve/serve.json` | Tailnet TCP 22 to `core:22` forwarding spike |

Operator-managed Linux host files:

```text
~/.config/umaxica/tailscale.env
~/.config/umaxica/agent-authorized-keys
```

The first file temporarily contains `TS_AUTHKEY` and must be mode 0600. The
second contains only Mac public keys, but is also mode 0600 to satisfy a
conservative OpenSSH policy. These paths are outside the repository, so this
repository's `.gitignore` does not and cannot protect them.

Persistent Podman volumes:

```text
tailscale-codex-state
remote-sshd
```

Compose scopes the actual volume names by project. Discover their final names
with `podman volume ls`; do not assume the unscoped names when removing them.

## Enablement model

The Dev Container override sets `REMOTE_SSHD=1`, mounts the authorized keys
and SSH configuration, and attaches `core` to `remote-access`. Therefore the
external authorized-keys file must exist before every Dev Container rebuild.

The `tailscale-codex` service has the `remote` profile and does not start with
an ordinary Dev Container launch. With no sidecar attached, there is no
tailnet ingress path to the internal SSH listener. Enabling the `remote`
profile starts only the sidecar; disabling or stopping that service removes
tailnet ingress without recreating `core`.

## Prerequisites

The Linux host needs rootless Podman, a working Podman Compose provider, and
the existing Dev Containers workflow. The Mac needs the Codex App, OpenSSH,
and a Tailscale client connected to the same tailnet. The Linux host must not
run a host Tailscale daemon or host OpenSSH server for this design.

Before rebuilding the Dev Container, confirm that the pre-existing host
configuration sources referenced by the override exist:

```sh
test -d "$HOME/.config/git"
test -f "$HOME/.gitconfig"
test -d "$HOME/.config/gh"
test -d "$HOME/.config/opencode"
test -f /etc/timezone
```

Missing paths are errors. Do not replace them with repository-local secret
copies or silent fallbacks.

## Tailnet policy and auth key

Define `tag:umaxica-core` in the tailnet policy and assign a tag owner. Add a
grant whose source identifies only the intended Mac user or device and whose
destination is `tag:umaxica-core` on `tcp:22`. The policy shape is:

```json
{
  "tagOwners": {
    "tag:umaxica-core": ["<tailnet-admin-selector>"]
  },
  "grants": [
    {
      "src": ["<mac-user-or-device-selector>"],
      "dst": ["tag:umaxica-core"],
      "ip": ["tcp:22"]
    }
  ]
}
```

Merge this into the existing tailnet policy instead of replacing unrelated
rules. Use the policy editor's tests before saving. Create a one-time,
pre-authorized auth key tagged with `tag:umaxica-core`. Verify that the tag
owner permits the key to assign that tag.

An auth key is a bootstrap credential, not the node's persistent identity.
After registration, revoke the key, remove it from the env file, recreate the
sidecar to remove it from container inspect data, and retain the state volume.

## Mac SSH key

Generate a dedicated key on the Mac. Do not reuse a personal or Git key.

```sh
umask 077
ssh-keygen -t ed25519 \
  -f "$HOME/.ssh/umaxica-core" \
  -C "umaxica-core-remote-codex"
```

Transfer only `~/.ssh/umaxica-core.pub` to the Linux host by a trusted local
method. Never copy the private file `~/.ssh/umaxica-core` to Linux or into a
container.

## Linux host files

Create the external directory and files on the Linux host:

```sh
install -d -m 0700 "$HOME/.config/umaxica"
install -m 0600 /dev/null "$HOME/.config/umaxica/tailscale.env"
install -m 0600 /dev/null "$HOME/.config/umaxica/agent-authorized-keys"
```

Open `tailscale.env` in an editor and add the bootstrap key:

```text
TS_AUTHKEY=<one-time-pre-authorized-tagged-key>
```

Do not put the key directly in a shell command, shell history, Compose YAML,
or repository file. Put the Mac public key line in
`agent-authorized-keys`, then verify metadata without printing either file:

```sh
chmod 0600 \
  "$HOME/.config/umaxica/tailscale.env" \
  "$HOME/.config/umaxica/agent-authorized-keys"

test -s "$HOME/.config/umaxica/tailscale.env"
test -s "$HOME/.config/umaxica/agent-authorized-keys"
stat -c '%n %U:%G %a' \
  "$HOME/.config/umaxica/tailscale.env" \
  "$HOME/.config/umaxica/agent-authorized-keys"
```

## Build and start

Rebuild `core` with the existing Dev Containers command or UI. Do not run
`podman compose build core`: Codex is installed by the
`ghcr.io/jsburckhardt/devcontainer-features/codex:1` Feature, and a raw
Compose build does not apply Dev Container Features.

For VS Code, run **Dev Containers: Rebuild Container**. Confirm that the
rebuilt container is named `global-devcontainer-core` before continuing.

From a Linux host terminal in the repository root, identify the provider and
validate both the default and remote-profile models:

```sh
podman compose version
podman info --format '{{.Host.OCIRuntime.Name}}'
printf 'PODMAN_COMPOSE_PROVIDER=%s\n' "${PODMAN_COMPOSE_PROVIDER:-<unset>}"

remote_compose=(
  podman compose
  -f compose.yaml
  -f .devcontainer/compose.override.yml
)

"${remote_compose[@]}" config
"${remote_compose[@]}" --profile remote config

if podman compose -f compose.yaml config --services |
  grep -Fxq tailscale-codex
then
  echo "ERROR: tailscale-codex entered base Compose" >&2
  exit 1
fi
```

`podman compose` delegates to an external provider. If the provider rejects
profiles, `!reset`, long-syntax bind mounts, `${HOME:?...}` interpolation, or
the merged network model, stop and record the provider name, version, and
exact error. Do not rewrite the configuration around an unknown provider.

Pull and record the official image identity:

```sh
podman pull tailscale/tailscale:v1.98.9
podman image inspect tailscale/tailscale:v1.98.9 \
  --format '{{json .RepoDigests}}'
```

Start only the sidecar. `--no-deps` prevents Compose from recreating the
Dev-Container-Feature-built `core` service:

```sh
"${remote_compose[@]}" --profile remote \
  up -d --no-deps tailscale-codex

"${remote_compose[@]}" --profile remote ps
```

## Gate C: Linux host verification

### Production isolation

```sh
podman build --target production -t umaxica-core-prod-check .
podman run --rm umaxica-core-prod-check \
  sh -c 'if command -v sshd; then exit 1; else echo no-sshd; fi'
```

Expected result: `no-sshd`.

### Core tools and read-only mounts

```sh
podman exec global-devcontainer-core \
  sh -lc 'command -v sshd && command -v codex && codex --version'

podman inspect global-devcontainer-core \
  --format '{{range .Mounts}}{{println .Destination .RW}}{{end}}'

podman exec global-devcontainer-core \
  sh -c '
    test ! -e /home/global/.ssh &&
    test ! -w /home/global/.gitconfig &&
    test ! -w /home/global/.config/git &&
    test ! -w /home/global/.config/gh &&
    test ! -w /home/global/.config/opencode &&
    test ! -w /home/global/workspace/.github &&
    test ! -w /home/global/workspace/bin &&
    test ! -w /home/global/workspace/Gemfile &&
    test ! -w /home/global/workspace/Gemfile.lock &&
    test ! -w /home/global/workspace/package.json &&
    test ! -w /home/global/workspace/.devcontainer
  '
```

The workspace and `~/.codex` are intentionally writable. The listed guarded
paths must not be writable. If `/home/global/.ssh` is present as a host bind
mount or any guarded path is writable, do not enable the sidecar.

### SSH server state

```sh
podman exec global-devcontainer-core \
  sudo /usr/sbin/sshd -t -f /etc/umaxica/sshd_config

podman exec global-devcontainer-core \
  sh -lc '
    test -r /etc/ssh/authorized_keys.d/global &&
    sudo test -f /var/lib/remote-sshd/ssh_host_ed25519_key &&
    ss -tln | grep -E "[.:]22[[:space:]]"
  '

podman exec global-devcontainer-core \
  sudo ssh-keygen -lf /var/lib/remote-sshd/ssh_host_ed25519_key
```

Record the host-key fingerprint for comparison after recreation and for
out-of-band verification on the Mac.

### Sidecar boundaries

Resolve the sidecar name without assuming a generated container name:

```sh
tailscale_container="$(
  "${remote_compose[@]}" --profile remote ps -q tailscale-codex
)"
test -n "$tailscale_container"
```

Inspect metadata without printing the environment values:

```sh
podman inspect "$tailscale_container" \
  --format 'privileged={{.HostConfig.Privileged}} network={{.HostConfig.NetworkMode}} caps={{json .EffectiveCaps}}'

podman inspect "$tailscale_container" \
  --format '{{range .Mounts}}{{println .Destination .RW}}{{end}}'

podman inspect "$tailscale_container" |
  jq -e '.[0].Config.Env | any(startswith("TS_AUTHKEY="))'

podman inspect global-devcontainer-core \
  --format '{{json .NetworkSettings.Networks}}'
podman inspect "$tailscale_container" \
  --format '{{json .NetworkSettings.Networks}}'
```

Before key removal, the safe boolean auth-key check is expected to return
`true`. Do not print `.Config.Env`.

Expected sidecar properties:

- not privileged;
- no host network;
- no `/dev/net/tun`;
- no Podman or Docker socket;
- no added capabilities in the service definition;
- only the `remote-access` Compose network;
- Tailscale state volume writable and Serve configuration read-only.

### No host SSH exposure

```sh
ss -tlnp
podman port global-devcontainer-core
podman port "$tailscale_container"
podman inspect global-devcontainer-core \
  --format '{{json .NetworkSettings.Ports}}'
podman inspect "$tailscale_container" \
  --format '{{json .NetworkSettings.Ports}}'
podman ps --format 'table {{.Names}}\t{{.Ports}}'

podman exec global-devcontainer-core \
  sh -c 'test ! -S /var/run/docker.sock && test ! -S /run/podman/podman.sock'
podman exec "$tailscale_container" \
  sh -c 'test ! -S /var/run/docker.sock && test ! -S /run/podman/podman.sock'
```

Existing Rails and Vite host ports may appear. Port 22 must not appear as a
host listener or published container port.

### Auth-key removal and Tailscale state persistence

After the node appears in the Tailscale admin console:

1. Record the node ID and DNS name.
2. Revoke the bootstrap auth key in the admin console.
3. Empty the host env file without deleting it.
4. Recreate only the sidecar.

```sh
podman exec "$tailscale_container" tailscale status --json |
  jq -r '.Self.ID, .Self.DNSName'

: > "$HOME/.config/umaxica/tailscale.env"
chmod 0600 "$HOME/.config/umaxica/tailscale.env"

"${remote_compose[@]}" --profile remote \
  up -d --no-deps --force-recreate tailscale-codex

tailscale_container="$(
  "${remote_compose[@]}" --profile remote ps -q tailscale-codex
)"

podman inspect "$tailscale_container" |
  jq -e '.[0].Config.Env | all(startswith("TS_AUTHKEY=") | not)'

podman exec "$tailscale_container" tailscale status --json |
  jq -r '.Self.ID, .Self.DNSName'
```

The node ID and DNS name must remain stable and the sidecar must remain
online. If it requires another auth key, stop and preserve logs without
posting credentials.

### Core recreation and application connectivity

Run **Dev Containers: Rebuild Container** again. Do not force-recreate `core`
with raw Compose. Repeat the Codex version, mount, sshd configuration,
host-key fingerprint, and network checks. The host-key fingerprint must remain
stable because `remote-sshd` is a named volume.

Then verify the existing application boundary:

```sh
podman exec global-devcontainer-core \
  sh -lc '
    getent hosts primary valkey &&
    nc -z primary 5432 &&
    nc -z valkey 6379 &&
    bin/rails runner "puts Rails.env" &&
    bin/rails test test/models/model_load_test.rb
  '
```

Use the merged Compose output and container inspection to confirm that all
pre-existing `core` networks and aliases remain present. Confirm Vite remains
reachable on its existing development port.

## Gate D: Mac and Codex App verification

Add a concrete alias to the Mac's `~/.ssh/config`:

```text
Host umaxica-core
  HostName umaxica-global-core
  User global
  IdentityFile ~/.ssh/umaxica-core
  IdentitiesOnly yes
```

Codex discovers concrete SSH aliases; a pattern-only `Host *` entry is not
sufficient. If the short MagicDNS hostname does not resolve, obtain the
sidecar's Tailscale IPv4 address on Linux and use that as `HostName`:

```sh
podman exec "$tailscale_container" tailscale ip -4
```

Before accepting a new host key on the Mac, compare the presented fingerprint
with the fingerprint recorded from the `remote-sshd` volume.

Verify terminal SSH first:

```sh
ssh umaxica-core whoami
ssh umaxica-core 'command -v codex && codex --version && printf "%s\n" "$PATH"'

ssh -o BatchMode=yes \
  -o PreferredAuthentications=password \
  -o PubkeyAuthentication=no \
  umaxica-core true

ssh -o BatchMode=yes root@umaxica-core true
```

The first command must print `global`; Codex must resolve to
`/usr/local/bin/codex`; password-only and root login must fail.

In the Codex App, open **Settings > Connections**, add or enable
`umaxica-core`, and select `/home/global/workspace`. Verify that the App can:

- start and manage the remote Codex App Server;
- open the repository rather than an existing CLI TUI;
- run a Rails command and `test/models/model_load_test.rb`;
- access the existing database and Vite development services;
- reconnect after sidecar restart and Dev Container recreation.

While the App is connected, the Linux host may verify the remote process
without changing it:

```sh
podman exec global-devcontainer-core \
  pgrep -af 'codex.*(app-server|remote-control)'
```

Finally, attempt TCP 22 from a tailnet device that is not allowed by the
grant. The connection must time out or be rejected:

```sh
nc -vz umaxica-global-core 22
```

## Unresolved runtime spikes

### Tailscale `TCPForward` to `core:22`

`docker/tailscale/serve/serve.json` contains:

```json
{"TCP":{"22":{"TCPForward":"core:22"}}}
```

Tailscale source accepts a general `host:port` TCP forwarding target and
performs the dial when handling a connection. Official Serve documentation,
however, documents localhost targets and does not guarantee a Compose DNS
peer as a stable public contract. Static addressing is not introduced.

Treat successful Mac SSH through the sidecar as the acceptance test. If name
resolution or forwarding fails, stop. Do not add `socat`, a derived image,
static addressing, `TS_DEST_IP`, host networking, or a published port without
a separate review and approval.

### Codex SSH transport details

Official Codex guidance states that the App starts the remote App Server over
SSH using the remote login shell and requires `codex` on that shell's PATH.
It does not guarantee whether every App release avoids PTY, TCP forwarding,
or stream-local forwarding.

Keep `PermitTTY yes`, `AllowTcpForwarding no`, and
`AllowStreamLocalForwarding no` for the first Gate D test. If the App fails
and diagnostics prove that forwarding is required, stop and propose the
narrowest allowlisted relaxation. Do not enable unrestricted forwarding.

## Primary references

- [Compose Specification](https://compose-spec.github.io/compose-spec/spec.html)
- [Podman Compose provider behavior](https://docs.podman.io/en/stable/markdown/podman-compose.1.html)
- [Podman bind-mount options](https://docs.podman.io/en/stable/markdown/podman-run.1.html)
- [Tailscale Docker parameters](https://tailscale.com/docs/features/containers/docker/docker-params)
- [Tailscale Serve](https://tailscale.com/docs/features/tailscale-serve)
- [OpenSSH `sshd_config`](https://man.openbsd.org/sshd_config)
- [OpenAI Codex manual](https://developers.openai.com/codex/codex-manual.md)

## Troubleshooting

- **Dev Container fails before core starts:** verify every bind source exists,
  `HOME` is set in the provider environment, and the authorized-keys file is
  non-empty, mode 0600, and owned by the host user.
- **Entrypoint reports missing or invalid authorized keys:** correct the host
  file; do not disable `StrictModes` or relax the entrypoint checks.
- **`sshd -t` fails:** inspect only the configuration error. Do not replace the
  custom configuration with distribution defaults.
- **Sidecar restart-loops before registration:** confirm the env file contains
  a valid, unexpired key and the tag owner permits `tag:umaxica-core`. Do not
  paste the key or unredacted inspect output into an issue.
- **Sidecar restart-loops after key removal:** stop and preserve the state
  volume; do not issue another key until state persistence is diagnosed.
- **MagicDNS fails:** use `tailscale ip -4` as the SSH `HostName` fallback.
- **Terminal SSH works but Codex App fails:** capture the App error, core logs,
  and process list. Do not enable forwarding or expose App Server transports
  directly.
- **sshd dies while Rails remains up:** restart the Dev Container after
  recording logs. The entrypoint launches sshd as a daemon, so `bin/dev`
  remains the container lifecycle process and does not monitor sshd.

## Rollback

1. Disable ingress without touching `core`:

   ```sh
   "${remote_compose[@]}" --profile remote stop tailscale-codex
   ```

2. Remove the SSH connection entry and dedicated key from the Mac when they
   are no longer needed.
3. Remove the Tailscale machine from the admin console.
4. Revert only the Remote Codex repository changes and rebuild with Dev
   Containers.
5. Remove the external Linux files when they are no longer required.

Deleting the Tailscale state or SSH host-key volume destroys persistent
identity and invalidates the Mac's recorded SSH host key. Only after explicit
approval, discover the project-scoped names and remove the exact volumes:

```sh
podman volume ls \
  --filter label=com.docker.compose.project=umaxica-apps-global-dc
```

Do not pass broad globs or unverified names to `podman volume rm`.
