# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::VerificationsControllerTest < ActionDispatch::IntegrationTest
  fixtures :staffs, :staff_tokens, :staff_passkeys

  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @staff = staffs(:one)
    @headers = as_staff_headers(@staff, host: @host)
    @token = staff_tokens(:one)
    @headers["X-TEST-SESSION-PUBLIC-ID"] = @token.public_id
    @passkey = staff_passkeys(:one)
  end

  test "should get show" do
    get sign_org_verification_url(ri: "jp"), headers: @headers

    assert_response :success
  end

  test "show with scope and return_to params" do
    return_to = Base64.urlsafe_encode64("/org/configuration")

    get sign_org_verification_url(scope: "configuration_email", return_to: return_to, ri: "jp"),
        headers: @headers

    assert_response :redirect
  end

  test "show redirects to configuration when return_to is invalid" do
    get sign_org_verification_url(scope: "configuration_email", return_to: "%%%INVALID%%%", ri: "jp"),
        headers: @headers

    assert_redirected_to sign_org_configuration_path(ri: "jp")
  end

  test "show handles recent verification" do
    @token.update!(last_step_up_at: 5.minutes.ago, last_step_up_scope: "configuration_email")

    get sign_org_verification_url(ri: "jp"), headers: @headers

    assert_response :success
  end
end
