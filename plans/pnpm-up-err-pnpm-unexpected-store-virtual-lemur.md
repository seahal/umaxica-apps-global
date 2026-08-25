# Fix recurring ERR_PNPM_UNEXPECTED_STORE in the dev container

## Context

Every dev container start, the first `pnpm up` / `pnpm install` fails with
`ERR_PNPM_UNEXPECTED_STORE`: `node_modules` is linked from
`/home/global/workspace/tmp/pnpm-data/pnpm/store/v11`, while the shell's pnpm wants
`/home/global/workspace/.pnpm-store/v11`.

Two different store locations are in play:

1. `config/vite.rb:8` sets `ViteRuby.env["XDG_DATA_HOME"] = <repo>/tmp/pnpm-data`, so every pnpm
   invocation vite-ruby makes (including its automatic dependency install on boot) resolves the
   store to `tmp/pnpm-data/pnpm/store/v11`.
2. A plain shell `pnpm` has no such override. Because `node_modules` is a separate named volume
   (`umaxica-node-modules`, `compose.yaml:205-207`) from `/home/global/.local/share`
   (`umaxica-home-share`), pnpm's default store resolution falls back to the workspace-local
   `.pnpm-store/v11`.

Whichever ran last wins, so the two keep invalidating each other — hence "まいにちこれ". The comment
in `config/vite.rb` ("read-only home directory") is stale: `/home/global/.cache` and
`/home/global/.local/share` are writable named volumes today.

Goal: one deterministic store path shared by vite-ruby and the shell, surviving container restarts,
off the bind-mounted repo tree.

## Change

Target store: `/home/global/.local/share/pnpm/store` (the `umaxica-home-share` volume — the location
`compose.yaml:193` already documents as "pnpm store").

1. `compose.yaml` — in the core service `environment:` block next to the existing Vite vars
   (`compose.yaml:180-184`), pin the store for every pnpm process in the container:

   ```yaml
   # pnpm's store must not depend on XDG resolution: node_modules lives on its own
   # volume, so pnpm otherwise falls back to a workspace-local .pnpm-store and
   # invalidates the store vite-ruby used. See plans/pnpm-up-err-pnpm-unexpected-store.
   npm_config_store_dir: /home/global/.local/share/pnpm/store
   ```

   Use `npm_config_store_dir` (pnpm's env form of the `store-dir` setting) rather than a committed
   `.npmrc` entry, so an absolute container path never leaks to host-side pnpm runs.

2. `config/vite.rb` — drop the `XDG_DATA_HOME` override and its stale rationale; keep
   `XDG_STATE_HOME`. With the store pinned explicitly, the override only reintroduces a second data
   root. Update the remaining comment to state why state, not data, is redirected.

3. `.gitignore:120` / `.aiignore:17` — leave `.pnpm-store/` ignored; harmless and still correct for
   host-side runs.

Do **not** move the store onto the `umaxica-node-modules` volume; nothing else lives there, so there
is no hardlink benefit, and discarding that volume would then also nuke the store.

## Cleanup on first apply (one time, requires user confirmation before deleting)

After the config change, the existing `node_modules` still points at the old store, so the first run
still errors. Recovery inside the container:

```bash
rm -rf /home/global/workspace/node_modules/.pnpm /home/global/workspace/node_modules/.modules.yaml
pnpm install --frozen-lockfile
```

Optional stale-state removal once the above succeeds: `rm -rf tmp/pnpm-data .pnpm-store`. These are
deletions of dev-container caches — confirm with the user before running.

## Verification

Inside the dev container, after `podman compose up` (no rebuild of volumes needed):

1. `pnpm config get store-dir` → `/home/global/.local/share/pnpm/store`
2. `pnpm install --frozen-lockfile` → succeeds, no `ERR_PNPM_UNEXPECTED_STORE`
3. `grep storeDir node_modules/.modules.yaml` → the same path
4. Boot Vite through Rails (`bin/dev` or `bin/rails s`) so vite-ruby runs pnpm itself, then re-run
   step 3 — the path must be unchanged, which is the actual regression this fixes.
5. `pnpm test` and `pnpm -s check` to confirm the reinstalled tree is intact.
6. Restart the container once and re-run `pnpm install` to confirm the error does not return.
