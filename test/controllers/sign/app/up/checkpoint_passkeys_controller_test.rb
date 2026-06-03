# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

module Sign::App::Up
  class CheckpointPasskeysControllerTest < ActionDispatch::IntegrationTest
    fixtures :app_preference_chronicle_levels, :app_preference_chronicle_events,
             :client_statuses, :client_telephone_statuses, :client_passkey_statuses,
             :client_chronicle_events, :client_chronicle_levels

    setup do
      host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")

      CloudflareTurnstile.test_mode = true
      CloudflareTurnstile.test_validation_response = { "success" => true }

      @original_trusted_origins = Webauthn.method(:trusted_origins)
      allowed_origins = [
        "http://id.app.localhost",
        "http://id.org.localhost",
        "http://www.example.com",
        "http://#{ENV.fetch("ID_SERVICE_URL", "id.umaxica.app")}",
        "https://#{ENV.fetch("ID_SERVICE_URL", "id.umaxica.app")}",
      ].uniq
      Webauthn.define_singleton_method(:trusted_origins) { allowed_origins }
    end

    teardown do
      CloudflareTurnstile.test_mode = false
      CloudflareTurnstile.test_validation_response = nil

      Webauthn.define_singleton_method(:trusted_origins, @original_trusted_origins)
    end

    test "GET show returns 200 with passkey endpoint data attrs" do
      telephone = verify_telephone_via_otp!
      cycle = current_sign_up_flow(telephone)

      get new_sign_app_up_checkpoint_passkey_url(ri: "jp")

      assert_response :success
      assert_select "[data-controller='passkey-registration']"
      begin_path = begin_sign_app_up_checkpoint_passkey_path(ri: "jp")

      assert_select "[data-passkey-registration-begin-url-value='#{begin_path}']"
      finish_path = sign_app_up_checkpoint_passkey_path(ri: "jp")

      assert_select "[data-passkey-registration-finish-url-value='#{finish_path}']"
      assert_select "[data-passkey-registration-success-redirect-url-value='#{sign_app_up_checkpoint_path(
        ri: "jp",
      )}']"
      assert_select "[data-passkey-registration-checkpoint-version-value='#{cycle.checkpoint_version}']"
    end

    test "POST begin returns challenge and options" do
      verify_telephone_via_otp!

      post begin_sign_app_up_checkpoint_passkey_url(ri: "jp")

      assert_response :ok
      json = response.parsed_body

      assert_predicate json["challenge_id"], :present?
      assert_kind_of Hash, json["options"]
      assert_predicate json.dig("options", "challenge"), :present?
      assert_predicate json.dig("options", "user", "id"), :present?

      challenge = session[:passkey_challenges][json["challenge_id"]]

      assert_predicate challenge, :present?
      assert_equal "registration", challenge["purpose"]
    end

    test "POST begin excludes existing passkey credentials" do
      telephone = verify_telephone_via_otp!
      telephone.user.client_passkeys.create!(
        webauthn_id: "existing_webauthn_id",
        public_key: "existing_public_key",
        sign_count: 0,
      )

      post begin_sign_app_up_checkpoint_passkey_url(ri: "jp")

      assert_response :ok
      excluded_ids = response.parsed_body.dig("options", "excludeCredentials").to_a.pluck("id")

      assert_includes excluded_ids, "existing_webauthn_id"
    end

    test "POST begin returns not found when registration session is missing" do
      post begin_sign_app_up_checkpoint_passkey_url, as: :json

      assert_response :not_found
    end

    test "GET show returns not found when registration session is missing" do
      get new_sign_app_up_checkpoint_passkey_url(ri: "jp")

      assert_response :not_found
    end

    test "POST begin rejects unverified telephone registration" do
      telephone = verify_telephone_via_otp!
      telephone.update!(user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED)

      post begin_sign_app_up_checkpoint_passkey_url, as: :json

      assert_response :unprocessable_content
      assert_predicate response.parsed_body["error"], :present?
    end

    test "GET show redirects unverified telephone registration to edit" do
      telephone = verify_telephone_via_otp!
      telephone.update!(user_telephone_status_id: ClientTelephoneStatus::UNVERIFIED)

      get new_sign_app_up_checkpoint_passkey_url(ri: "jp")

      assert_redirected_to edit_sign_app_up_telephone_path(ri: "jp")
    end

    test "POST create saves passkey and returns checkpoint redirect on success" do
      telephone = verify_telephone_via_otp!
      cycle = current_sign_up_flow(telephone)

      post begin_sign_app_up_checkpoint_passkey_url(ri: "jp")
      challenge_id = response.parsed_body["challenge_id"]

      mock_credential = Object.new
      mock_credential.define_singleton_method(:id) { "new_webauthn_id" }
      mock_credential.define_singleton_method(:public_key) { "new_public_key" }
      mock_credential.define_singleton_method(:sign_count) { 1 }
      mock_credential.define_singleton_method(:verify) { |_challenge| true }

      WebAuthn::Credential.stub(:from_create, mock_credential) do
        assert_difference("ClientPasskey.count", 1) do
          post sign_app_up_checkpoint_passkey_url(ri: "jp"), params: {
            challenge_id: challenge_id,
            checkpoint_version: cycle.checkpoint_version,
            credential: {
              id: "new_webauthn_id",
              response: { clientDataJSON: "e30=", attestationObject: "e30=" },
            },
            description: "Signup Passkey",
          }
        end
      end

      assert_response :created
      assert_equal "ok", response.parsed_body["status"]
      assert_equal sign_app_up_checkpoint_path(ri: "jp"), response.parsed_body["redirect_url"]
      assert_predicate session[:user_telephone_registration], :present?
      assert_equal ClientStatus::UNVERIFIED_WITH_SIGN_UP, telephone.user.reload.status_id
      assert cycle.reload.requirement_cleared?(:passkey)
      assert_not cycle.requirement_cleared?(:birthdate)
      assert_not cycle.requirement_cleared?(:passcode)
    end

    test "POST create requires challenge id" do
      verify_telephone_via_otp!
      cycle = current_sign_up_flow(registration_telephone)

      post sign_app_up_checkpoint_passkey_url(ri: "jp"), params: {
        checkpoint_version: cycle.checkpoint_version,
        credential: {
          id: "new_webauthn_id",
          response: { clientDataJSON: "e30=", attestationObject: "e30=" },
        },
      }

      assert_response :bad_request
      assert_predicate response.parsed_body["error"], :present?
    end

    test "POST create does not establish login session before finalization" do
      telephone = verify_telephone_via_otp!
      cycle = current_sign_up_flow(telephone)

      post begin_sign_app_up_checkpoint_passkey_url(ri: "jp")
      challenge_id = response.parsed_body["challenge_id"]

      mock_credential = Object.new
      mock_credential.define_singleton_method(:id) { "login_webauthn_id" }
      mock_credential.define_singleton_method(:public_key) { "login_public_key" }
      mock_credential.define_singleton_method(:sign_count) { 1 }
      mock_credential.define_singleton_method(:verify) { |_challenge| true }

      WebAuthn::Credential.stub(:from_create, mock_credential) do
        post sign_app_up_checkpoint_passkey_url(ri: "jp"), params: {
          challenge_id: challenge_id,
          checkpoint_version: cycle.checkpoint_version,
          credential: {
            id: "login_webauthn_id",
            response: { clientDataJSON: "e30=", attestationObject: "e30=" },
          },
          description: "Login Passkey",
        }
      end

      assert_response :created

      acme_host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
      get acme_app_settings_url(ri: "jp", host: acme_host)

      assert_response :redirect
      assert_not_equal acme_app_settings_url(ri: "jp", host: acme_host), response.location
      assert_equal ClientStatus::UNVERIFIED_WITH_SIGN_UP, telephone.user.reload.status_id
    end

    test "POST create respects pt parameter for redirect" do
      telephone = verify_telephone_via_otp!
      cycle = current_sign_up_flow(telephone)

      post begin_sign_app_up_checkpoint_passkey_url(ri: "jp")
      challenge_id = response.parsed_body["challenge_id"]

      mock_credential = Object.new
      mock_credential.define_singleton_method(:id) { "rt_webauthn_id" }
      mock_credential.define_singleton_method(:public_key) { "rt_public_key" }
      mock_credential.define_singleton_method(:sign_count) { 1 }
      mock_credential.define_singleton_method(:verify) { |_challenge| true }

      pt = "/welcome?ri=jp"

      WebAuthn::Credential.stub(:from_create, mock_credential) do
        post sign_app_up_checkpoint_passkey_url(ri: "jp"), params: {
          pt: pt,
          challenge_id: challenge_id,
          checkpoint_version: cycle.checkpoint_version,
          credential: {
            id: "rt_webauthn_id",
            response: { clientDataJSON: "e30=", attestationObject: "e30=" },
          },
          description: "PT Passkey",
        }
      end

      assert_response :created
      assert_equal sign_app_up_checkpoint_path(ri: "jp"),
                   response.parsed_body["redirect_url"]
    end

    test "POST create does not create signup or login audit before finalization" do
      telephone = verify_telephone_via_otp!
      cycle = current_sign_up_flow(telephone)

      post begin_sign_app_up_checkpoint_passkey_url(ri: "jp")
      challenge_id = response.parsed_body["challenge_id"]

      mock_credential = Object.new
      mock_credential.define_singleton_method(:id) { "audit_webauthn_id" }
      mock_credential.define_singleton_method(:public_key) { "audit_public_key" }
      mock_credential.define_singleton_method(:sign_count) { 1 }
      mock_credential.define_singleton_method(:verify) { |_challenge| true }

      WebAuthn::Credential.stub(:from_create, mock_credential) do
        assert_no_difference("ClientChronicle.count") do
          post sign_app_up_checkpoint_passkey_url(ri: "jp"), params: {
            challenge_id: challenge_id,
            checkpoint_version: cycle.checkpoint_version,
            credential: {
              id: "audit_webauthn_id",
              response: { clientDataJSON: "e30=", attestationObject: "e30=" },
            },
            description: "Audit Passkey",
          }
        end
      end
    end

    test "POST create returns unprocessable on verifier error" do
      telephone = verify_telephone_via_otp!
      cycle = current_sign_up_flow(telephone)

      post begin_sign_app_up_checkpoint_passkey_url(ri: "jp")
      challenge_id = response.parsed_body["challenge_id"]

      mock_credential = Object.new
      mock_credential.define_singleton_method(:verify) do |_challenge|
        raise WebAuthn::Error, "verification failed"
      end

      WebAuthn::Credential.stub(:from_create, mock_credential) do
        assert_no_difference("ClientPasskey.count") do
          post sign_app_up_checkpoint_passkey_url(ri: "jp"), params: {
            challenge_id: challenge_id,
            checkpoint_version: cycle.checkpoint_version,
            credential: {
              id: "new_webauthn_id",
              response: { clientDataJSON: "e30=", attestationObject: "e30=" },
            },
          }
        end
      end

      assert_response :unprocessable_content
      assert_predicate response.parsed_body["error"], :present?
    end

    test "POST create rejects stale checkpoint version before creating passkey" do
      verify_telephone_via_otp!

      post begin_sign_app_up_checkpoint_passkey_url(ri: "jp")
      challenge_id = response.parsed_body["challenge_id"]

      mock_credential = Object.new
      mock_credential.define_singleton_method(:id) { "stale_webauthn_id" }
      mock_credential.define_singleton_method(:public_key) { "stale_public_key" }
      mock_credential.define_singleton_method(:sign_count) { 1 }
      mock_credential.define_singleton_method(:verify) { |_challenge| true }

      WebAuthn::Credential.stub(:from_create, mock_credential) do
        assert_no_difference("ClientPasskey.count") do
          post sign_app_up_checkpoint_passkey_url(ri: "jp"), params: {
            challenge_id: challenge_id,
            checkpoint_version: 999,
            credential: {
              id: "stale_webauthn_id",
              response: { clientDataJSON: "e30=", attestationObject: "e30=" },
            },
            description: "Stale Passkey",
          }
        end
      end

      assert_response :conflict
      assert_equal "stale_checkpoint", response.parsed_body["error"]
    end

    private

    def verify_telephone_via_otp!
      post(
        sign_app_up_telephone_url,
        params: {
          user_telephone: {
            raw_number: "+1234567890",
            confirm_policy: "1",
            confirm_using_mfa: "1",
          },
          "cf-turnstile-response": "test",
        },
      )

      telephone = registration_telephone
      otp_data = telephone.get_otp
      hotp = ROTP::HOTP.new(otp_data[:otp_private_key])
      code = hotp.at(otp_data[:otp_counter])

      patch(
        sign_app_up_telephone_url(ri: "jp"), params: {
          user_telephone: { pass_code: code },
        },
      )

      assert_redirected_to sign_app_up_guardrail_url(ri: "jp")

      get(sign_app_up_guardrail_url(ri: "jp"))

      assert_redirected_to sign_app_up_checkpoint_url(ri: "jp")

      get(sign_app_up_checkpoint_url(ri: "jp"))

      assert_response :success

      telephone.reload
    end

    def current_sign_up_flow(telephone)
      ClientSignUpFlow.order(:id).find_by!(
        principal_id: telephone.user_id,
        pending_contact_type: "telephone",
        pending_contact_id: telephone.id,
      )
    end

    def registration_telephone
      registration_session = session[:user_telephone_registration] || {}
      public_id = registration_session[:public_id] || registration_session["public_id"]
      ClientTelephone.find_by!(public_id: public_id)
    end
  end
end
