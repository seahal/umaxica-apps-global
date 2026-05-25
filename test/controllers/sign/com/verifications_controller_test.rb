# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class Sign::Com::VerificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    host! @host
    @visitor = create_verified_visitor_with_email(
      email_address: "com-verification-#{SecureRandom.hex(4)}@example.com",
    )
    @visitor.visitor_telephones.create!(
      number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    @headers = as_visitor_headers(@visitor, host: @host)
  end

  test "should get show" do
    get sign_com_verification_url(ri: "jp"), headers: @headers

    assert_response :success
  end

  test "redirects to setup page when no verification methods are registered" do
    visitor = Visitor.create!(visibility_id: VisitorVisibility::VISITOR)
    visitor.visitor_telephones.create!(
      number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    headers = as_visitor_headers(visitor, host: @host)

    get sign_com_verification_url(ri: "jp"), headers: headers

    assert_response :redirect
    uri = URI.parse(response.location)
    query = Rack::Utils.parse_query(uri.query)

    assert_equal "/verification/setup/new", uri.path
    assert_predicate query["rt"], :present?
  end

  test "show renders only email and passkey method links" do
    return_to = ReturnTargetToken.issue(
      return_to: sign_com_configuration_emails_path(ri: "jp"),
      flow: "step_up.bootstrap",
      surface: "com",
      session_nonce: @headers["X-TEST-SESSION-PUBLIC-ID"],
    )
    VisitorPasskey.create!(
      visitor: @visitor,
      webauthn_id: Base64.urlsafe_encode64("com_verification_passkey", padding: false),
      external_id: SecureRandom.uuid,
      public_key: "verification_key",
      description: "Verification Key",
      status_id: VisitorPasskeyStatus::ACTIVE,
    )

    get sign_com_verification_url(scope: "configuration_email", return_to: return_to, ri: "jp"),
        headers: @headers

    assert_response :success
    assert_includes response.body, new_sign_com_verification_email_path(ri: "jp")
    assert_includes response.body, new_sign_com_verification_passkey_path(ri: "jp")
  end
end
