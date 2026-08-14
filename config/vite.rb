# frozen_string_literal: true

# pnpm writes state (update-check metadata) next to its data root. Keep that inside
# the repository so vite-ruby's pnpm calls do not depend on a home directory that is
# not guaranteed writable outside the dev container. The store location itself is
# pinned by `npm_config_store_dir` in compose.yaml, not by XDG resolution.
pnpm_state_home = File.expand_path("../tmp/pnpm-state", __dir__)

ViteRuby.env["XDG_STATE_HOME"] = pnpm_state_home
