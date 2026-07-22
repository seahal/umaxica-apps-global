# Core Tailscale SSH Userspace PoC Implementation Note

## Decision

Keep the existing sidecar route while adding a development-only, fail-open
userspace `tailscaled` lifecycle inside `core`. Do not authenticate the node or
change Tailnet policy during repository implementation.

## Implementation boundary

The official Tailscale container image is used as a pinned binary source. A
one-shot Compose service populates a named tools volume, which `core` mounts
read-only. A separate named state volume preserves only the in-core node
identity. The supervisor runs as PID 1, starts the daemon with an explicit
socket and state directory, enables SSH only for an already authenticated node,
monitors early and later daemon exits, and shuts down tracked processes on
container termination.

Local development is intentionally fail-open. Remote readiness is fail-closed:
the status probe does not report success unless the backend is running, the node
is online, and the SSH preference is enabled.

## Plan deviation

Changing Dev Container `overrideCommand` from true to false restores the image
entrypoint. The current development host can have a missing or empty legacy
authorized-keys bind, which previously made that entrypoint terminate before
the new supervisor could run. The custom overlay therefore sets
`REMOTE_SSHD_REQUIRED=0`.

This exception applies only to the missing-or-empty authorized-keys case. A
valid file retains the compatibility OpenSSH route. Invalid permissions,
ownership, configuration, or host-key setup still terminates startup. The base
entrypoint remains fail-fast by default because the new behavior requires the
explicit development overlay setting.

## Provider correction

Runtime verification must use Podman explicitly. An early diagnostic command
reached a separate Docker daemon and created project-named temporary resources;
it did not exercise or modify the running Podman project. Subsequent runtime
verification used `podman compose` and a disposable Podman container. Cleanup
of the Docker-only named resources requires separate destructive approval and
must not be conflated with Podman cleanup.

## Verification boundary

Repository tests, Compose merge inspection, a Dev Container image build, and a
disposable rootless Podman container demonstrate the intended command,
userspace daemon startup, no TUN device, no requested capability additions, no
auth-key environment variable, explicit unauthenticated status, state
ownership, and clean signal-driven exit.

They do not prove Tailnet registration, SSH policy authorization, an external
client login, node-identity recovery across rebuilds, or host-restart recovery.
Those remain operator-owned acceptance gates documented in
`docs/operations/core-tailscale-ssh-userspace-poc.md`.
