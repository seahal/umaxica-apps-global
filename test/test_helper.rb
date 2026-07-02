# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
ENV["AUTH_SERVICE_URL"] = "auth.app.localhost"
ENV["AUTH_CORPORATE_URL"] = "auth.com.localhost"
ENV["AUTH_STAFF_URL"] = "auth.org.localhost"
ENV["PUBLIC_AUTH_SERVICE_URL"] = "auth.app.localhost"
ENV["PUBLIC_AUTH_CORPORATE_URL"] = "auth.com.localhost"
ENV["PUBLIC_AUTH_STAFF_URL"] = "auth.org.localhost"
ENV["PRIVATE_AUTH_SERVICE_URL"] = "auth.app.localhost"
ENV["PRIVATE_AUTH_CORPORATE_URL"] = "auth.com.localhost"
ENV["PRIVATE_AUTH_STAFF_URL"] = "auth.org.localhost"
ENV["SMTP_FROM_ADDRESS_APP"] = "from@umaxica.app"
RubyVM::YJIT.enable if defined?(RubyVM::YJIT)

if ENV["COVERAGE"] == "true"
  require "simplecov"

  SimpleCov.start("rails") do
    enable_coverage :branch

    # Ensure all Ruby files under app/ are included,
    # even if they are not loaded during the test run.
    track_files "app/**/*.rb"

    add_filter "/test/"
    add_filter "/config/"
    add_filter "/vendor/"

    add_group "Controllers", "app/controllers"
    add_group "Models", "app/models"
    add_group "Helpers", "app/helpers"
    add_group "Jobs", "app/jobs"
    add_group "Mailers", "app/mailers"
    add_group "Services", "app/services"
    add_group "Values", "app/values"
    add_group "Forms", "app/forms"
    add_group "Policies", "app/policies"
    add_group "Subscribers", "app/subscribers"
    add_group "Validators", "app/validators"
    add_group "Errors", "app/errors"

    minimum_coverage line: 98
  end
end

require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    parallel_workers =
      if ENV["COVERAGE"] == "true"
        1
      else
        Integer(ENV.fetch("PARALLEL_WORKERS", "16"), 10)
      end
    raise "PARALLEL_WORKERS must be positive" unless parallel_workers.positive?

    fixtures :all
    parallelize(workers: parallel_workers)

    # The rate_limit backing store (config.x.rate_limit.store) is a single
    # MemoryStore instance created once at boot and shared by every test in the
    # process. Its counters are keyed by request IP (127.0.0.1 for all tests),
    # so without a reset a rate_limit test's counter leaks into later, unrelated
    # tests and spuriously 429s them. Clear it before each test for a clean slate
    # (mutate the same instance with #clear — replacing it would not reach
    # controllers that captured the original store at class-load time).
    setup { Rails.configuration.x.rate_limit.fetch(:store).clear }
  end
end
