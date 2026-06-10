# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::SignOutsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    @acme_host = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
    @visitor = create_verified_visitor_with_email(email_address: "com-out-#{SecureRandom.hex(4)}@example.com")
    @visitor.visitor_telephones.create!(
      number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
  end

  test "sign out confirmation does not mutate the session" do
    token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)

    get sign_com_sign_out_confirmation_url(ri: "jp"), headers: session_headers(token)

    assert_response :success
    assert_predicate token.reload, :currently_usable?
  end

  test "sign out attempt logs out and shows completion" do
    token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)

    post sign_com_sign_out_attempt_url(ri: "jp"), params: { confirm: "1" }, headers: session_headers(token)

    assert_redirected_to sign_com_sign_out_completion_url(ri: "jp")
  end

  test "sign out attempt without confirmation redirects back without mutation" do
    token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)

    post sign_com_sign_out_attempt_url(ri: "jp"), headers: session_headers(token)

    assert_redirected_to sign_com_sign_out_confirmation_url(ri: "jp")
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

end
