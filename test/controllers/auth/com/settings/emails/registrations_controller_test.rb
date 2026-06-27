# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Com::Settings::Emails::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("SIGN_CORPORATE_URL", "id.com.localhost")
    @host = ENV.fetch("SIGN_CORPORATE_URL", "id.com.localhost")
    @visitor = create_verified_visitor_with_email(
      email_address: "com-config-registration-#{SecureRandom.hex(4)}@example.com",
    )
    @visitor.visitor_telephones.create!(
      number: "+1555#{SecureRandom.random_number(10**7).to_s.rjust(7, "0")}",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    @headers = as_visitor_headers(@visitor, host: @host)
    @token = VisitorToken.find_by!(public_id: @headers["X-TEST-SESSION-PUBLIC-ID"])
    satisfy_visitor_verification(@token)
    mark_token_step_up_satisfied_for_test(@token, scope: "settings_email")

    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  test "new renders notification preference only" do
    get new_sign_com_settings_emails_registration_url(
      ri: "jp",
    ), headers: @headers

    assert_response :success
    assert_select "input[type=email][name='visitor_email[address]']", count: 1
    assert_select "input[type=checkbox][name='visitor_email[notifiable]']", count: 1
    assert_select "input[type=checkbox][name='visitor_email[promotional]']", count: 0
  end

  test "new allows bootstrap when visitor multi factor status is unconfigured" do
    visitor = Visitor.create!(status_id: VisitorStatus::NOTHING)
    visitor.visitor_telephones.create!(
      number: "+1555#{SecureRandom.random_number(10**7).to_s.rjust(7, "0")}",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    headers = as_visitor_headers(visitor, host: @host)
    token = VisitorToken.find_by!(public_id: headers["X-TEST-SESSION-PUBLIC-ID"])
    token.update!(created_at: 1.hour.ago, last_step_up_at: nil, last_step_up_scope: nil)
    get new_sign_com_settings_emails_registration_url(
      ri: "jp",
    ), headers: headers

    assert_response :success
    assert_equal VisitorMfaStatus::UNCONFIGURED, visitor.reload.mfa_status_id
  end

  test "new requires step up when visitor multi factor status is active" do
    @token.update!(created_at: 1.hour.ago, last_step_up_at: nil, last_step_up_scope: nil)

    get new_sign_com_settings_emails_registration_url(ri: "jp"), headers: @headers

    assert_response :redirect
    uri = URI.parse(response.location)
    query = Rack::Utils.parse_query(uri.query)

    assert_equal "/verification", uri.path
    assert_equal "settings_email", query["scope"]
    assert_equal VisitorMfaStatus::ACTIVE, @visitor.reload.mfa_status_id
  end

  test "create sends OTP email and stores notification preference" do
    get new_sign_com_settings_emails_registration_url(
      ri: "jp",
    ), headers: @headers

    assert_enqueued_emails 1 do
      post sign_com_settings_emails_registration_url(ri: "jp"),
           params: {
             visitor_email: { raw_address: "com-config-new@example.com", notifiable: "0" },
             "cf-turnstile-response": "test",
           },
           headers: @headers
    end

    assert_response :redirect
    assert_redirected_to edit_sign_com_settings_emails_registration_url(ri: "jp")

    get edit_sign_com_settings_emails_registration_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_select "h1", text: I18n.t("sign.app.authentication.email.edit.page_title")
    assert_select "label", text: I18n.t("sign.app.authentication.email.edit.code_label")
    assert_select "input[placeholder=?]", I18n.t("sign.app.authentication.email.edit.code_placeholder")
    assert_select "input[type=submit][value=?]", I18n.t("sign.app.authentication.email.edit.submit")
    assert_includes response.body, "メールアドレス"
    assert_includes response.body, I18n.t("sign.app.authentication.email.edit.delivery_help")

    visitor_email = @visitor.visitor_emails.order(:created_at).last

    assert_equal "com-config-new@example.com", visitor_email.address
    assert_not visitor_email.notifiable
  end
end
