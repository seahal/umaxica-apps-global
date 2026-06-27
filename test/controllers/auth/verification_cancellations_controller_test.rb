# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::VerificationCancellationsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :operators, :client_tokens, :operator_tokens, :client_statuses, :operator_passkeys

  test "app cancellation clears local step-up session and renders acme cancellation handoff" do
    host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    user = clients(:one)
    headers = as_user_headers(user, host: host)
    token = ClientToken.find_by!(public_id: headers["X-TEST-SESSION-PUBLIC-ID"])
    return_to = auth_app_settings_emails_path(ri: "jp")
    grant = signed_step_up_grant_for(
      actor: user, token: token, scope: "settings_email", return_to: return_to, surface: "app",
    )

    get auth_app_verification_url(
      scope: "settings_email",
      pt: signed_step_up_pt_for(return_to, surface: "app", session_nonce: token.public_id),
      ri: "jp",
      step_up_ceremony_grant: grant,
    ),
        headers: headers

    post auth_app_verification_cancellation_url(ri: "jp"), headers: headers

    assert_response :success
    assert_includes response.body, "/verification/cancellation"
    assert_nil token.reload.step_up_session
  end

  test "com cancellation clears local step-up session and renders acme cancellation handoff" do
    host = ENV.fetch("SIGN_CORPORATE_URL", "id.com.localhost")
    visitor = create_verified_visitor_with_email(email_address: "cancel-com-#{SecureRandom.hex(4)}@example.com")
    visitor.visitor_telephones.create!(
      number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    headers = as_visitor_headers(visitor, host: host)
    token = VisitorToken.find_by!(public_id: headers["X-TEST-SESSION-PUBLIC-ID"])
    return_to = auth_com_settings_emails_path(ri: "jp")
    grant = signed_step_up_grant_for(
      actor: visitor, token: token, scope: "settings_email", return_to: return_to, surface: "com",
    )

    get auth_com_verification_url(
      scope: "settings_email",
      pt: signed_step_up_pt_for(return_to, surface: "com", session_nonce: token.public_id),
      ri: "jp",
      step_up_ceremony_grant: grant,
    ),
        headers: headers

    post auth_com_verification_cancellation_url(ri: "jp"), headers: headers

    assert_response :success
    assert_includes response.body, "/verification/cancellation"
    assert_nil token.reload.step_up_session
  end

  test "org cancellation clears local step-up session and renders acme cancellation handoff" do
    host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    staff = operators(:one)
    headers = as_staff_headers(staff, host: host)
    token = OperatorToken.find_by!(public_id: headers["X-TEST-SESSION-PUBLIC-ID"])
    return_to = auth_org_settings_path(ri: "jp")
    grant = signed_step_up_grant_for(
      actor: staff, token: token, scope: "settings_email", return_to: return_to, surface: "org",
    )

    get auth_org_verification_url(
      scope: "settings_email",
      pt: signed_step_up_pt_for(return_to, surface: "org", session_nonce: token.public_id),
      ri: "jp",
      step_up_ceremony_grant: grant,
    ),
        headers: headers

    post auth_org_verification_cancellation_url(ri: "jp"), headers: headers

    assert_response :see_other
    assert_equal auth_org_settings_path(ri: "jp"), URI.parse(response.location).request_uri
    assert_nil token.reload.step_up_session
  end
end
