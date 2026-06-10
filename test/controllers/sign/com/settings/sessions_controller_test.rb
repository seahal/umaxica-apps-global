# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::Settings::SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    @acme_host = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
    @visitor = create_verified_visitor_with_email(email_address: "com-sessions-#{SecureRandom.hex(4)}@example.com")
    @visitor.visitor_telephones.create!(
      number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    @current_token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
  end

  test "index_redirects_to_acme_session_authority" do
    get sign_com_settings_sessions_url(ri: "jp"), headers: session_headers

    assert_redirect_to_acme_sessions
  end

  test "destroy_redirect_is_not_session_mutation" do
    other_token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)

    post sign_com_settings_session_revocation_attempt_url(other_token.public_id, ri: "jp"), headers: session_headers

    assert_redirect_to_acme_sessions
    assert_predicate other_token.reload, :currently_usable?
  end

  test "others_redirect_is_not_session_inventory_mutation" do
    other_token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)

    post sign_com_settings_session_revocations_others_url(ri: "jp"), headers: session_headers

    assert_redirect_to_acme_sessions
    assert_predicate other_token.reload, :currently_usable?
  end

  test "revoke_all_redirect_is_not_session_mutation" do
    other_token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)

    post sign_com_settings_session_revocations_all_url(ri: "jp"), headers: session_headers

    assert_redirect_to_acme_sessions
    assert_predicate @current_token.reload, :currently_usable?
    assert_predicate other_token.reload, :currently_usable?
  end

  private

  def session_headers
    {
      "Host" => @host,
      "X-TEST-CURRENT-RESOURCE" => @visitor.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @current_token.public_id,
    }
  end

  def assert_redirect_to_acme_sessions
    assert_response :see_other
    location = URI.parse(response.location)

    assert_equal @acme_host, location.host
    assert_equal "/settings/sessions", location.path
    assert_equal "ri=jp", location.query
  end
end
