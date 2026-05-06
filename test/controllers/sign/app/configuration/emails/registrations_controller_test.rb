# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::Configuration::Emails::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  fixtures :users, :user_statuses, :user_token_statuses, :user_token_kinds, :user_email_statuses

  setup do
    host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @user = users(:one)
    @token = UserToken.create!(
      user: @user,
    )
    satisfy_user_verification(@token)

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
      "X-TEST-CURRENT-USER" => @user.id,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }
  end

  test "registration new is available" do
    get new_sign_app_configuration_emails_registration_url(ri: "jp"), headers: request_headers

    assert_response :success
  end

  test "create sends OTP email" do
    assert_no_difference("User.count") do
      assert_enqueued_emails 1 do
        post sign_app_configuration_emails_registration_url(ri: "jp"),
             params: {
               user_email: {
                 raw_address: "config-registration@example.com",
               },
               "cf-turnstile-response": "test",
             },
             headers: request_headers
      end
    end

    assert_response :redirect
    assert_redirected_to edit_sign_app_configuration_emails_registration_url(ri: "jp")
  end

  test "update verifies OTP and confirms email" do
    perform_enqueued_jobs do
      post sign_app_configuration_emails_registration_url(ri: "jp"),
           params: {
             user_email: {
               raw_address: "config-verify@example.com",
             },
             "cf-turnstile-response": "test",
           },
           headers: request_headers
    end

    user_email = UserEmail.find_by!(address: "config-verify@example.com")
    otp_data = user_email.get_otp
    code = ROTP::HOTP.new(otp_data[:otp_private_key]).at(otp_data[:otp_counter]).to_s

    patch sign_app_configuration_emails_registration_url(ri: "jp"),
          params: {
            user_email: {
              pass_code: code,
            },
          },
          headers: request_headers

    assert_redirected_to sign_app_configuration_emails_url(ri: "jp")
    assert_equal UserEmailStatus::VERIFIED_WITH_SIGN_UP, user_email.reload.user_email_status_id
    assert_equal @user.id, user_email.user_id
  end

  test "edit falls back to latest unverified email when session is missing" do
    post sign_app_configuration_emails_registration_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: "config-session-recovery@example.com",
           },
           "cf-turnstile-response": "test",
         },
         headers: request_headers

    session.delete(:email_registration_public_id)

    get edit_sign_app_configuration_emails_registration_url(ri: "jp"), headers: request_headers

    assert_response :success
  end

  test "update with blank pass_code renders edit with error" do
    post sign_app_configuration_emails_registration_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: "config-blank-code@example.com",
           },
           "cf-turnstile-response": "test",
         },
         headers: request_headers

    user_email = UserEmail.find_by!(address: "config-blank-code@example.com")
    session[:email_registration_public_id] = user_email.public_id

    patch sign_app_configuration_emails_registration_url(ri: "jp"),
          params: {
            user_email: {
              pass_code: "",
            },
          },
          headers: request_headers

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("sign.app.registration.email.update.code_required")
  end

  test "update with wrong pass_code renders edit with error" do
    post sign_app_configuration_emails_registration_url(ri: "jp"),
         params: {
           user_email: {
             raw_address: "config-wrong-code@example.com",
           },
           "cf-turnstile-response": "test",
         },
         headers: request_headers

    user_email = UserEmail.find_by!(address: "config-wrong-code@example.com")
    session[:email_registration_public_id] = user_email.public_id

    patch sign_app_configuration_emails_registration_url(ri: "jp"),
          params: {
            user_email: {
              pass_code: "000000",
            },
          },
          headers: request_headers

    assert_response :unprocessable_content
  end

  test "edit with invalid session redirects to new registration" do
    get edit_sign_app_configuration_emails_registration_url(ri: "jp"), headers: request_headers

    assert_response :redirect
    assert_redirected_to new_sign_app_configuration_emails_registration_url(ri: "jp")
    assert_includes flash[:notice], I18n.t("sign.app.registration.email.edit.session_expired")
  end
end
