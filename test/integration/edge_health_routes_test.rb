# typed: false
# frozen_string_literal: true

require "test_helper"

class EdgeHealthRoutesTest < ActionDispatch::IntegrationTest
  test "legacy edge health routes are not routed" do
    [
      ENV.fetch("PRIVATE_ACME_CORPORATE_URL", "www.com.localhost"),
      ENV.fetch("PRIVATE_ACME_SERVICE_URL", "www.app.localhost"),
      ENV.fetch("PRIVATE_ACME_STAFF_URL", "www.org.localhost"),
      ENV.fetch("PUBLIC_CORE_CORPORATE_URL", ENV.fetch("PUBLIC_CORE_CORPORATE_URL", "core.com.localhost")),
      ENV.fetch("PUBLIC_CORE_SERVICE_URL", ENV.fetch("PUBLIC_CORE_SERVICE_URL", "core.app.localhost")),
      ENV.fetch("PUBLIC_CORE_STAFF_URL", ENV.fetch("PUBLIC_CORE_STAFF_URL", "core.org.localhost")),
      ENV.fetch("PRIVATE_AUTH_CORPORATE_URL", "sign.com.localhost"),
      ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost"),
      ENV.fetch("PRIVATE_AUTH_STAFF_URL", "sign.org.localhost"),
    ].each do |host|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{host}/edge/v0/health", method: :get)
      end
    end
  end

  test "legacy sign web health routes are not routed" do
    [
      ENV.fetch("PRIVATE_AUTH_CORPORATE_URL", "sign.com.localhost"),
      ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost"),
      ENV.fetch("PRIVATE_AUTH_STAFF_URL", "sign.org.localhost"),
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
      ENV.fetch("PRIVATE_ACME_CORPORATE_URL", "www.com.localhost"),
      ENV.fetch("PRIVATE_ACME_SERVICE_URL", "www.app.localhost"),
      ENV.fetch("PRIVATE_ACME_STAFF_URL", "www.org.localhost"),
      ENV.fetch("PUBLIC_CORE_CORPORATE_URL", ENV.fetch("PUBLIC_CORE_CORPORATE_URL", "core.com.localhost")),
      ENV.fetch("PUBLIC_CORE_SERVICE_URL", ENV.fetch("PUBLIC_CORE_SERVICE_URL", "core.app.localhost")),
      ENV.fetch("PUBLIC_CORE_STAFF_URL", ENV.fetch("PUBLIC_CORE_STAFF_URL", "core.org.localhost")),
      ENV.fetch("PRIVATE_AUTH_CORPORATE_URL", "sign.com.localhost"),
      ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost"),
      ENV.fetch("PRIVATE_AUTH_STAFF_URL", "sign.org.localhost"),
    ].each do |host|
      %w(/health/live /health/ready).each do |path|
        assert_raises(ActionController::RoutingError, "#{host}#{path} should not be routed") do
          Rails.application.routes.recognize_path("http://#{host}#{path}", method: :get)
        end
      end
    end
  end
end
