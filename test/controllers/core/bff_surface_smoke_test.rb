# typed: false
# frozen_string_literal: true

require "test_helper"

class CoreBffSurfaceSmokeTest < ActionDispatch::IntegrationTest
  SURFACES = [
    {
      host: ENV.fetch("CORE_SERVICE_URL", "core.app.localhost"),
      auth_callback_path: "/auth/callback",
      auth_logout_path: "/auth/logout",
      backchannel_logout_path: "/oidc/backchannel/logout",
      token_refresh_path: "/api/v0/token/refresh",
    },
    {
      host: ENV.fetch("CORE_CORPORATE_URL", "core.com.localhost"),
      auth_callback_path: "/auth/callback",
      auth_logout_path: "/auth/logout",
      backchannel_logout_path: "/oidc/backchannel/logout",
      token_refresh_path: "/api/v0/token/refresh",
    },
    {
      host: ENV.fetch("CORE_STAFF_URL", "core.org.localhost"),
      auth_callback_path: "/auth/callback",
      auth_logout_path: "/auth/logout",
      backchannel_logout_path: "/oidc/backchannel/logout",
      token_refresh_path: "/api/v0/token/refresh",
    },
  ].freeze

  test "core BFF and logout routes are executable on every surface" do
    SURFACES.each do |surface|
      host = surface.fetch(:host)
      host! host

      get "https://#{host}#{surface.fetch(:auth_callback_path)}"

      assert_response :unprocessable_content

      post "https://#{host}#{surface.fetch(:auth_logout_path)}"

      assert_response :see_other
      assert_match(%r{\Ahttps?://#{Regexp.escape(host)}/\z}, response.headers["Location"])

      post "https://#{host}#{surface.fetch(:backchannel_logout_path)}",
           params: { logout_token: "invalid" }

      assert_response :bad_request
      assert_equal "invalid_logout_token", response.body

      post "https://#{host}#{surface.fetch(:token_refresh_path)}",
           headers: { "Accept" => "application/json" },
           as: :json

      assert_response :service_unavailable
      assert_equal "service_unavailable", response.parsed_body.fetch("error").fetch("code")
    end
  end
end
