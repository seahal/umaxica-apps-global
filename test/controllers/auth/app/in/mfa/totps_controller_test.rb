# typed: false
# frozen_string_literal: true

require "test_helper"

module Auth::App::In
  class MfaTotpsControllerTest < ActionDispatch::IntegrationTest
    fixtures :client_statuses, :client_passkey_statuses, :client_secret_credential_kinds,
             :client_secret_credential_statuses, :client_email_statuses, :client_totp_credential_statuses

    setup do
      host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
      CloudflareTurnstile.test_mode = true
      CloudflareTurnstile.test_validation_response = { "success" => true }

      @user = Client.create!(mfa_level_enabled: true)
      @email = "mfa_totp_#{SecureRandom.hex(4)}@example.com".freeze
      @user.client_emails.create!(address: @email, user_email_status_id: ClientEmailStatus::VERIFIED)
      @totp = ClientTotpCredential.create!(
        user: @user,
        private_key: ROTP::Base32.random_base32,
        user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
        title: "totp",
      )

      _secret_credential, @raw_secret_credential = ClientSecretCredential.issue!(
        name: "TOTP MFA secret_credential",
        user_id: @user.id,
        user_secret_kind_id: ClientSecretCredentialKind::PERMANENT,
        uses: 10,
        status: :active,
      )
    end

    teardown do
      CloudflareTurnstile.test_mode = false
      CloudflareTurnstile.test_validation_response = nil
    end

    def with_prosopite_paused
      Prosopite.pause { yield }
    end

    test "new renders form with stealth when pending_mfa exists" do
      with_prosopite_paused do
        establish_pending_mfa_via_secret_credential!
      end

      with_prosopite_paused do
        get new_sign_app_sign_in_challenge_totp_path(ri: "jp")
      end

      assert_response :success
      assert_select "input[name='cf-turnstile-response']"
      assert_select "h1", text: I18n.t("sign.app.in.mfa.totp.title")
      assert_select "label", text: I18n.t("sign.app.in.mfa.totp.token_label")
      assert_select "input[placeholder=?]", I18n.t("sign.app.in.mfa.totp.token_placeholder")
      assert_select "input[type=submit][value=?]", I18n.t("sign.app.in.mfa.totp.submit")
      assert_includes response.body, "認証アプリ"
      assert_includes response.body, I18n.t("sign.app.in.mfa.totp.help")
      assert_not_includes response.body, "届きます"
      assert_not_includes response.body, "送信され"
    end

    test "new redirects to sign in when pending_mfa is missing" do
      with_prosopite_paused do
        get new_sign_app_sign_in_challenge_totp_path(ri: "jp")
      end

      assert_response :see_other
      assert_redirected_to sign_app_sign_in_path(ri: "jp")
      assert_equal I18n.t("sign.app.in.mfa.session_expired"), flash[:alert]
    end

    test "create with valid TOTP code redirects to settings" do
      with_prosopite_paused do
        establish_pending_mfa_via_secret_credential!
      end

      # Verify pending_mfa was set
      assert_predicate session[:pending_mfa], :present?, "pending_mfa should be set after secret_credential login"
      user_id = session[:pending_mfa]["user_id"]
      user = Client.find(user_id)

      # Verify user's OTPs are accessible
      otps = user.client_totp_credentials
        .where(user_identity_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE)

      assert_not_empty otps,
                       "Client should have active OTPs. All OTPs: #{user.client_totp_credentials.pluck(
                         :id,
                         :user_identity_totp_credential_status_id,
                       ).inspect}"

      totp_code = ROTP::TOTP.new(@totp.private_key).now

      with_prosopite_paused do
        post sign_app_sign_in_challenge_totp_path(ri: "jp"), params: {
          totp_challenge_form: { token: totp_code },
        }
      end

      # Debug: check if the response body contains TOTP verification error
      if response.status == 422
        errors = response.body.scan(/class="[^"]*error[^"]*"[^>]*>([^<]+)</)

        flunk "TOTP verification failed (422). Errors: #{errors.inspect}. " \
              "TOTP code: #{totp_code}. " \
              "Client OTP count: #{user.client_totp_credentials.count}. " \
              "pending_mfa after: #{session[:pending_mfa].inspect}"
      end

      assert_response :found
      assert_match %r{\Ahttp://id\.umaxica\.app/sign/in/check}, response.location
      assert_nil session[:pending_mfa]
      assert_not_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    end

    test "create with invalid TOTP code renders form with error" do
      with_prosopite_paused do
        establish_pending_mfa_via_secret_credential!
      end

      with_prosopite_paused do
        post sign_app_sign_in_challenge_totp_path(ri: "jp"), params: {
          totp_challenge_form: { token: "000000" },
        }
      end

      assert_response :unprocessable_content
      assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    end

    test "create with valid TOTP code and stealth failure renders form with error" do
      with_prosopite_paused do
        establish_pending_mfa_via_secret_credential!
      end

      CloudflareTurnstile.test_validation_response = { "success" => false }

      totp_code = ROTP::TOTP.new(@totp.private_key).now

      with_prosopite_paused do
        post sign_app_sign_in_challenge_totp_path(ri: "jp"), params: {
          totp_challenge_form: { token: totp_code },
        }
      end

      assert_response :unprocessable_content
      assert_includes response.body, I18n.t("session_limit.turnstile_failed")
      assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    end

    # Regression guard for FINDING-06: same TOTP window must not be accepted twice.
    # Simulates a concurrent request that already consumed the current window by
    # pre-setting last_otp_at to the window timestamp before the request arrives.
    test "create rejects TOTP code whose window has already been consumed" do
      with_prosopite_paused do
        establish_pending_mfa_via_secret_credential!
      end

      totp_code = ROTP::TOTP.new(@totp.private_key).now
      otp_window_at = ROTP::TOTP.new(@totp.private_key).verify(totp_code.to_s)

      # Pre-consume the window -- simulates a concurrent request that beat this one
      @totp.update!(last_otp_at: Time.zone.at(otp_window_at))

      with_prosopite_paused do
        post sign_app_sign_in_challenge_totp_path(ri: "jp"), params: {
          totp_challenge_form: { token: totp_code },
        }
      end

      assert_response :unprocessable_content
      assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    end

    test "create without pending_mfa redirects to sign in" do
      with_prosopite_paused do
        post sign_app_sign_in_challenge_totp_path(ri: "jp"), params: {
          totp_challenge_form: { token: "123456" },
        }
      end

      assert_response :see_other
      assert_redirected_to sign_app_sign_in_path(ri: "jp")
    end

    private

    def establish_pending_mfa_via_secret_credential!
      with_prosopite_paused do
        post(
          sign_app_sign_in_secret_credential_path(ri: "jp"), params: {
            secret_credential_login_form: {
              identifier: @email,
              secret_credential_value: @raw_secret_credential,
            },
            "cf-turnstile-response": "test_token",
          },
        )
      end

      assert_response :redirect
    end
  end
end
