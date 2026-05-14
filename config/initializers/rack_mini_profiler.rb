# typed: false
# frozen_string_literal: true

if defined?(Rack::MiniProfiler)
  Rack::MiniProfiler.config.enabled = ENV["RACK_MINI_PROFILER_ENABLED"] == "true"
  Rack::MiniProfiler.config.auto_inject = Rack::MiniProfiler.config.enabled
end
