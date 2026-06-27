# typed: false
# frozen_string_literal: true

require "test_helper"

class CoreBffSurfaceSmokeTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_token_kinds, :com_preference_binding_methods, :com_preferences

  SURFACES = [
    {
      host: ENV.fetch("CORE_SERVICE_URL", "core.app.localhost"),
      acme_host: ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"),
      backchannel_logout_path: "/oidc/backchannel/logout",
      token_refresh_path: "/api/v0/token/refresh",
    },
    {
      host: ENV.fetch("CORE_CORPORATE_URL", "core.com.localhost"),
      acme_host: ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost"),
      backchannel_logout_path: "/oidc/backchannel/logout",
      token_refresh_path: "/api/v0/token/refresh",
    },
    {
      host: ENV.fetch("CORE_STAFF_URL", "core.org.localhost"),
      acme_host: ENV.fetch("ACME_STAFF_URL", "www.org.localhost"),
      backchannel_logout_path: "/oidc/backchannel/logout",
      token_refresh_path: "/api/v0/token/refresh",
    },
  ].freeze

  test "core BFF and logout routes are executable on every surface" do
    SURFACES.each do |surface|
      host = surface.fetch(:host)
      host! host

      get "https://#{host}/oidc/callback"

      assert_response :unprocessable_content

      user = clients(:one)
      token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
      cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

      post "https://#{host}/sign/out", params: { ri: "jp" }, headers: {
        "X-TEST-CURRENT-USER" => user.id.to_s,
        "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
      }

      handoff_rendered = response.status.between?(200, 299)

      assert response.redirect? || handoff_rendered, "expected redirect or handoff success, got #{response.status}"
      assert_select "form#sign-out-handoff-form[method=?]", "post", maximum: 1 if handoff_rendered

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

  private

  def complete_core_sign_out_url_for(host)
    case host
    when ENV.fetch("CORE_SERVICE_URL", "core.app.localhost")
      complete_core_app_sign_out_url(ri: "jp", host: host)
    when ENV.fetch("CORE_CORPORATE_URL", "core.com.localhost")
      complete_core_com_sign_out_url(ri: "jp", host: host)
    else
      complete_core_org_sign_out_url(ri: "jp", host: host)
    end
  end
end
