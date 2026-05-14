# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class Sign::Org::Verification::PasskeysControllerTest < ActionDispatch::IntegrationTest
  fixtures :staffs, :staff_tokens

  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @staff = staffs(:one)
    @headers = as_staff_headers(@staff, host: @host)
    @token = staff_tokens(:one)
    @headers["X-TEST-SESSION-PUBLIC-ID"] = @token.public_id
  end

  test "creates verification on success" do
    return_to = Base64.urlsafe_encode64(sign_org_configuration_passkeys_path(ri: "jp"))

    StepUp::AvailableMethods.stub(:call, [:passkey]) do
      WebAuthn::Credential.stub(:options_for_get, OpenStruct.new(id: "test")) do
        WebAuthn::Credential.stub(:from_get, passkey_credential_stub("webauthn_id_1")) do
          get sign_org_verification_url(scope: "configuration_passkey", return_to: return_to, ri: "jp"),
              headers: @headers

          assert_response :success

          get new_sign_org_verification_passkey_url(ri: "jp"), headers: @headers

          assert_response :success

          post sign_org_verification_passkey_url(ri: "jp"),
               params: { verification: { challenge_id: "test", credential_json: '{"id":"webauthn_id_1"}' } },
               headers: @headers

          assert_response :redirect
          assert_redirected_to sign_org_configuration_passkeys_url(ri: "jp")

          @token.reload

          assert_not_nil @token.last_step_up_at
          assert_equal "configuration_passkey", @token.last_step_up_scope
          assert_nil @token.reauth_session
          assert_nil session[:reauth]
        end
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
