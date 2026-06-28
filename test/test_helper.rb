# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
ENV["PRIVATE_SIGN_SERVICE_URL"] = ENV["PRIVATE_SIGN_SERVICE_URL"].to_s.empty? ? "sign.app.localhost" : ENV["PRIVATE_SIGN_SERVICE_URL"]
ENV["PRIVATE_SIGN_STAFF_URL"] = ENV["PRIVATE_SIGN_STAFF_URL"].to_s.empty? ? (ENV["SIGN_STAFF_URL"].to_s.empty? ? "sign.org.localhost" : ENV["SIGN_STAFF_URL"]) : ENV["PRIVATE_SIGN_STAFF_URL"]
ENV["PRIVATE_SIGN_CORPORATE_URL"] = ENV["PRIVATE_SIGN_CORPORATE_URL"].to_s.empty? ? (ENV["SIGN_CORPORATE_URL"].to_s.empty? ? "sign.com.localhost" : ENV["SIGN_CORPORATE_URL"]) : ENV["PRIVATE_SIGN_CORPORATE_URL"]
ENV["ID_SERVICE_URL"] = ENV["ID_SERVICE_URL"].to_s.empty? ? ENV["PRIVATE_SIGN_SERVICE_URL"] : ENV["ID_SERVICE_URL"]
ENV["ID_STAFF_URL"] = ENV["ID_STAFF_URL"].to_s.empty? ? ENV["PRIVATE_SIGN_STAFF_URL"] : ENV["ID_STAFF_URL"]
ENV["ID_CORPORATE_URL"] = ENV["ID_CORPORATE_URL"].to_s.empty? ? ENV["PRIVATE_SIGN_CORPORATE_URL"] : ENV["ID_CORPORATE_URL"]
ENV["PRIVATE_ACME_SERVICE_URL"] = ENV["PRIVATE_ACME_SERVICE_URL"].to_s.empty? ? (ENV["ACME_SERVICE_URL"].to_s.empty? ? "www.app.localhost" : ENV["ACME_SERVICE_URL"]) : ENV["PRIVATE_ACME_SERVICE_URL"]
ENV["PRIVATE_ACME_STAFF_URL"] = ENV["PRIVATE_ACME_STAFF_URL"].to_s.empty? ? (ENV["ACME_STAFF_URL"].to_s.empty? ? "www.org.localhost" : ENV["ACME_STAFF_URL"]) : ENV["PRIVATE_ACME_STAFF_URL"]
ENV["PRIVATE_ACME_CORPORATE_URL"] = ENV["PRIVATE_ACME_CORPORATE_URL"].to_s.empty? ? (ENV["ACME_CORPORATE_URL"].to_s.empty? ? "www.com.localhost" : ENV["ACME_CORPORATE_URL"]) : ENV["PRIVATE_ACME_CORPORATE_URL"]
ENV["PRIVATE_ACME_NETWORK_URL"] = ENV["PRIVATE_ACME_NETWORK_URL"].to_s.empty? ? (ENV["ACME_NETWORK_URL"].to_s.empty? ? "www.umaxica.net" : ENV["ACME_NETWORK_URL"]) : ENV["PRIVATE_ACME_NETWORK_URL"]
ENV["PRIVATE_ACME_DEVELOPER_URL"] = ENV["PRIVATE_ACME_DEVELOPER_URL"].to_s.empty? ? (ENV["ACME_DEVELOPER_URL"].to_s.empty? ? "developer.umaxica.net" : ENV["ACME_DEVELOPER_URL"]) : ENV["PRIVATE_ACME_DEVELOPER_URL"]
ENV["PUBLIC_AUTH_SERVICE_URL"] = ENV["PUBLIC_AUTH_SERVICE_URL"].to_s.empty? ? (ENV["AUTH_SERVICE_URL"].to_s.empty? ? "auth.app.localhost" : ENV["AUTH_SERVICE_URL"]) : ENV["PUBLIC_AUTH_SERVICE_URL"]
ENV["PUBLIC_AUTH_STAFF_URL"] = ENV["PUBLIC_AUTH_STAFF_URL"].to_s.empty? ? (ENV["AUTH_STAFF_URL"].to_s.empty? ? "auth.org.localhost" : ENV["AUTH_STAFF_URL"]) : ENV["PUBLIC_AUTH_STAFF_URL"]
ENV["PUBLIC_AUTH_CORPORATE_URL"] = ENV["PUBLIC_AUTH_CORPORATE_URL"].to_s.empty? ? (ENV["AUTH_CORPORATE_URL"].to_s.empty? ? "auth.com.localhost" : ENV["AUTH_CORPORATE_URL"]) : ENV["PUBLIC_AUTH_CORPORATE_URL"]
ENV["PUBLIC_CORE_SERVICE_URL"] = ENV["PUBLIC_CORE_SERVICE_URL"].to_s.empty? ? (ENV["CORE_SERVICE_URL"].to_s.empty? ? "core.app.localhost" : ENV["CORE_SERVICE_URL"]) : ENV["PUBLIC_CORE_SERVICE_URL"]
ENV["PUBLIC_CORE_STAFF_URL"] = ENV["PUBLIC_CORE_STAFF_URL"].to_s.empty? ? (ENV["CORE_STAFF_URL"].to_s.empty? ? "core.org.localhost" : ENV["CORE_STAFF_URL"]) : ENV["PUBLIC_CORE_STAFF_URL"]
ENV["PUBLIC_CORE_CORPORATE_URL"] = ENV["PUBLIC_CORE_CORPORATE_URL"].to_s.empty? ? (ENV["CORE_CORPORATE_URL"].to_s.empty? ? "core.com.localhost" : ENV["CORE_CORPORATE_URL"]) : ENV["PUBLIC_CORE_CORPORATE_URL"]
ENV["PRIVATE_CORE_NETWORK_URL"] = ENV["PRIVATE_CORE_NETWORK_URL"].to_s.empty? ? (ENV["CORE_NETWORK_URL"].to_s.empty? ? "core.net.localhost" : ENV["CORE_NETWORK_URL"]) : ENV["PRIVATE_CORE_NETWORK_URL"]
ENV["PRIVATE_CORE_DEVELOPER_URL"] = ENV["PRIVATE_CORE_DEVELOPER_URL"].to_s.empty? ? (ENV["CORE_DEVELOPER_URL"].to_s.empty? ? "core.dev.localhost" : ENV["CORE_DEVELOPER_URL"]) : ENV["PRIVATE_CORE_DEVELOPER_URL"]
ENV["PUBLIC_BASE_SERVICE_URL"] = ENV["PUBLIC_BASE_SERVICE_URL"].to_s.empty? ? (ENV["BASE_SERVICE_URL"].to_s.empty? ? "base.app.localhost" : ENV["BASE_SERVICE_URL"]) : ENV["PUBLIC_BASE_SERVICE_URL"]
ENV["PUBLIC_BASE_STAFF_URL"] = ENV["PUBLIC_BASE_STAFF_URL"].to_s.empty? ? (ENV["BASE_STAFF_URL"].to_s.empty? ? "base.org.localhost" : ENV["BASE_STAFF_URL"]) : ENV["PUBLIC_BASE_STAFF_URL"]
ENV["PUBLIC_BASE_CORPORATE_URL"] = ENV["PUBLIC_BASE_CORPORATE_URL"].to_s.empty? ? (ENV["BASE_CORPORATE_URL"].to_s.empty? ? "base.com.localhost" : ENV["BASE_CORPORATE_URL"]) : ENV["PUBLIC_BASE_CORPORATE_URL"]
ENV["PRIVATE_BASE_SERVICE_URL"] = ENV["PRIVATE_BASE_SERVICE_URL"].to_s.empty? ? (ENV["BASE_SERVICE_URL"].to_s.empty? ? "base.app.localhost" : ENV["BASE_SERVICE_URL"]) : ENV["PRIVATE_BASE_SERVICE_URL"]
ENV["PRIVATE_BASE_STAFF_URL"] = ENV["PRIVATE_BASE_STAFF_URL"].to_s.empty? ? (ENV["BASE_STAFF_URL"].to_s.empty? ? "base.org.localhost" : ENV["BASE_STAFF_URL"]) : ENV["PRIVATE_BASE_STAFF_URL"]
ENV["PRIVATE_BASE_CORPORATE_URL"] = ENV["PRIVATE_BASE_CORPORATE_URL"].to_s.empty? ? (ENV["BASE_CORPORATE_URL"].to_s.empty? ? "base.com.localhost" : ENV["BASE_CORPORATE_URL"]) : ENV["PRIVATE_BASE_CORPORATE_URL"]
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
