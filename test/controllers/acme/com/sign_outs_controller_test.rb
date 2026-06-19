# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::Com::SignOutsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
    @visitor = create_verified_visitor_with_email(email_address: "acme-com-sign-out-#{SecureRandom.hex(4)}@example.com")
    host! @host
  end

  test "post sign out enters oidc end-session flow without unregistered redirect uri" do
    token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post acme_com_sign_out_url(host: @host, ri: "jp"), headers: session_headers(token)

    assert_response :temporary_redirect
    location = URI.parse(response.location)
    query = Rack::Utils.parse_nested_query(location.query.to_s)

    assert_equal "/oidc/logout", location.path
    assert_predicate query["id_token_hint"], :present?
    assert_nil query["post_logout_redirect_uri"]
  end

  private

  def session_headers(token)
    {
      "Host" => @host,
      "X-TEST-CURRENT-RESOURCE" => @visitor.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
  end
end
