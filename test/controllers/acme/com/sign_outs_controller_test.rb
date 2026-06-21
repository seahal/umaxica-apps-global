# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::Com::Sign::OutsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
    @visitor = create_verified_visitor_with_email(email_address: "acme-com-sign-out-#{SecureRandom.hex(4)}@example.com")
    host! @host
  end

  test "edit sign out renders confirmation without mutation" do
    token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)

    get edit_acme_com_sign_out_url(host: @host, ri: "jp"), headers: session_headers(token)

    assert_response :success
    assert_select "p", text: I18n.t("sign.shared.sign_out.confirm_description")
    assert_select "form[action*=?][method=?]", acme_com_sign_out_path, "post"
    assert_predicate token.reload, :currently_usable?
  end

  test "post sign out revokes the current session and reaches completion" do
    token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token.rotate_refresh_token!

    post acme_com_sign_out_url(host: @host, ri: "jp"), headers: session_headers(token)

    assert_response :see_other
    assert_predicate token.reload, :revoked?

    follow_redirect!

    assert_response :success
    assert_select "h1", text: I18n.t("sign.shared.sign_out.completed_title")
  end

  test "post sign out without a resolved session renders friendly completion" do
    post acme_com_sign_out_url(host: @host, ri: "jp")

    assert_response :success
    assert_select "h1", text: I18n.t("sign.shared.sign_out.completed_title")
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
