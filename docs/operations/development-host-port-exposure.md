# Development Host Port Exposure

Development containers do not publish services to the host's external network interfaces by default.
Where host access is genuinely required, the publication is restricted to loopback.

This is the standing contract for every Compose file in this repository. It is not advice about a
particular service, and a host firewall is not an acceptable substitute for it.

## The Rule

1. **Prefer no publication at all.** If a service is only consumed by other containers, it gets no
   `ports:` entry. Containers reach it by Compose service name over the shared network
   (`primary:5432`, `valkey:6379`, `tempo:3200`).
2. **If the host genuinely needs it, publish to loopback only.** Write the bind address explicitly:
   `127.0.0.1:3000:3000`, never `3000:3000`. A `ports:` entry with no host address makes Podman bind
   `0.0.0.0`, which places the service on every host interface — LAN, Wi-Fi, Ethernet, and Tailscale
   included.
3. **Never publish a datastore.** PostgreSQL (`primary`, `replica`) and Valkey are container-only.
   Convenience is not a reason to add `5432:5432` or `6379:6379`; use `podman compose exec` for a
   shell against them.

## Container Bind and Host Publication Are Separate Decisions

A process binding `0.0.0.0` _inside_ its container is normal and usually required — it is how the
container becomes reachable on the Podman network at all. It says nothing about host exposure, which
is decided solely by `ports:`.

```text
BINDING=0.0.0.0             ->  Rails listens on the core container's own interfaces.
ports: 127.0.0.1:3000:3000  ->  the host reaches it only from the host itself.
ports: 3000:3000            ->  every machine on the LAN reaches it.  <- not allowed
```

`compose.yaml` therefore keeps `BINDING: "0.0.0.0"` and `VITE_RUBY_HOST: "0.0.0.0"`, and leaves
fakecloud on its default `0.0.0.0:4566` container bind. Do not "harden" those to `127.0.0.1`: that
would break `cloudflare-tunnel`, `bin/tunnel-origin-check`, and every container-to-container call,
while changing nothing about host exposure.

## Current Publications

| Service                                                    | Host publication           | Why                                                                                                                     |
| ---------------------------------------------------------- | -------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `core` (Rails, 3000)                                       | `127.0.0.1:3000`           | The browser opens the documented `http://<service>.<surface>.localhost:3000` origins, which resolve to `127.0.0.1`.     |
| `core` (Vite, 3036)                                        | `127.0.0.1:3036`           | `@vite/client` opens its HMR socket to the dev server from the browser.                                                 |
| `fakecloud` (4566)                                         | `127.0.0.1`                | OpenTofu and the AWS CLI run on the host against the local AWS emulator. Not a datastore. See `local-aws-fakecloud.md`. |
| `primary`, `replica`                                       | none                       | Reached as `primary:5432` / `replica:5432`.                                                                             |
| `valkey`                                                   | none                       | Reached as `valkey:6379`.                                                                                               |
| `loki`, `tempo`, `grafana`, `prometheus`, `otel-collector` | none                       | The `observability` profile is entirely container-internal.                                                             |
| `cloudflare-tunnel`                                        | none, and none is possible | The connector is outbound-only.                                                                                         |

IPv6: rootless Podman publishes these as IPv4 only, so no `::`-bound listener is created. The
loopback form pins the IPv4 side explicitly. If a future service needs IPv6 loopback, write
`[::1]:PORT:PORT` as a second, equally explicit entry — never a bare `PORT:PORT`.

## Kafka

There is no Kafka broker in this stack. The standalone `cp-kafka` service was removed along with
RustFS: nothing consumed it (no `rdkafka`, `racecar`, `ruby-kafka`, or `karafka` dependency exists,
and the `opentelemetry-instrumentation-*` entries in `Gemfile.lock` instrument clients that are not
installed). Amazon MSK is now modelled through `fakecloud`, which serves the MSK **control plane**
only, because giving it a container runtime socket to spawn a real broker would grant it the
invoking user's full container-management rights. See `local-aws-fakecloud.md`.

## Container Runtime Sockets

No service mounts `/var/run/docker.sock` or a Podman socket, and none may. A socket mount is a
larger grant than any port publication: it lets the container start arbitrary images and bind-mount
arbitrary host paths as the invoking user, which no `ports:` entry can do.
`test/tooling/compose_host_port_exposure_test.rb` enforces this.

## Cloudflare Tunnel

`cloudflare-tunnel` needs no inbound host port and must never be given one. It dials Cloudflare
outbound over QUIC (UDP 7844) and resolves the Rails origin over Global's private Podman network:

```text
cloudflare-tunnel -> frontend network -> core:3000 (Rails)
```

The Edge Worker reaches Rails through its Cloudflare Workers VPC Service binding; the Edge and
Global compose projects do not share a host Podman network. Tunnel and VPC Service routing live in
the Cloudflare account, not in this repository. The Rails target must name a `frontend` service
address. A target pointing at `host.docker.internal:3000` would route Cloudflare traffic back out
through the host and is not supported by this contract — see
`docs/operations/cloudflare-private-origin.md`.

## Verification

Run on the **host**, not inside a container:

```sh
podman ps --format 'table {{.Names}}\t{{.Ports}}'
sudo ss -lntup | grep -E ':(3000|3036|4566|5432|6379)\b'
```

Expected: `primary`, `replica`, and `valkey` show a bare container port with no `->` mapping. `core`
shows `127.0.0.1:3000->3000/tcp` and `127.0.0.1:3036->3036/tcp`, and `fakecloud` shows
`127.0.0.1:4566->4566/tcp`. No line anywhere contains `0.0.0.0:3000`, `0.0.0.0:3036`,
`0.0.0.0:4566`, `*:3000`, `*:3036`, or `*:4566`.

From a second machine on the same LAN, both of these must fail to connect:

```sh
curl --max-time 5 http://<host-lan-ip>:3000/health
curl --max-time 5 http://<host-lan-ip>:3036/
```

`bin/tunnel-origin-check` remains the gate for the container-network path, and Gate 4 of
`docs/operations/cloudflare-private-origin.md` requires `podman compose config` to show no new host
port publication.

## Out of Scope

GitHub Actions `services:` blocks in `.github/workflows/` publish `5432` and `6379` on the runner.
That is a different threat model — a single-use runner VM with no LAN neighbours and no persistent
data — and the addresses are runner-local. This contract governs Compose files only, and
`test/tooling/compose_host_port_exposure_test.rb` checks Compose files only.

## Review Checklist

Reject a change that adds any of the following without an entry in the table above:

- a `ports:` value with no explicit host address
- any publication of 5432 or 6379, or any container runtime socket mount
- a `network_mode: host` service
- a `--publish`/`-p` flag in a script that omits the bind address
