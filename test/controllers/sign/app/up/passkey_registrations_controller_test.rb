# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

module Sign::App::Up
  class PasskeyRegistrationsControllerTest < ActionDispatch::IntegrationTest
    fixtures :app_preference_chronicle_levels, :app_preference_chronicle_events,
             :user_statuses, :user_telephone_statuses, :user_passkey_statuses,
             :user_chronicle_events, :user_chronicle_levels

    setup do
      host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")

      CloudflareTurnstile.test_mode = true
      CloudflareTurnstile.test_validation_response = { "success" => true }

      if defined?(AwsSmsService)
        @original_aws_sms_service_send_message = AwsSmsService.method(:send_message)
        AwsSmsService.singleton_class.send(:define_method, :send_message) do |**_kwargs|
          true
        end
      end

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

      if defined?(AwsSmsService) && @original_aws_sms_service_send_message
        original = @original_aws_sms_service_send_message
        AwsSmsService.singleton_class.send(:define_method, :send_message) do |**kwargs|
          original.call(**kwargs)
        end
      end

      Webauthn.define_singleton_method(:trusted_origins, @original_trusted_origins)
    end

    test "GET show returns 200 with passkey endpoint data attrs" do
      telephone = verify_telephone_via_otp!

      get sign_app_up_telephone_passkey_registration_url(telephone, ri: "jp")

      assert_response :success
      assert_select "[data-controller='passkey-registration']"
      begin_path = begin_sign_app_up_telephone_passkey_registration_path(telephone, ri: "jp")

      assert_select "[data-passkey-registration-begin-url-value='#{begin_path}']"
      finish_path = sign_app_up_telephone_passkey_registration_path(telephone, ri: "jp")

      assert_select "[data-passkey-registration-finish-url-value='#{finish_path}']"
      assert_select "[data-passkey-registration-success-redirect-url-value='#{sign_app_in_bulletin_path(
        ri: "jp",
      )}']"
    end

    test "POST begin returns challenge and options" do
      telephone = verify_telephone_via_otp!

      post begin_sign_app_up_telephone_passkey_registration_url(telephone, ri: "jp")

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

    test "POST create saves passkey and returns completion redirect on success" do
      telephone = verify_telephone_via_otp!

      post begin_sign_app_up_telephone_passkey_registration_url(telephone, ri: "jp")
      challenge_id = response.parsed_body["challenge_id"]

      mock_credential = Object.new
      mock_credential.define_singleton_method(:id) { "new_webauthn_id" }
      mock_credential.define_singleton_method(:public_key) { "new_public_key" }
      mock_credential.define_singleton_method(:sign_count) { 1 }
      mock_credential.define_singleton_method(:verify) { |_challenge| true }

      WebAuthn::Credential.stub(:from_create, mock_credential) do
        assert_difference("UserPasskey.count", 1) do
          post sign_app_up_telephone_passkey_registration_url(telephone, ri: "jp"), params: {
            challenge_id: challenge_id,
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
      assert_equal sign_app_configuration_path(ri: "jp"), response.parsed_body["redirect_url"]
      assert_nil session[:user_telephone_registration]
      assert_equal UserStatus::VERIFIED_WITH_SIGN_UP, telephone.user.reload.status_id
    end

    test "POST create establishes login session for configuration access" do
      telephone = verify_telephone_via_otp!

      post begin_sign_app_up_telephone_passkey_registration_url(telephone, ri: "jp")
      challenge_id = response.parsed_body["challenge_id"]

      mock_credential = Object.new
      mock_credential.define_singleton_method(:id) { "login_webauthn_id" }
      mock_credential.define_singleton_method(:public_key) { "login_public_key" }
      mock_credential.define_singleton_method(:sign_count) { 1 }
      mock_credential.define_singleton_method(:verify) { |_challenge| true }

      WebAuthn::Credential.stub(:from_create, mock_credential) do
        post sign_app_up_telephone_passkey_registration_url(telephone, ri: "jp"), params: {
          challenge_id: challenge_id,
          credential: {
            id: "login_webauthn_id",
            response: { clientDataJSON: "e30=", attestationObject: "e30=" },
          },
          description: "Login Passkey",
        }
      end

      assert_response :created

      get sign_app_configuration_url(ri: "jp")

      assert_response :success
    end

    test "POST create respects rt parameter for redirect" do
      telephone = verify_telephone_via_otp!

      post begin_sign_app_up_telephone_passkey_registration_url(telephone, ri: "jp")
      challenge_id = response.parsed_body["challenge_id"]

      mock_credential = Object.new
      mock_credential.define_singleton_method(:id) { "rt_webauthn_id" }
      mock_credential.define_singleton_method(:public_key) { "rt_public_key" }
      mock_credential.define_singleton_method(:sign_count) { 1 }
      mock_credential.define_singleton_method(:verify) { |_challenge| true }

      rt = "/welcome?ri=jp"

      WebAuthn::Credential.stub(:from_create, mock_credential) do
        post sign_app_up_telephone_passkey_registration_url(telephone, ri: "jp"), params: {
          rt: rt,
          challenge_id: challenge_id,
          credential: {
            id: "rt_webauthn_id",
            response: { clientDataJSON: "e30=", attestationObject: "e30=" },
          },
          description: "RT Passkey",
        }
      end

      assert_response :created
      assert_equal sign_app_configuration_path(ri: "jp"),
                   response.parsed_body["redirect_url"]
    end

    test "POST create creates audit record on success" do
      telephone = verify_telephone_via_otp!

      post begin_sign_app_up_telephone_passkey_registration_url(telephone, ri: "jp")
      challenge_id = response.parsed_body["challenge_id"]

      mock_credential = Object.new
      mock_credential.define_singleton_method(:id) { "audit_webauthn_id" }
      mock_credential.define_singleton_method(:public_key) { "audit_public_key" }
      mock_credential.define_singleton_method(:sign_count) { 1 }
      mock_credential.define_singleton_method(:verify) { |_challenge| true }

      WebAuthn::Credential.stub(:from_create, mock_credential) do
        assert_difference("UserChronicle.count", 1) do
          post sign_app_up_telephone_passkey_registration_url(telephone, ri: "jp"), params: {
            challenge_id: challenge_id,
            credential: {
              id: "audit_webauthn_id",
              response: { clientDataJSON: "e30=", attestationObject: "e30=" },
            },
            description: "Audit Passkey",
          }
        end
      end

      audit = UserChronicle.last

      assert_equal UserChronicleEvent::SIGNED_UP_WITH_TELEPHONE, audit.event_id
      assert_equal telephone.user.id, audit.actor_id
    end

    test "POST create returns unprocessable on verifier error" do
      telephone = verify_telephone_via_otp!

      post begin_sign_app_up_telephone_passkey_registration_url(telephone, ri: "jp")
      challenge_id = response.parsed_body["challenge_id"]

      mock_credential = Object.new
      mock_credential.define_singleton_method(:verify) do |_challenge|
        raise WebAuthn::Error, "verification failed"
      end

      WebAuthn::Credential.stub(:from_create, mock_credential) do
        assert_no_difference("UserPasskey.count") do
          post sign_app_up_telephone_passkey_registration_url(telephone, ri: "jp"), params: {
            challenge_id: challenge_id,
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

    private

    def verify_telephone_via_otp!
      post(
        sign_app_up_telephones_url(ri: "jp"), params: {
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
        sign_app_up_telephone_url(telephone, ri: "jp"), params: {
          user_telephone: { pass_code: code },
        },
      )

      assert_redirected_to sign_app_up_telephone_passkey_registration_url(telephone, ri: "jp")
      telephone.reload
    end

    def registration_telephone
      registration_session = session[:user_telephone_registration] || {}
      public_id = registration_session[:public_id] || registration_session["public_id"]
      UserTelephone.find_by!(public_id: public_id)
    end
  end
end
