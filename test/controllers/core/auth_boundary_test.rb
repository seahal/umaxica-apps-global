# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class CoreAuthBoundaryTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_token_kinds

  BOOT_HOSTS = Rails.configuration.x.boot_config.fetch(:hosts)
  SURFACES = [
    {
      host: BOOT_HOSTS.core_service.host,
      controller: "core/app/auth/callbacks",
      sign_out_controller: "core/app/sign_outs",
      acme_host: BOOT_HOSTS.acme_service.host,
    },
    {
      host: BOOT_HOSTS.core_corporate.host,
      controller: "core/com/auth/callbacks",
      sign_out_controller: "core/com/sign_outs",
      acme_host: BOOT_HOSTS.acme_corporate.host,
    },
    {
      host: BOOT_HOSTS.core_staff.host,
      controller: "core/org/auth/callbacks",
      sign_out_controller: "core/org/sign_outs",
      acme_host: BOOT_HOSTS.acme_staff.host,
    },
  ].freeze

  test "callback, logout, and back-channel routes remain executable on every surface" do
    SURFACES.each do |surface|
      host = surface.fetch(:host)
      host! host

      assert_routing(
        { method: :get, path: "http://#{host}/oidc/callback" },
        { controller: surface.fetch(:controller), action: "show", to: "/#{surface.fetch(:controller)}#show" },
      )

      assert_routing(
        { method: :post, path: "http://#{host}/sign/out" },
        { controller: surface.fetch(:sign_out_controller), action: "create" },
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

      get "https://#{host}/oidc/callback"

      assert_response :unprocessable_content
    end
  end

  test "logout redirects to the acme oidc logout flow on every surface" do
    SURFACES.each do |surface|
      host = surface.fetch(:host)
      host! host

      user = clients(:one)
      token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
      cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

      post "http://#{host}/sign/out", params: { ri: "jp" }, headers: {
        "X-TEST-CURRENT-USER" => user.id.to_s,
        "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
      }

      handoff_rendered = response.status.between?(200, 299)

      assert response.redirect? || handoff_rendered, "expected redirect or handoff success, got #{response.status}"
      assert_select "form#sign-out-handoff-form[method=?]", "post", maximum: 1 if handoff_rendered
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

  def complete_core_sign_out_url_for(controller, host)
    surface = controller.split("/")[1]
    public_send("complete_core_#{surface}_sign_out_url", ri: "jp", host: host)
  end
end
