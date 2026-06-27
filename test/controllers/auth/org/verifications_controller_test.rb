# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Org::VerificationsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_tokens, :operator_passkeys

  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @staff = operators(:one)
    @headers = as_staff_headers(@staff, host: @host)
    @token = operator_tokens(:one)
    @headers["X-TEST-SESSION-PUBLIC-ID"] = @token.public_id
    @passkey = operator_passkeys(:one)
  end

  test "should get show" do
    get sign_org_verification_url(ri: "jp"), headers: @headers

    assert_response :success
  end

  test "show with scope and return_to params" do
    return_to = Base64.urlsafe_encode64("/org/settings")

    get sign_org_verification_url(scope: "settings_email", return_to: return_to, ri: "jp"),
        headers: @headers

    assert_response :success
  end

  test "show redirects to settings when return_to is invalid" do
    get sign_org_verification_url(scope: "settings_email", return_to: "%%%INVALID%%%", ri: "jp"),
        headers: @headers

    assert_response :success
  end

  test "show handles recent verification" do
    @token.update!(last_step_up_at: 5.minutes.ago, last_step_up_scope: "settings_email")

    get sign_org_verification_url(ri: "jp"), headers: @headers

    assert_response :success
  end
end
