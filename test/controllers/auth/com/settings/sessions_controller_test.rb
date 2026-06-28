# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Com::Settings::SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("AUTH_CORPORATE_URL", "auth.com.localhost")
    @visitor = create_verified_visitor_with_email(email_address: "com-sessions-#{SecureRandom.hex(4)}@example.com")
    @visitor.visitor_telephones.create!(
      number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    @current_token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
  end

  test "index renders sign session inventory" do
    get auth_com_settings_sessions_url(ri: "jp"), headers: session_headers

    assert_response :success
    assert_includes response.body, @current_token.public_id
  end

  test "selected revocation revokes other session" do
    other_token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)

    post auth_com_settings_session_revocation_url(other_token.public_id, ri: "jp"), headers: session_headers

    assert_redirected_to auth_com_settings_sessions_path(ri: "jp")
    assert_not_predicate other_token.reload, :currently_usable?
  end

  test "others revocation preserves current session" do
    other_token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)

    post auth_com_settings_revocations_others_url(ri: "jp"), headers: session_headers

    assert_redirected_to auth_com_settings_sessions_path(ri: "jp")
    assert_predicate @current_token.reload, :currently_usable?
    assert_not_predicate other_token.reload, :currently_usable?
  end

  test "revoke all revokes every session" do
    other_token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)

    post auth_com_settings_revocations_all_url(ri: "jp"), headers: session_headers

    assert_redirected_to auth_com_sign_out_path(ri: "jp")
    assert_not_predicate @current_token.reload, :currently_usable?
    assert_not_predicate other_token.reload, :currently_usable?
  end

  private

  def session_headers
    {
      "Host" => @host,
      "X-TEST-CURRENT-RESOURCE" => @visitor.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @current_token.public_id,
    }
  end
end
