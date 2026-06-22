# frozen_string_literal: true

# Keep pnpm's writable state inside the repository so Vite can boot in this
# container without touching the read-only home directory.
pnpm_data_home = File.expand_path("../tmp/pnpm-data", __dir__)
pnpm_state_home = File.expand_path("../tmp/pnpm-state", __dir__)

ViteRuby.env["XDG_DATA_HOME"] = pnpm_data_home
ViteRuby.env["XDG_STATE_HOME"] = pnpm_state_home
