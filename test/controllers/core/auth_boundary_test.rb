# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class CoreAuthBoundaryTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_token_kinds, :operators, :operator_token_kinds

  BOOT_HOSTS = Rails.configuration.x.boot_config.fetch(:hosts)
  SURFACES = [
    {
      host: BOOT_HOSTS.core_service.host,
      controller: "core/app/auth/callbacks",
      sign_out_controller: "core/app/sign_outs",
      acme_host: BOOT_HOSTS.acme_service.host,
      jwt_issuer_id: "surface:CORE_APP",
      resource_type: "client",
    },
    {
      host: BOOT_HOSTS.core_corporate.host,
      controller: "core/com/auth/callbacks",
      sign_out_controller: "core/com/sign_outs",
      acme_host: BOOT_HOSTS.acme_corporate.host,
      jwt_issuer_id: "surface:CORE_COM",
      resource_type: "visitor",
    },
    {
      host: BOOT_HOSTS.core_staff.host,
      controller: "core/org/auth/callbacks",
      sign_out_controller: "core/org/sign_outs",
      acme_host: BOOT_HOSTS.acme_staff.host,
      jwt_issuer_id: "surface:CORE_ORG",
      resource_type: "operator",
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

  test "logout redirects to the base oidc logout flow on every surface" do
    SURFACES.each do |surface|
      host = surface.fetch(:host)
      host!(host)

      resource_type = surface.fetch(:resource_type)
      user, token, token_class = actor_and_token_for(resource_type)
      cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

      post(
        "http://#{host}/sign/out", params: { ri: "jp" },
                                   headers: bearer_headers(
                                     AuthenticationToken.encode(
                                       user, host: host, session_public_id: token.public_id, resource_type: resource_type,
                                             jwt_issuer_id: surface.fetch(:jwt_issuer_id),
                                     ),
                                   ),
      )

      handoff_rendered = response.status.between?(200, 299)

      assert response.redirect? || handoff_rendered, "expected redirect or handoff success, got #{response.status}"
      assert_select "form#sign-out-handoff-form[method=?]", "post", maximum: 1 if handoff_rendered
    ensure
      # Each surface iteration mints a fresh session for the same fixture
      # user; revoke it so the per-user concurrent session cap isn't hit on
      # a later surface in this loop.
      AuthenticationLogoutCurrentSession.call(
        resource: user,
        token_class: token_class,
        session_public_id: token.public_id,
        reason: "test_cleanup",
      )
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

  def core_sign_out_completion_url_for(controller, host)
    surface = controller.split("/")[1]
    public_send("core_#{surface}_sign_out_completion_url", ri: "jp", host: host)
  end

  private

  def bearer_headers(token, headers: {})
    headers.merge("Authorization" => "Bearer #{token}")
  end

  def actor_and_token_for(resource_type)
    case resource_type
    when "operator"
      staff = operators(:one)
      token = OperatorToken.create!(staff: staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
      [staff, token, OperatorToken]
    when "visitor"
      VisitorStatus.ensure_defaults!
      VisitorVisibility.ensure_defaults!
      visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
      token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
      [visitor, token, VisitorToken]
    else
      user = clients(:one)
      token = ClientToken.create!(user: user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
      [user, token, ClientToken]
    end
  end
end
