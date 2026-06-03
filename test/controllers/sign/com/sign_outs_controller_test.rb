# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::SignOutsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    @acme_host = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
    @visitor = create_verified_visitor_with_email(email_address: "com-out-#{SecureRandom.hex(4)}@example.com")
  end

  test "sign_out_get_redirect_is_not_session_mutation" do
    token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)

    get sign_com_sign_out_url(ri: "jp"), headers: session_headers(token)

    assert_redirect_to_acme_sign_out
    assert_predicate token.reload, :currently_usable?
  end

  test "sign_out_post_redirect_uses_acme_authority" do
    token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)

    post sign_com_sign_out_url(ri: "jp"), params: { confirm: "1" }, headers: session_headers(token)

    assert_redirect_to_acme_sign_out
    assert_predicate token.reload, :currently_usable?
  end

  test "sign_out_destroy_redirect_is_not_session_mutation" do
    token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)

    delete sign_com_sign_out_url(ri: "jp"), headers: session_headers(token)

    assert_redirect_to_acme_sign_out
    assert_predicate token.reload, :currently_usable?
  end

  private

  def session_headers(token)
    {
      "Host" => @host,
      "X-TEST-CURRENT-RESOURCE" => @visitor.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
  end

  def assert_redirect_to_acme_sign_out
    assert_response :see_other
    location = URI.parse(response.location)

    assert_equal @acme_host, location.host
    assert_equal "/sign/out", location.path
    assert_equal "ri=jp", location.query
  end
end
