# frozen_string_literal: true

coverage_enabled = %w(1 true).include?(ENV.fetch("COVERAGE", "").downcase)

if coverage_enabled && ENV["SIMPLECOV_STARTED"] != "true"
  require "simplecov"

  SimpleCov.command_name(ENV.fetch("SIMPLECOV_COMMAND_NAME", "Minitest"))
  SimpleCov.start("rails")

  ENV["SIMPLECOV_STARTED"] = "true"
end
