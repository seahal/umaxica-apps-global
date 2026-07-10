# Plan: split compose contract from devcontainer-local concerns

## Context

The dev loop has two recurring pains:

1. **ClaudeCode rewrites files in `~/.claude` and re-touches permissions** inside the devcontainer.
   The current rw bind mount to the host `~/.claude` directory makes this surface both fragile (perm
   churn under rootless podman userns mapping) and high-value as a token-theft target if anything
   inside the container is compromised.
2. **`compose.yaml` mixes the cross-environment contract with developer-machine concerns** — host
   UID/GID, host-side ports, and developer-only services live next to the
   postgres/valkey/kafka/observability topology that should be stable across environments.

The goal of this plan is to harden the developer environment without changing application behavior:

- Restore `compose.yaml` as a **cross-environment service contract**: who depends on whom,
  network/DNS, healthchecks, replica sizing.
- Move developer-host concerns into `.devcontainer/compose.override.yml`: host-port publishing, host
  UID/GID build args, the workspace bind mount, named volumes for caches, AI-CLI auth/cache
  strategy.
- Reduce ClaudeCode permission churn and credential exfiltration risk in line with AGENTS.md (no
  broad chown, no `permit!`-style shortcuts, no skipping verification).

Out of scope: Rails code, migrations, docs, ADR changes. Touch only `compose.yaml`,
`.devcontainer/compose.override.yml`, `.devcontainer/devcontainer.json`, `docker/core/`, and the
scripts under `.devcontainer/`.

## Current state (what is already correct)

- `compose.override.yml` already uses `userns_mode: keep-id` and clears the inherited `user:` so the
  image-baked USER wins — keep this pattern; the inline comments at `compose.yaml:23-26` and
  `compose.override.yml:6-11` already explain why.
- The `entrypoint.sh` already avoids `chown -R ${HOME}` — only normalizes the root-owned tmpfs
  targets `tmp/` and `log/` (`docker/core/entrypoint.sh:11-13`).
- `pgadmin` and `tinyrdm` are already gated behind the `tools` profile.
- `~/.ssh`, `~/.gitconfig`, `~/.config/git`, `~/.config/gh`, `~/.config/opencode` are mounted
  **read-only** already (`.devcontainer/devcontainer.json:104-114`).
- No docker/podman socket is mounted. No `privileged: true`. No broad `cap_add`. Those defaults
  stay.

## What stays in `compose.yaml` (shared contract)

Keep untouched:

- All service definitions for `primary`, `replica`, `valkey`, `kafka`, `loki`, `tempo`, `grafana`,
  `otel-collector`, `prometheus`, `pgadmin`, `tinyrdm`.
- Network topology (`backend`, `frontend`, `observability`, `outer`) and the long DNS alias list
  under `core.networks.frontend.aliases`.
- Healthchecks and `depends_on` graph.
- Replica/primary tmpfs sizing and `shm_size` — these are environment-portable knobs (already
  env-controlled via `POSTGRES_*_TMPFS_SIZE`).
- `:z` SELinux labels on bind-mounted config files (harmless on non-SELinux hosts; required on
  Fedora/RHEL).
- `env_file: docker/core/env` and the in-service `environment:` map for postgres credentials.

## What moves to `.devcontainer/compose.override.yml` (developer-host)

These are host-shaped, so they should not appear in the shared contract:

1. **Host UID/GID build args.** `args.DOCKER_UID`/`DOCKER_GID` in `compose.yaml:8-11` read from
   `${UID}`/`${GID}`. Move the `build.args` block under `core:` to the override; leave only
   `build.context` + `build.dockerfile` in the base.
2. **Host port publishings.** `core:3001:3000`, `kafka:9092`, `pgadmin:5050`,
   `tempo:3200/4317/4318/9411`. Define them under the override; keep `EXPOSE` / container-side ports
   unchanged in the base.
3. **Workspace bind mount.** Move
   `volumes: - type: bind, source: ".", target: /home/global/workspace` from base to override and
   add `:Z` (SELinux) only on the override line — the base file should not assume a checked-out repo
   on disk.
4. **`cloudflare-tunnel` service.** Move the full definition behind a `tunnel` profile in the
   override. It needs `${CLOUDFLARED_TOKEN}` from the developer shell; production / CI never reaches
   this path today anyway.
5. **`extra_hosts: host.docker.internal:host-gateway`.** Keep this in the override — it is
   meaningful only on developer workstations.

## Permission and cache layout (Podman-rootless friendly)

Add the following **named volumes** to the override so ClaudeCode and the dev tooling stop fighting
the bind-mounted workspace:

| Path inside container                  | Volume                 | Reason                                                                           |
| -------------------------------------- | ---------------------- | -------------------------------------------------------------------------------- |
| `/home/global/.cache`                  | `umaxica-home-cache`   | pnpm, corepack, Vite+, Ruby YJIT scratch                                         |
| `/home/global/.local/share`            | `umaxica-home-share`   | pnpm store, devcontainer feature payloads                                        |
| `/home/global/workspace/node_modules`  | `umaxica-node-modules` | keep off the bind mount → host stays clean, no perm war                          |
| `/home/global/workspace/vendor/bundle` | `umaxica-bundle`       | same reasoning; also lets the bundle path stay readable to the in-container user |

Why this fixes ClaudeCode perm churn: with `userns_mode: keep-id`, host UID maps to the in-container
UID, but writes to bind-mounted host paths still pass through the SELinux label / xattr layer and
(on some kernels) trigger inode rewrites. Putting high-write caches on named volumes routes those
writes through the podman storage driver instead of the host filesystem.

Keep all four named volumes **non-permanent in name** — `umaxica-*` is fine — so
`podman volume rm umaxica-node-modules umaxica-bundle` cleanly recovers from a corrupted cache
without touching `home-cache`/`home-share` (where AI-CLI auth material would otherwise live).

## AI-CLI mount strategy (reduce blast radius)

Today both `~/.claude` and `~/.codex` are full rw bind mounts. Tighten as follows in
`.devcontainer/devcontainer.json` mounts:

- Keep `~/.claude.json` as rw bind (this is the auth file; ClaudeCode rewrites it).
- Replace the `~/.claude` rw bind mount with **a named volume** for cache state and a narrow rw bind
  mount **only** for the credential subset that actually needs to round-trip to the host (e.g.
  `.credentials.json`). Everything else (project history, transcript cache, prompt cache) lives in
  the container-only volume — if the container is compromised the attacker reaches container-local
  state, not the host `~/.claude` directory.
- Same shape for `~/.codex`: keep auth file rw, move cache state to a named volume.
- Leave `~/.config/git`, `~/.gitconfig`, `~/.ssh`, `~/.config/opencode`, `~/.config/gh` read-only
  (current state).

If switching `~/.claude` shape is too invasive in one step, an acceptable first slice is: leave the
bind mount but add a `mode=0700` named volume for `/home/global/.cache/claude` and point
`CLAUDE_CACHE_DIR` (or the XDG equivalent) at it. That moves the heavy-write directory off the bind
mount and removes the visible perm-churn symptom even if the credential layout is unchanged.

## Workspace write-guards (supply-chain defense)

The biggest "outside-the-container" blast surface is the repo bind mount. Add readonly guards in
`devcontainer.json` `mounts` for paths a compromised in-container process should never edit:

- `.github/workflows/`
- `bin/`
- `Gemfile`, `Gemfile.lock`
- `package.json`, `pnpm-lock.yaml`
- `.devcontainer/`

These overlay the workspace bind mount; the rest of the tree stays writable so normal development is
not blocked. Pattern is the existing `readonly` mount style in `devcontainer.json:104-113`.

Do **not** add a workspace-wide readonly. Editing source is the point of the devcontainer.

## Files to change

- `compose.yaml` — strip developer-host fields listed above; keep service contract.
- `.devcontainer/compose.override.yml` — add `build.args`, host port maps, workspace bind mount with
  `:Z`, new named volumes, `cloudflare-tunnel` behind `tunnel` profile. Declare the new volumes at
  file bottom.
- `.devcontainer/devcontainer.json` — narrow `~/.claude` and `~/.codex` mounts; add workspace
  write-guards for `.github/workflows/`, `bin/`, `Gemfile{,lock}`, `package.json`, `pnpm-lock.yaml`,
  `.devcontainer/`.
- `docker/core/entrypoint.sh` — no change expected; the current narrow chown of `tmp/` and `log/` is
  already the right shape.
- `.devcontainer/setup-claude.sh` — minor: stop printing the absolute credential path in success
  messages (leaks layout in shared screen recordings).

Existing utilities to reuse (do not reinvent):

- `userns_mode: keep-id` + `user: !reset null` pattern already at
  `.devcontainer/compose.override.yml:5-11`.
- `profiles: [tools]` gating pattern already at `.devcontainer/compose.override.yml:45-50`.
- `tmpfs: !reset null` pattern already at `.devcontainer/compose.override.yml:17`.

## What to leave on the host after migration

Once `node_modules` and `vendor/bundle` are on named volumes, the host-side copies on the developer
workstation can be removed:

```
rm -rf node_modules vendor/bundle .bundle
```

Keep on the host: `Gemfile`, `Gemfile.lock`, `package.json`, `pnpm-lock.yaml`, `.ruby-version`,
`.node-version`, `.tool-versions`. The contract is "lockfiles in git, materialized dependencies in
container volumes."

Do not delete `tmp/` blindly — only `tmp/cache`, `tmp/pids`, `tmp/sockets` are safe to wipe. Active
Rails state may live under `tmp/storage` depending on the workflow.

## Verification

After applying the change:

1. **Clean rebuild from a cold state:**
   ```
   podman compose -f compose.yaml -f .devcontainer/compose.override.yml down -v
   podman volume rm umaxica-node-modules umaxica-bundle umaxica-home-cache umaxica-home-share || true
   podman compose -f compose.yaml -f .devcontainer/compose.override.yml build --no-cache core
   podman compose -f compose.yaml -f .devcontainer/compose.override.yml up -d
   ```
2. **Ownership check from inside `core`:**
   ```
   stat -c '%u:%g %n' /home/global /home/global/workspace /home/global/.cache /usr/local/bundle
   ```
   Every path should report the in-container `global` user, never `root` or a subuid number.
3. **ClaudeCode round-trip:** open the devcontainer in VS Code, run `claude` once to trigger a
   config write, then exit and re-enter. Confirm `~/.claude.json` on the host is still readable by
   the host user and has no `subuid` ownership.
4. **Workspace guards:** from inside the container, `touch .github/workflows/x` should fail with
   EROFS. `touch app/models/x.rb` should succeed.
5. **Tests still pass:**
   ```
   bin/rails test
   ```
   Then a targeted parallel run to confirm the tmpfs-on-postgres sizing still holds with the
   override applied:
   ```
   bin/rails test:db
   bin/rails test test/models/
   ```
6. **VS Code rebuild:** `Dev Containers: Rebuild Container` — must succeed without any postCreate
   `chown` step appearing in logs.

## Rollout sequencing

Do this in three commits so each step is independently revertable:

1. **Pure move.** Relocate host-port maps, `build.args` UID/GID, and the workspace bind mount from
   base to override. Behavior should be byte-identical.
2. **Named volumes for caches.** Add `node_modules`, `bundle`, `home-cache`, `home-share`. Wipe
   host-side `node_modules`/`vendor/bundle` after verification.
3. **AI-CLI tightening + workspace write-guards.** Narrow `~/.claude` and `~/.codex` mounts; add
   readonly overlays on `.github/workflows/`, `bin/`, lockfiles, `.devcontainer/`.

Each step ends with the verification block above; do not advance until the previous step is green.
