# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::Settings::Emails::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses, :operator_email_statuses

  setup do
    host! ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    cookies["csrf_token"] = csrf_token_value
    @staff = operators(:one)
    @token = OperatorToken.create!(staff: @staff, staff_token_status_id: OperatorTokenStatus::ACTIVE)
    satisfy_staff_verification(@token)
    mark_token_step_up_satisfied_for_test(@token, scope: "settings_email")

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
      "X-CSRF-Token" => csrf_token_value,
    }
  end

  test "registration new is available" do
    setup_email_ceremony_grant

    assert_response :success
    assert_select "input[type=checkbox][name='staff_email[notifiable]']", count: 1
    assert_select "input[type=checkbox][name='staff_email[promotional]']", count: 0
  end

  test "registration edit renders stealth turnstile" do
    setup_email_ceremony_grant
    perform_enqueued_jobs do
      post sign_org_settings_emails_registration_url(ri: "jp"),
           params: {
             staff_email: { raw_address: "org-config-edit@example.com" },
             "cf-turnstile-response": "test",
           },
           headers: request_headers
    end

    get edit_sign_org_settings_emails_registration_url(ri: "jp"), headers: request_headers

    assert_response :success
    assert_select "input[name='cf-turnstile-response'][type='hidden']", count: 1
    assert_includes response.body, 'data-turnstile-mode-value="execute"'
    assert_select "h1", text: I18n.t("sign.app.authentication.email.edit.page_title")
    assert_select "label", text: I18n.t("sign.app.authentication.email.edit.code_label")
    assert_select "input[placeholder=?]", I18n.t("sign.app.authentication.email.edit.code_placeholder")
    assert_select "input[type=submit][value=?]", I18n.t("sign.app.authentication.email.edit.submit")
    assert_includes response.body, "メールアドレス"
    assert_includes response.body, I18n.t("sign.app.authentication.email.edit.delivery_help")
  end

  test "create sends OTP email and stores notification preference" do
    setup_email_ceremony_grant
    assert_enqueued_emails 1 do
      post sign_org_settings_emails_registration_url(ri: "jp"),
           params: {
             staff_email: { raw_address: "org-config-registration@example.com", notifiable: "0" },
             "cf-turnstile-response": "test",
           },
           headers: request_headers
    end

    assert_response :redirect
    assert_redirected_to edit_sign_org_settings_emails_registration_url(ri: "jp")
    assert_not @staff.operator_emails.order(:created_at).last.notifiable
  end

  test "update verifies OTP and confirms email" do
    setup_email_ceremony_grant
    perform_enqueued_jobs do
      post sign_org_settings_emails_registration_url(ri: "jp"),
           params: {
             staff_email: { raw_address: "org-config-verify@example.com" },
             "cf-turnstile-response": "test",
           },
           headers: request_headers
    end

    staff_email = @staff.operator_emails.order(:created_at).last

    assert_not_nil staff_email
    otp_data = staff_email.get_otp
    code = ROTP::HOTP.new(otp_data[:otp_private_key]).at(otp_data[:otp_counter]).to_s

    patch sign_org_settings_emails_registration_url(ri: "jp"),
          params: { staff_email: { pass_code: code } },
          headers: request_headers

    assert_redirected_to acme_org_settings_emails_url(
      ri: "jp",
      host: ENV.fetch("ACME_STAFF_URL", "www.org.localhost"),
    )
    assert_equal OperatorEmailStatus::VERIFIED, staff_email.reload.staff_email_status_id
  end

  test "update rejects when turnstile fails" do
    setup_email_ceremony_grant
    perform_enqueued_jobs do
      post sign_org_settings_emails_registration_url(ri: "jp"),
           params: {
             staff_email: { raw_address: "org-config-turnstile-failure@example.com" },
             "cf-turnstile-response": "test",
           },
           headers: request_headers
    end

    staff_email = @staff.operator_emails.order(:created_at).last
    CloudflareTurnstile.test_validation_response = { "success" => false }

    patch sign_org_settings_emails_registration_url(ri: "jp"),
          params: { staff_email: { pass_code: "123456" } },
          headers: request_headers

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("turnstile_error")
    assert_equal OperatorEmailStatus::UNVERIFIED, staff_email.reload.staff_email_status_id
  end

  test "update with blank pass_code renders edit with error" do
    setup_email_ceremony_grant
    post sign_org_settings_emails_registration_url(ri: "jp"),
         params: {
           staff_email: { raw_address: "org-config-blank@example.com" },
           "cf-turnstile-response": "test",
         },
         headers: request_headers

    patch sign_org_settings_emails_registration_url(ri: "jp"),
          params: { staff_email: { pass_code: "" } },
          headers: request_headers

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.org.registration.email.update.code_required")
  end

  test "edit with invalid session redirects to new registration" do
    get edit_sign_org_settings_emails_registration_url(ri: "jp"), headers: request_headers

    assert_response :redirect
    assert_redirected_to new_sign_org_settings_emails_registration_url(ri: "jp")
  end

  private

  def setup_email_ceremony_grant
    issuance = IdentityEmailCeremonyGrantIssuer.issue!(
      surface: "org",
      actor_ref: @staff.public_id,
      session_ref: @token.public_id,
      operation: "registration",
    )
    get(
      new_sign_org_settings_emails_registration_url(
        ri: "jp",
        email_ceremony_grant: issuance.grant,
      ), headers: request_headers,
    )
  end
end
