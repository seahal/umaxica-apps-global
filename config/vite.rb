# frozen_string_literal: true

# Keep package-runner state inside the checkout for reproducible host and container builds.
bun_state_home = File.expand_path("../tmp/bun-state", __dir__)
ViteRuby.env["XDG_STATE_HOME"] = bun_state_home
ViteRuby.env["VITE_RUBY_PACKAGE_MANAGER"] = "bun"
