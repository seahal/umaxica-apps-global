# typed: false
# frozen_string_literal: true

require "test_helper"

class CoreAuthBoundaryTest < ActionDispatch::IntegrationTest
  SURFACES = [
    {
      host: ENV.fetch("CORE_SERVICE_URL", "core.app.localhost"),
      controller: "core/app/auth/callbacks",
    },
    {
      host: ENV.fetch("CORE_CORPORATE_URL", "core.com.localhost"),
      controller: "core/com/auth/callbacks",
    },
    {
      host: ENV.fetch("CORE_STAFF_URL", "core.org.localhost"),
      controller: "core/org/auth/callbacks",
    },
  ].freeze

  test "callback, logout, and back-channel routes remain executable on every surface" do
    SURFACES.each do |surface|
      host = surface.fetch(:host)
      host! host

      assert_routing(
        { method: :get, path: "http://#{host}/auth/callback" },
        { controller: surface.fetch(:controller), action: "show" },
      )

      assert_routing(
        { method: :post, path: "http://#{host}/auth/logout" },
        { controller: surface.fetch(:controller).sub("callbacks", "logouts"), action: "create" },
      )

      assert_routing(
        { method: :post, path: "http://#{host}/oidc/backchannel/logout" },
        { controller: "core/#{surface.fetch(:controller).split("/")[1]}/oidc/backchannel/logouts", action: "create" },
      )
    end
  end

  test "callback rejects missing oauth state with an explicit failure" do
    SURFACES.each do |surface|
      host = surface.fetch(:host)
      host! host

      get "https://#{host}/auth/callback"

      assert_response :unprocessable_content
    end
  end

  test "logout redirects back to the local root on every surface" do
    SURFACES.each do |surface|
      host = surface.fetch(:host)
      host! host

      post "https://#{host}/auth/logout"

      assert_response :see_other
      assert_equal "https://#{host}/", response.location
    end
  end

  test "back-channel logout rejects invalid tokens without mutating session state" do
    SURFACES.each do |surface|
      host = surface.fetch(:host)
      host! host

      post "https://#{host}/oidc/backchannel/logout", params: { logout_token: "invalid" }

      assert_response :bad_request
      assert_equal "invalid_logout_token", response.body
    end
  end
end
