# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign::App::In
  class MfaTotpsControllerTest < ActionDispatch::IntegrationTest
    fixtures :user_statuses, :user_passkey_statuses, :user_secret_kinds, :user_secret_statuses, :user_email_statuses,
             :user_one_time_password_statuses

    setup do
      host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
      CloudflareTurnstile.test_mode = true
      CloudflareTurnstile.test_validation_response = { "success" => true }

      @user = User.create!(multi_factor_enabled: true)
      @email = "mfa_totp_#{SecureRandom.hex(4)}@example.com".freeze
      @user.user_emails.create!(address: @email, user_email_status_id: UserEmailStatus::VERIFIED)
      @totp = UserOneTimePassword.create!(
        user: @user,
        private_key: ROTP::Base32.random_base32,
        user_one_time_password_status_id: UserOneTimePasswordStatus::ACTIVE,
        title: "totp",
      )

      _secret, @raw_secret = UserSecret.issue!(
        name: "TOTP MFA secret",
        user_id: @user.id,
        user_secret_kind_id: UserSecretKind::PERMANENT,
        uses: 10,
        status: :active,
      )
    end

    teardown do
      CloudflareTurnstile.test_mode = false
      CloudflareTurnstile.test_validation_response = nil
    end

    test "new redirects to sign in when pending_mfa is missing" do
      get new_sign_app_in_challenge_totp_path(ri: "jp")

      assert_response :see_other
      assert_redirected_to new_sign_app_in_path(ri: "jp")
      assert_equal I18n.t("sign.app.in.mfa.session_expired"), flash[:alert]
    end

    test "create with valid TOTP code redirects to configuration" do
      establish_pending_mfa_via_secret!

      # Verify pending_mfa was set
      assert_predicate session[:pending_mfa], :present?, "pending_mfa should be set after secret login"
      user_id = session[:pending_mfa]["user_id"]
      user = User.find(user_id)

      # Verify user's OTPs are accessible
      otps = user.user_one_time_passwords
        .where(user_identity_one_time_password_status_id: UserOneTimePasswordStatus::ACTIVE)

      assert_not_empty otps,
                       "User should have active OTPs. All OTPs: #{user.user_one_time_passwords.pluck(
                         :id,
                         :user_identity_one_time_password_status_id,
                       ).inspect}"

      totp_code = ROTP::TOTP.new(@totp.private_key).now

      post sign_app_in_challenge_totp_path(ri: "jp"), params: {
        totp_challenge_form: { token: totp_code },
      }

      # Debug: check if the response body contains TOTP verification error
      if response.status == 422
        errors = response.body.scan(/class="[^"]*error[^"]*"[^>]*>([^<]+)</)

        flunk "TOTP verification failed (422). Errors: #{errors.inspect}. " \
              "TOTP code: #{totp_code}. " \
              "User OTP count: #{user.user_one_time_passwords.count}. " \
              "pending_mfa after: #{session[:pending_mfa].inspect}"
      end

      assert_response :found
      assert_redirected_to sign_app_configuration_path(ri: "jp")
      assert_nil session[:pending_mfa]
      assert_not_nil cookies[Authentication::Base::ACCESS_COOKIE_KEY]
    end

    test "create with invalid TOTP code renders form with error" do
      establish_pending_mfa_via_secret!

      post sign_app_in_challenge_totp_path(ri: "jp"), params: {
        totp_challenge_form: { token: "000000" },
      }

      assert_response :unprocessable_content
      assert_nil cookies[Authentication::Base::ACCESS_COOKIE_KEY]
    end

    test "create without pending_mfa redirects to sign in" do
      post sign_app_in_challenge_totp_path(ri: "jp"), params: {
        totp_challenge_form: { token: "123456" },
      }

      assert_response :see_other
      assert_redirected_to new_sign_app_in_path(ri: "jp")
    end

    private

    def establish_pending_mfa_via_secret!
      post(
        sign_app_in_secret_path(ri: "jp"), params: {
          secret_login_form: {
            identifier: @email,
            secret_value: @raw_secret,
          },
          "cf-turnstile-response": "test_token",
        },
      )

      assert_response :redirect
    end
  end
end
