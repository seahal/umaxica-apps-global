# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::Configuration::Emails::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  fixtures :staffs, :staff_statuses, :staff_email_statuses

  setup do
    host! ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @staff = staffs(:one)
    @token = StaffToken.create!(staff: @staff, status: StaffToken::STATUS_ACTIVE)
    satisfy_staff_verification(@token)

    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  def request_headers
    {
      "Host" => @host,
      "X-TEST-CURRENT-STAFF" => @staff.id,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }
  end

  test "registration new is available" do
    get new_sign_org_configuration_emails_registration_url(ri: "jp"), headers: request_headers

    assert_response :success
  end

  test "create sends OTP email" do
    assert_enqueued_emails 1 do
      post sign_org_configuration_emails_registration_url(ri: "jp"),
           params: {
             staff_email: { raw_address: "org-config-registration@example.com" },
             "cf-turnstile-response": "test",
           },
           headers: request_headers
    end

    assert_response :redirect
    assert_redirected_to edit_sign_org_configuration_emails_registration_url(ri: "jp")
  end

  test "update verifies OTP and confirms email" do
    perform_enqueued_jobs do
      post sign_org_configuration_emails_registration_url(ri: "jp"),
           params: {
             staff_email: { raw_address: "org-config-verify@example.com" },
             "cf-turnstile-response": "test",
           },
           headers: request_headers
    end

    staff_email = StaffEmail.find_by!(address: "org-config-verify@example.com")
    otp_data = staff_email.get_otp
    code = ROTP::HOTP.new(otp_data[:otp_private_key]).at(otp_data[:otp_counter]).to_s

    patch sign_org_configuration_emails_registration_url(ri: "jp"),
          params: { staff_email: { pass_code: code } },
          headers: request_headers

    assert_redirected_to sign_org_configuration_emails_url(ri: "jp")
    assert_equal StaffEmailStatus::VERIFIED, staff_email.reload.staff_email_status_id
  end

  test "update with blank pass_code renders edit with error" do
    post sign_org_configuration_emails_registration_url(ri: "jp"),
         params: {
           staff_email: { raw_address: "org-config-blank@example.com" },
           "cf-turnstile-response": "test",
         },
         headers: request_headers

    patch sign_org_configuration_emails_registration_url(ri: "jp"),
          params: { staff_email: { pass_code: "" } },
          headers: request_headers

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.org.registration.email.update.code_required")
  end

  test "edit with invalid session redirects to new registration" do
    get edit_sign_org_configuration_emails_registration_url(ri: "jp"), headers: request_headers

    assert_response :redirect
    assert_redirected_to new_sign_org_configuration_emails_registration_url(ri: "jp")
  end
end
