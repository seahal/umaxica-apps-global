# typed: false
# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
COVERAGE_ENABLED = ENV["COVERAGE"] == "true"

ENV["ID_SERVICE_URL"] = "id.app.localhost"
ENV["ID_CORPORATE_URL"] = "id.com.localhost"
ENV["ID_STAFF_URL"] = "id.org.localhost"
ENV["SIGN_SERVICE_URL"] = ENV["ID_SERVICE_URL"]
ENV["SIGN_CORPORATE_URL"] = ENV["ID_CORPORATE_URL"]
ENV["SIGN_STAFF_URL"] = ENV["ID_STAFF_URL"]
ENV["SIGN_NETWORK_URL"] = "id.net.localhost"
ENV["SIGN_DEVELOPER_URL"] = "id.dev.localhost"
ENV["APEX_SERVICE_URL"] = "app.localhost"
ENV["APEX_CORPORATE_URL"] = "com.localhost"
ENV["APEX_STAFF_URL"] = "org.localhost"
ENV["JUMP_APP_URL"] = "jump.app.localhost"
ENV["JUMP_COM_URL"] = "jump.com.localhost"
ENV["JUMP_ORG_URL"] = "jump.org.localhost"
ENV["JUMP_SERVICE_URL"] = ENV["JUMP_APP_URL"]
ENV["JUMP_CORPORATE_URL"] = ENV["JUMP_COM_URL"]
ENV["JUMP_STAFF_URL"] = ENV["JUMP_ORG_URL"]

require_relative "support/simplecov_setup" if COVERAGE_ENABLED
require_relative "../config/environment"
require "rails/test_help"
require "ostruct"

# Load support files
Rails.root.glob("test/support/**/*.rb").each do |file|
  require file
end

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: COVERAGE_ENABLED ? 1 : TestSupport::CpuWorkers.detect, work_stealing: true)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    setup do
      RateLimit.store.clear if defined?(RateLimit)
      if defined?(CloudflareTurnstile)
        CloudflareTurnstile.test_mode = true
        CloudflareTurnstile.test_validation_response = { "success" => true }
      end
    end

    # Add more helper methods to be used by all tests here...
  end
end
