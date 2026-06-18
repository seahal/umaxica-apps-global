# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class Sign::Com::Verification::PasskeysControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    host! @host
    @visitor = create_verified_visitor_with_email(
      email_address: "com-passkey-stepup-#{SecureRandom.hex(4)}@example.com",
    )
    @visitor.visitor_telephones.create!(
      number: "+8190#{SecureRandom.random_number(10 ** 8).to_s.rjust(8, "0")}",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    @headers = as_visitor_headers(@visitor, host: @host)
    @token = VisitorToken.find_by!(public_id: @headers["X-TEST-SESSION-PUBLIC-ID"])
    @visitor.visitor_passkeys.create!(
      description: "Test passkey",
      webauthn_id: "test",
      public_key: "public_key",
      sign_count: 0,
      status_id: VisitorPasskeyStatus::ACTIVE,
    )
  end

  test "creates verification on success" do
    return_to = Base64.urlsafe_encode64(sign_com_settings_emails_path(ri: "jp"))

    StepUpAvailableMethods.stub(:call, [:passkey]) do
      WebAuthn::Credential.stub(:options_for_get, OpenStruct.new(id: "test")) do
        WebAuthn::Credential.stub(:from_get, passkey_credential_stub("test")) do
          get sign_com_verification_url(scope: "settings_email", return_to: return_to, ri: "jp"),
              headers: @headers

          assert_response :success

          get new_sign_com_verification_passkey_url(
                ri: "jp",
                scope: "settings_email",
                return_to: return_to,
              ), headers: @headers

          assert_response :redirect

          post sign_com_verification_passkey_url(ri: "jp"),
               params: { verification: { challenge_id: "test", credential_json: '{"id":"test"}' } },
               headers: @headers

          assert_response :redirect
          assert_redirected_to sign_com_verification_url(ri: "jp")
        end
      end
    end
  end

  test "new keeps scope and return_to in form hidden fields" do
    return_to = Base64.urlsafe_encode64(sign_com_settings_emails_path(ri: "jp"))

    StepUpAvailableMethods.stub(:call, [:passkey]) do
      WebAuthn::Credential.stub(:options_for_get, OpenStruct.new(id: "test")) do
        get sign_com_verification_url(scope: "settings_email", return_to: return_to, ri: "jp"),
            headers: @headers

        assert_response :success

        get new_sign_com_verification_passkey_url(
              ri: "jp",
              scope: "settings_email",
              return_to: return_to,
            ), headers: @headers

        assert_response :redirect
      end
    end
  end

  private

  def passkey_credential_stub(id)
    Struct.new(:id, :sign_count) do
      define_method(:verify) do |*|
        true
      end
    end.new(id, 1)
  end
end
