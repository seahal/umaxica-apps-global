# typed: false
# frozen_string_literal: true

require "test_helper"
require "minitest/mock"
require "base64"

module Sign::App::In
  class PasskeysControllerTest < ActionDispatch::IntegrationTest
    fixtures :clients, :client_statuses, :client_email_statuses, :client_telephone_statuses

    setup do
      host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
      CloudflareTurnstile.test_mode = true
      CloudflareTurnstile.test_validation_response = { "success" => true }
      JitSecurityTurnstileVerifier.test_mode = true
      JitSecurityTurnstileVerifier.test_response = { "success" => true }
      @user = create_verified_user_with_email(email_address: "passkey_test_user_#{SecureRandom.hex(6)}@example.com")
      @user_email = @user.client_emails.first # Use the email created by the helper

      @user_telephone = ClientTelephone.create!(
        user: @user,
        number: "+819012345678",
        user_telephone_status_id: ClientTelephoneStatus::VERIFIED,
      ) unless ClientTelephone.find_by(user: @user)

      # Setup user passkey for login
      @passkey = ClientPasskey.create!(
        user: @user,
        webauthn_id: Base64.urlsafe_encode64("login_id_bytes_12345", padding: false),
        external_id: SecureRandom.uuid,
        public_key: "login_key",
        description: "Login Key",
        status_id: ClientPasskeyStatus::ACTIVE,
      )

      # Mock TRUSTED_ORIGINS
      @original_trusted_origins = Webauthn.method(:trusted_origins)
      Webauthn.define_singleton_method(:trusted_origins) { ["http://id.app.localhost", "http://id.org.localhost"] }
    end

    teardown do
      if defined?(@original_trusted_origins) && @original_trusted_origins
        Webauthn.define_singleton_method(:trusted_origins, @original_trusted_origins)
      end
      CloudflareTurnstile.test_mode = false
      CloudflareTurnstile.test_validation_response = nil
      JitSecurityTurnstileVerifier.test_mode = false
      JitSecurityTurnstileVerifier.test_response = nil
    end
    test "should get new" do
      get new_sign_app_sign_in_passkey_path(ri: "jp")

      assert_response :success
      assert_select "[data-passkey-authentication-options-url-value=?]", sign_app_sign_in_passkey_options_path(ri: "jp")
      assert_select "[data-passkey-authentication-verification-url-value=?]",
                    sign_app_sign_in_passkey_verification_path(ri: "jp")
      assert_select "a[href=?]", sign_app_sign_in_entrance_path(ri: "jp")
    end

    # Case F-1: Identifier does not exist
    test "options returns error if identifier not found" do
      post sign_app_sign_in_passkey_options_path(ri: "jp"),
           params: options_params(identifier: "unknown@example.com")

      assert_response :unprocessable_content
      assert_includes response.body, I18n.t("errors.webauthn.no_passkeys_available")
    end

    # Case F-2: Identifier exists but no passkey
    test "options returns error if no passkeys" do
      user_no_passkey = clients(:two)
      user_no_passkey_email = ClientEmail.create!(user: user_no_passkey, address: "nopasskey@example.com")

      post sign_app_sign_in_passkey_options_path(ri: "jp"),
           params: options_params(identifier: user_no_passkey_email.address)

      assert_response :unprocessable_content
      assert_includes response.body, I18n.t("errors.webauthn.no_passkeys_available")
    end

    test "options returns challenge and allowCredentials for email identifier" do
      email = ClientEmail.find_by(user: @user).address

      post sign_app_sign_in_passkey_options_path(ri: "jp"), params: options_params(identifier: email)

      assert_response :ok
      json = response.parsed_body

      assert_not_nil json["challenge_id"]
      options = json["options"]

      assert_not_empty options["allowCredentials"]

      Rails.logger.debug { "DEBUG: allowCredentials = #{options["allowCredentials"].inspect}" }
      Rails.logger.debug { "DEBUG: allowCredentials = #{options["allowCredentials"].inspect}" }
      Rails.logger.debug { "DEBUG: passkey_id = #{@passkey.webauthn_id}" }

      # Verify allowCredentials contains our passkey ID
      match = options["allowCredentials"].any? { |c| c["id"] == @passkey.webauthn_id }

      assert match, "Expected allowCredentials to contain #{@passkey.webauthn_id}"

      # Case F-4: Challenge saved with correct purpose
      assert_not_nil session[:passkey_challenges][json["challenge_id"]]
      assert_equal "authentication", session[:passkey_challenges][json["challenge_id"]]["purpose"]
    end

    test "options returns challenge and allowCredentials for telephone identifier" do
      post sign_app_sign_in_passkey_options_path(ri: "jp"),
           params: options_params(identifier: @user_telephone.number)

      assert_response :ok
      json = response.parsed_body

      assert_not_nil json["challenge_id"]
      assert_not_empty json.dig("options", "allowCredentials")
    end

    # Case F-3b: JSON response format validation for authentication options (regression test)
    test "options returns valid Base64URL encoded challenge" do
      email = ClientEmail.find_by(user: @user).address

      post sign_app_sign_in_passkey_options_path(ri: "jp"), params: options_params(identifier: email)

      assert_response :ok
      json = response.parsed_body
      options = json["options"]

      # Verify challenge is Base64URL encoded
      challenge = options["challenge"]

      assert_match(/\A[A-Za-z0-9_-]+\z/, challenge, "challenge should be Base64URL format")
      padding_needed = (4 - (challenge.length % 4)) % 4

      assert_operator padding_needed, :<=, 2,
                      "challenge should have valid Base64URL padding (0-2 chars), but would need #{padding_needed}"

      # Verify no duplicate keys in JSON
      json_string = response.body
      challenge_count = json_string.scan(/"challenge"/).count

      assert_equal 1, challenge_count,
                   "JSON should contain exactly one 'challenge' key (found #{challenge_count})"

      # Verify allowCredentials IDs are properly encoded
      options["allowCredentials"].each_with_index do |credential, index|
        cred_id = credential["id"]

        assert_match(
          /\A[A-Za-z0-9_-]+\z/, cred_id,
          "allowCredentials[#{index}].id should be Base64URL format",
        )
      end
    end

    # Case G-1: Verification success
    test "verification logs user in on success" do
      assert_not_nil @passkey, "Passkey must exist"
      # Get challenge
      email = ClientEmail.find_by(user: @user).address
      post sign_app_sign_in_passkey_options_path(ri: "jp"), params: options_params(identifier: email)
      explanation = response.parsed_body
      challenge_id = explanation["challenge_id"]

      # Mock WebAuthn verification
      mock_credential = Object.new
      passkey_id = @passkey.webauthn_id
      mock_credential.define_singleton_method(:id) { passkey_id }
      mock_credential.define_singleton_method(:sign_count) { 1 }
      mock_credential.define_singleton_method(:verify) { |*_args| true }

      WebAuthn::Credential.stub(:from_get, mock_credential) do
        params = {
          challenge_id: challenge_id,
          credential: {
            id: @passkey.webauthn_id,
            response: { clientDataJSON: "e30=",
                        authenticatorData: "e30=",
                        signature: "sig",
                        userHandle: "h", },
          },
        }

        # Should log in
        post sign_app_sign_in_passkey_verification_path(ri: "jp", pt: "/settings/emails"), params: params

        assert_response :ok
        json = response.parsed_body

        assert_equal "ok", json["status"]
        assert_not_nil json["access_token"]
        assert_equal "Bearer", json["token_type"]
        assert_equal AuthenticationBase::ACCESS_TOKEN_TTL.to_i, json["expires_in"]
        assert_equal sign_app_sign_in_check_path, json["redirect_url"]

        # Challenge verification updates sign count
        assert_equal 1, @passkey.reload.sign_count
      end
    end

    test "verification with session limit exceeded returns session_restricted" do
      # Create 2 active sessions to hit the limit
      ClientToken.where(user_id: @user.id).delete_all
      2.times do
        create_rotated_active_user_session(@user, rotations: 3)
      end

      # Get challenge
      email = ClientEmail.find_by(user: @user).address
      post sign_app_sign_in_passkey_options_path(ri: "jp"), params: options_params(identifier: email)
      explanation = response.parsed_body
      challenge_id = explanation["challenge_id"]

      # Mock WebAuthn verification
      mock_credential = Object.new
      passkey_id = @passkey.webauthn_id
      mock_credential.define_singleton_method(:id) { passkey_id }
      mock_credential.define_singleton_method(:sign_count) { 1 }
      mock_credential.define_singleton_method(:verify) { |*_args| true }

      WebAuthn::Credential.stub(:from_get, mock_credential) do
        params = {
          challenge_id: challenge_id,
          credential: {
            id: @passkey.webauthn_id,
            response: { clientDataJSON: "e30=",
                        authenticatorData: "e30=",
                        signature: "sig",
                        userHandle: "h", },
          },
        }

        post sign_app_sign_in_passkey_verification_path(ri: "jp"), params: params

        assert_response :ok
        json = response.parsed_body

        assert_equal "session_restricted", json["status"]
        assert_equal sign_app_sign_in_session_path(ri: "jp"), json["redirect_url"]
        assert_equal 0, ClientToken.where(user_id: @user.id, user_token_status_id: ClientTokenStatus::RESTRICTED).count
      end
    end

    test "verification returns same response for credential mismatch and missing verified pii" do
      # Baseline: credential mismatch
      post sign_app_sign_in_passkey_options_path(ri: "jp"),
           params: options_params(identifier: @user_email.address)
      baseline_challenge_id = response.parsed_body["challenge_id"]

      post sign_app_sign_in_passkey_verification_path(ri: "jp"), params: {
        challenge_id: baseline_challenge_id,
        credential: {
          id: Base64.urlsafe_encode64("unknown_credential", padding: false),
          response: { clientDataJSON: "e30=", authenticatorData: "e30=", signature: "sig", userHandle: "h" },
        },
      }

      assert_response :unauthorized
      mismatch_body = response.body

      # PII missing user with valid passkey credential
      user_without_verified_pii = Client.create!(status_id: ClientStatus::NOTHING, mfa_level_enabled: false)
      email = user_without_verified_pii.client_emails.create!(
        address: "unverified_passkey_#{SecureRandom.hex(4)}@example.com",
        user_email_status_id: ClientEmailStatus::VERIFIED,
      )
      passkey = ClientPasskey.create!(
        user: user_without_verified_pii,
        webauthn_id: Base64.urlsafe_encode64("pii_missing_login_id_#{SecureRandom.hex(4)}", padding: false),
        external_id: SecureRandom.uuid,
        public_key: "pii_missing_public_key",
        description: "PII missing key",
        status_id: ClientPasskeyStatus::ACTIVE,
      )
      email.update!(user_email_status_id: ClientEmailStatus::UNVERIFIED)

      post sign_app_sign_in_passkey_options_path(ri: "jp"), params: options_params(identifier: email.address)
      pii_challenge_id = response.parsed_body["challenge_id"]

      mock_credential = Object.new
      mock_credential.define_singleton_method(:id) { passkey.webauthn_id }
      mock_credential.define_singleton_method(:sign_count) { 1 }
      mock_credential.define_singleton_method(:verify) { |*_args| true }

      WebAuthn::Credential.stub(:from_get, mock_credential) do
        post sign_app_sign_in_passkey_verification_path(ri: "jp"), params: {
          challenge_id: pii_challenge_id,
          credential: {
            id: passkey.webauthn_id,
            response: { clientDataJSON: "e30=",
                        authenticatorData: "e30=",
                        signature: "sig",
                        userHandle: "h", },
          },
        }
      end

      assert_response :unauthorized
      assert_equal mismatch_body, response.body
    end

    test "verification returns unauthorized when challenge actor and passkey owner mismatch" do
      post sign_app_sign_in_passkey_options_path(ri: "jp"),
           params: options_params(identifier: @user_email.address)
      challenge_id = response.parsed_body["challenge_id"]

      other_user = create_verified_user_with_email(email_address: "passkey_other_#{SecureRandom.hex(4)}@example.com")
      other_passkey = ClientPasskey.create!(
        user: other_user,
        webauthn_id: Base64.urlsafe_encode64("other_user_key_#{SecureRandom.hex(4)}", padding: false),
        external_id: SecureRandom.uuid,
        public_key: "other_user_key",
        description: "Other Client Key",
        status_id: ClientPasskeyStatus::ACTIVE,
      )

      mock_credential = Object.new
      mock_credential.define_singleton_method(:id) { other_passkey.webauthn_id }
      mock_credential.define_singleton_method(:sign_count) { 1 }
      mock_credential.define_singleton_method(:verify) { |*_args| true }

      WebAuthn::Credential.stub(:from_get, mock_credential) do
        post sign_app_sign_in_passkey_verification_path(ri: "jp"), params: {
          challenge_id: challenge_id,
          credential: {
            id: other_passkey.webauthn_id,
            response: { clientDataJSON: "e30=",
                        authenticatorData: "e30=",
                        signature: "sig",
                        userHandle: "h", },
          },
        }
      end

      assert_response :unauthorized
      assert_includes response.body, I18n.t("errors.webauthn.credential_not_found")
    end

    test "verification returns 422 when login result status is unknown" do
      post sign_app_sign_in_passkey_options_path(ri: "jp"),
           params: options_params(identifier: @user_email.address)
      challenge_id = response.parsed_body["challenge_id"]

      passkey_id = @passkey.webauthn_id
      mock_credential = Object.new
      mock_credential.define_singleton_method(:id) { passkey_id }
      mock_credential.define_singleton_method(:sign_count) { 1 }
      mock_credential.define_singleton_method(:verify) { |*_args| true }

      original_method = Sign::App::In::PasskeysController.instance_method(:perform_passkey_sign_in)
      Sign::App::In::PasskeysController.define_method(:perform_passkey_sign_in) { |_passkey| { status: :unknown } }
      begin
        WebAuthn::Credential.stub(:from_get, mock_credential) do
          post(
            sign_app_sign_in_passkey_verification_path(ri: "jp"), params: {
              challenge_id: challenge_id,
              credential: {
                id: @passkey.webauthn_id,
                response: { clientDataJSON: "e30=",
                            authenticatorData: "e30=",
                            signature: "sig",
                            userHandle: "h", },
              },
            },
          )
        end
      ensure
        Sign::App::In::PasskeysController.define_method(:perform_passkey_sign_in, original_method)
      end

      assert_response :unprocessable_content
      assert_includes response.body, I18n.t("errors.login_failed")
    end

    test "verification returns bad request on challenge purpose mismatch" do
      email = ClientEmail.find_by(user: @user).address
      post sign_app_sign_in_passkey_options_path(ri: "jp"), params: options_params(identifier: email)
      challenge_id = response.parsed_body["challenge_id"]
      mismatch_error = SignWebauthn::ChallengePurposeMismatchError.new("purpose mismatch")

      original_method = Sign::App::In::PasskeysController.instance_method(:with_challenge)
      Sign::App::In::PasskeysController.define_method(:with_challenge) do |*_args, &_block|
        raise mismatch_error
      end
      begin
        post(
          sign_app_sign_in_passkey_verification_path(ri: "jp"), params: {
            challenge_id: challenge_id,
            credential: {
              id: @passkey.webauthn_id,
              response: { clientDataJSON: "e30=",
                          authenticatorData: "e30=",
                          signature: "sig",
                          userHandle: "h", },
            },
          },
        )
      ensure
        Sign::App::In::PasskeysController.define_method(:with_challenge, original_method)
      end

      assert_response :bad_request
      assert_includes response.body, I18n.t("errors.webauthn.challenge_invalid")
    end

    test "options returns 403 when user is at session hard_reject limit" do
      # Create 2 active + 1 restricted to hit the hard limit
      ClientToken.where(user_id: @user.id).delete_all
      2.times do
        create_rotated_active_user_session(@user, rotations: 3)
      end
      restricted = ClientToken.create!(user: @user, user_token_status_id: ClientTokenStatus::RESTRICTED)
      restricted.rotate_refresh_token!(discarded_at: 15.minutes.from_now)

      post sign_app_sign_in_passkey_options_path(ri: "jp"),
           params: options_params(identifier: @user_email.address),
           as: :json

      assert_response :forbidden
      json = response.parsed_body

      assert_equal "session_limit_hard_reject", json["error_code"]
    end

    test "options returns turnstile error when response token is missing" do
      CloudflareTurnstile.test_mode = false
      JitSecurityTurnstileVerifier.test_mode = false
      JitSecurityTurnstileVerifier.test_response = nil

      post sign_app_sign_in_passkey_options_path(ri: "jp"), params: { identifier: @user_email.address }

      assert_response :unprocessable_content
      assert_equal I18n.t("turnstile_error"), response.parsed_body["error"]
    end

    private

    def options_params(identifier:)
      {
        identifier: identifier,
        "cf-turnstile-response": "test_token",
      }
    end

    def create_rotated_active_user_session(user, rotations:)
      token = ClientToken.create!(user: user, user_token_status_id: ClientTokenStatus::ACTIVE)
      refresh = token.rotate_refresh_token!

      rotations.times do
        refresh = SignRefreshTokenService.call(refresh_token: refresh)[:refresh_token]
      end
    end
  end
end
