# typed: false
# frozen_string_literal: true

require "test_helper"

class EdgeHealthRoutesTest < ActionDispatch::IntegrationTest
  test "legacy edge health routes are not routed" do
    [
      ENV.fetch("ACME_CORPORATE_URL"),
      ENV.fetch("ACME_SERVICE_URL"),
      ENV.fetch("ACME_STAFF_URL"),
      ENV.fetch("CORE_CORPORATE_URL"),
      ENV.fetch("CORE_SERVICE_URL"),
      ENV.fetch("CORE_STAFF_URL"),
      ENV.fetch("SIGN_CORPORATE_URL"),
      ENV.fetch("PRIVATE_SIGN_SERVICE_URL"),
      ENV.fetch("SIGN_STAFF_URL"),
    ].each do |host|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{host}/edge/v0/health", method: :get)
      end
    end
  end

  test "legacy sign web health routes are not routed" do
    [
      ENV.fetch("SIGN_CORPORATE_URL"),
      ENV.fetch("PRIVATE_SIGN_SERVICE_URL"),
      ENV.fetch("SIGN_STAFF_URL"),
    ].each do |host|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{host}/web/v0/health", method: :get)
      end
    end
  end

  # The probe contract was unified on /health/liveness and /health/readiness.
  # The former /health/live and /health/ready paths were removed outright (no
  # compatibility shim); guard against their reintroduction on any surface.
  test "removed legacy probe paths are not routed" do
    [
      ENV.fetch("ACME_CORPORATE_URL"),
      ENV.fetch("ACME_SERVICE_URL"),
      ENV.fetch("ACME_STAFF_URL"),
      ENV.fetch("CORE_CORPORATE_URL"),
      ENV.fetch("CORE_SERVICE_URL"),
      ENV.fetch("CORE_STAFF_URL"),
      ENV.fetch("SIGN_CORPORATE_URL"),
      ENV.fetch("PRIVATE_SIGN_SERVICE_URL"),
      ENV.fetch("SIGN_STAFF_URL"),
    ].each do |host|
      %w(/health/live /health/ready).each do |path|
        assert_raises(ActionController::RoutingError, "#{host}#{path} should not be routed") do
          Rails.application.routes.recognize_path("http://#{host}#{path}", method: :get)
        end
      end
    end
  end
end
