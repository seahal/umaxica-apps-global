# typed: false
# frozen_string_literal: true

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.

# In the devcontainer the workspace (including tmp/cache) is a ZFS bind mount;
# test boots (16 parallel workers) hammer the bootsnap cache, so keep it on
# tmpfs-backed /tmp for tests. Dev keeps the default tmp/cache so the cache
# survives container restarts.
# RAILS_ENV is not yet set when `bin/rails test` boots, so also detect the
# test command from ARGV.
if ENV["RAILS_ENV"] == "test" || (defined?(ARGV) && ARGV.first == "test")
  ENV["BOOTSNAP_CACHE_DIR"] ||= "/tmp/bootsnap"
end

require "bootsnap/setup" # Speed up boot time by caching expensive operations.
