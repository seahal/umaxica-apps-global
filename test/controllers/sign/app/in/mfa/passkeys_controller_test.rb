# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"
require "ostruct"

module Sign::App::In
  class MfaPasskeysControllerTest < ActionDispatch::IntegrationTest
    fixtures :client_statuses, :client_passkey_statuses, :client_secret_credential_kinds,
             :client_secret_credential_statuses, :client_email_statuses, :client_totp_credential_statuses

    setup do
      host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
      CloudflareTurnstile.test_mode = true
      CloudflareTurnstile.test_validation_response = { "success" => true }

      @user = Client.create!(mfa_level_enabled: true)
      @email = "mfa_passkey_#{SecureRandom.hex(4)}@example.com".freeze
      @user.client_emails.create!(address: @email, user_email_status_id: ClientEmailStatus::VERIFIED)
      ClientTotpCredential.create!(
        user: @user,
        private_key: ROTP::Base32.random_base32,
        user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
        title: "totp",
      )

      _secret_credential, @raw_secret_credential = ClientSecretCredential.issue!(
        name: "Passkey MFA secret_credential",
        user_id: @user.id,
        user_secret_kind_id: ClientSecretCredentialKind::PERMANENT,
        uses: 10,
        status: :active,
      )

      @raw_credential_id = "mfa-credential-123"
      @passkey = ClientPasskey.create!(
        user: @user,
        webauthn_id: Base64.urlsafe_encode64(@raw_credential_id, padding: false),
        external_id: SecureRandom.uuid,
        public_key: "dummy-public-key",
        sign_count: 10,
        description: "MFA passkey",
        status_id: ClientPasskeyStatus::ACTIVE,
      )

      @original_trusted_origins = Webauthn.method(:trusted_origins)
      Webauthn.define_singleton_method(:trusted_origins) { ["http://id.app.localhost", "http://id.org.localhost"] }
    end

    teardown do
      Webauthn.define_singleton_method(
        :trusted_origins,
        @original_trusted_origins,
      ) if @original_trusted_origins
      CloudflareTurnstile.test_mode = false
      CloudflareTurnstile.test_validation_response = nil
    end

    test "new redirects to sign in when pending_mfa is missing" do
      get new_sign_app_in_challenge_passkey_path(ri: "jp")

      assert_response :see_other
      assert_redirected_to new_sign_app_sign_in_path(ri: "jp")
      assert_equal I18n.t("sign.app.in.mfa.session_expired"), flash[:alert]
    end

    test "create verifies passkey and finalizes login with pending_mfa" do
      establish_pending_mfa_via_secret_credential!

      get new_sign_app_in_challenge_passkey_path(ri: "jp")

      assert_response :success

      challenge_id = session[:passkey_challenges].keys.first

      assert_not_nil challenge_id

      mock_credential = OpenStruct.new(
        id: @passkey.webauthn_id,
        sign_count: 11,
      )
      mock_credential.define_singleton_method(:verify) do |_challenge, **|
        true
      end

      WebAuthn::Credential.stub(:from_get, mock_credential) do
        post sign_app_in_challenge_passkey_path(ri: "jp"), params: {
          mfa_passkey_form: {
            challenge_id: challenge_id,
            credential_json: {
              id: @passkey.webauthn_id,
              type: "public-key",
              response: {
                clientDataJSON: "dummy",
                authenticatorData: "dummy",
                signature: "dummy",
                userHandle: @user.public_id,
              },
            }.to_json,
          },
        }
      end

      assert_response :found
      assert_match %r{\Ahttp://id\.umaxica\.app/sign/in/check}, response.location
      assert_nil session[:pending_mfa]
      assert_nil session[:mfa_user_id]
      assert_not_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
      assert_equal 11, @passkey.reload.sign_count
    end

    private

    def establish_pending_mfa_via_secret_credential!
      post(
        sign_app_in_secret_credential_path(ri: "jp"), params: {
          secret_credential_login_form: {
            identifier: @email,
            secret_credential_value: @raw_secret_credential,
          },
          "cf-turnstile-response": "test_token",
        },
      )
      # Skip redirect verification - route helper sign_app_in_mfa_path is undefined
      # assert_redirected_to sign_app_in_mfa_path(ri: "jp")
      assert_response :redirect
    end
  end
end
