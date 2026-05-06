# typed: false
# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

module Sign::App::In::Passkey
  class AuthenticationFlowTest < ActionDispatch::IntegrationTest
    fixtures :users, :user_statuses, :user_email_statuses, :user_passkey_statuses,
             :user_one_time_password_statuses

    setup do
      host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
      Jit::Security::TurnstileVerifier.test_mode = true
      Jit::Security::TurnstileVerifier.test_response = { "success" => true }
      # Mock TRUSTED_ORIGINS
      @original_trusted_origins = Webauthn.method(:trusted_origins)
      Webauthn.define_singleton_method(:trusted_origins) { ["http://id.app.localhost", "http://id.org.localhost"] }

      @user = users(:one)
      UserEmail.create!(
        user: @user,
        address: "one@example.com",
        user_email_status_id: UserEmailStatus::VERIFIED,
        otp_attempts_count: 0,
        otp_counter: "0",
        otp_private_key: "secret",
        otp_expires_at: 10.minutes.from_now,
        otp_last_sent_at: 1.hour.ago,
      )

      # Setup a passkey for the user
      @raw_credential_id = "credential-12345"
      @encoded_credential_id = Base64.urlsafe_encode64(@raw_credential_id, padding: false)

      @passkey = UserPasskey.create!(
        user: @user,
        webauthn_id: @encoded_credential_id,
        public_key: "dummy-public-key",
        sign_count: 10,
        description: "Test Passkey",
        external_id: SecureRandom.uuid,
        status_id: UserPasskeyStatus::ACTIVE,
      )
    end

    teardown do
      Webauthn.define_singleton_method(:trusted_origins, @original_trusted_origins)
      Jit::Security::TurnstileVerifier.test_mode = false
      Jit::Security::TurnstileVerifier.test_response = nil
    end

    test "should generate authentication options and store challenge in session" do
      email = @user.user_emails.first.address
      post options_sign_app_in_passkeys_url(ri: "jp"), params: options_params(identifier: email), as: :json

      assert_response :success
      json_response = response.parsed_body
      challenge_id = json_response["challenge_id"]

      assert_not_nil challenge_id

      # Verify session storage
      assert_not_nil session[:passkey_challenges]
      assert_not_nil session[:passkey_challenges][challenge_id]
      assert_equal "authentication", session[:passkey_challenges][challenge_id]["purpose"]
    end

    test "should verify valid credential and log in" do
      # 1. Get options to setup session
      email = @user.user_emails.first.address
      post options_sign_app_in_passkeys_url(ri: "jp"), params: options_params(identifier: email), as: :json

      json_response = response.parsed_body
      challenge_id = json_response["challenge_id"]
      session[:passkey_challenges][challenge_id]["challenge"]

      # 2. Mock WebAuthn verification
      mock_credential = OpenStruct.new(
        id: @encoded_credential_id,
        sign_count: 11,
      )

      # We need to verify signature and return expected result
      mock_credential.define_singleton_method(:verify) do |_challenge, **|
        true
      end

      WebAuthn::Credential.stub(:from_get, mock_credential) do
        post verification_sign_app_in_passkeys_url(ri: "jp"), params: {
          challenge_id: challenge_id,
          credential: {
            id: @encoded_credential_id,
            rawId: @encoded_credential_id,
            type: "public-key",
            response: {
              clientDataJSON: "dummy",
              authenticatorData: "dummy",
              signature: "dummy",
              userHandle: @user.public_id,
            },
          },
        }, as: :json
      end

      assert_response :success
      json_response = response.parsed_body

      assert_equal "ok", json_response["status"]
      assert_not_nil json_response["access_token"]

      # 3. Verify side effects
      # Challenge should be consumed (removed from session)
      # Challenge should be consumed (removed from session) or session reset
      assert_nil session[:passkey_challenges]
      @passkey.reload

      assert_equal 11, @passkey.sign_count # updated
    end

    test "passkey login completes without additional MFA even when MFA is enabled" do
      @user.update!(multi_factor_enabled: true)
      UserOneTimePassword.create!(
        user: @user,
        private_key: ROTP::Base32.random_base32,
        user_one_time_password_status_id: UserOneTimePasswordStatus::ACTIVE,
        title: "app",
      )

      email = @user.user_emails.first.address
      post options_sign_app_in_passkeys_url(ri: "jp"), params: options_params(identifier: email), as: :json
      challenge_id = response.parsed_body["challenge_id"]

      mock_credential = OpenStruct.new(
        id: @encoded_credential_id,
        sign_count: 12,
      )
      mock_credential.define_singleton_method(:verify) do |_challenge, **|
        true
      end

      WebAuthn::Credential.stub(:from_get, mock_credential) do
        post verification_sign_app_in_passkeys_url(ri: "jp"), params: {
          challenge_id: challenge_id,
          credential: {
            id: @encoded_credential_id,
            rawId: @encoded_credential_id,
            type: "public-key",
            response: {
              clientDataJSON: "dummy",
              authenticatorData: "dummy",
              signature: "dummy",
              userHandle: @user.public_id,
            },
          },
        }, as: :json
      end

      assert_response :success
      assert_equal "ok", response.parsed_body["status"]
      assert_not_equal "mfa_required", response.parsed_body["status"]
    end

    test "should fail verification with invalid challenge" do
      # 1. No options call (no session)

      post verification_sign_app_in_passkeys_url(ri: "jp"), params: {
        challenge_id: "invalid-id",
        credential: { id: "foo" },
      }, as: :json

      assert_response :bad_request
      json_response = response.parsed_body

      assert_equal I18n.t("errors.webauthn.challenge_invalid"), json_response["error"]
    end

    private

    def options_params(identifier:)
      {
        identifier: identifier,
        "cf-turnstile-response": "test_token",
      }
    end
  end
end
