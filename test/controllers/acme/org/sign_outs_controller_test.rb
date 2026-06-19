# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::Org::SignOutsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_token_kinds

  setup do
    @host = ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
    @staff = operators(:one)
    host! @host
  end

  test "post sign out enters oidc end-session flow without unregistered redirect uri" do
    token = OperatorToken.create!(staff: @staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post acme_org_sign_out_url(host: @host, ri: "jp"), headers: session_headers(token)

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
      "X-TEST-CURRENT-STAFF" => @staff.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
  end
end
