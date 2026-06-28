# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
ENV["SIGN_SERVICE_URL"] ||= "sign.app.localhost"
ENV["SIGN_STAFF_URL"] ||= "sign.org.localhost"
ENV["SIGN_CORPORATE_URL"] ||= "sign.com.localhost"
ENV["AUTH_SERVICE_URL"] ||= "auth.app.localhost"
ENV["AUTH_STAFF_URL"] ||= "auth.org.localhost"
ENV["AUTH_CORPORATE_URL"] ||= "auth.com.localhost"
ENV["BASE_SERVICE_URL"] ||= "base.app.localhost"
ENV["BASE_STAFF_URL"] ||= "base.org.localhost"
ENV["BASE_CORPORATE_URL"] ||= "base.com.localhost"

# Enable YJIT before Rails boots.
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
      ENV.fetch("PARALLEL_WORKERS") do
        1
      end
    parallel_workers = parallel_workers.to_i if parallel_workers.is_a?(String)

    fixtures :all
    parallelize(workers: parallel_workers)
  end
end
