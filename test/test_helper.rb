# typed: false
# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

trusted_origins = ENV["TRUSTED_ORIGINS"].to_s.split(",").map(&:strip).reject(&:empty?)
trusted_origins |= [
  "http://id.app.localhost",
  "http://id.com.localhost",
  "http://id.org.localhost",
]
ENV["TRUSTED_ORIGINS"] = trusted_origins.join(",")
COVERAGE_ENABLED = ENV["COVERAGE"] == "true"
require_relative "support/simplecov_setup" if COVERAGE_ENABLED

require "active_model"
require_relative "../config/environment"
require "rails/test_help"

Rails.root.glob("test/support/**/*.rb").each do |file|
  require file
end

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: COVERAGE_ENABLED ? 1 : :number_of_processors, work_stealing: true)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
