# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

# Integration tests for Org verification flow
#
# These tests verify:
# - Org staff verification flow works similarly to App
# - Email OTP is NOT available for Org (passkey only)
# - High-risk operations require verification
class OrgVerificationFlowTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses, :operator_passkeys, :operator_passkey_statuses

  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @staff = operators(:one)
    @token = OperatorToken.create!(
      staff: @staff,
      staff_token_status_id: OperatorTokenStatus::NOTHING,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
      public_id: "ovf#{SecureRandom.hex(4)}",
      discarded_at: 1.day.from_now,
    )
    @token.update!(last_step_up_at: Time.current, last_step_up_scope: "settings_passkey")
    @headers = as_staff_headers(@staff, host: @host)
    @headers["X-TEST-SESSION-PUBLIC-ID"] = @token.public_id
  end

  test "org verification show page does not display email option" do
    # Create passkey for staff to ensure link is rendered
    OperatorPasskey.create!(
      staff: @staff,
      webauthn_id: "test_webauthn_id",
      public_key: "test_public_key",
      sign_count: 0,
    )

    StepUpAvailableMethods.stub(:call, [:passkey]) do
      get auth_org_verification_url(ri: "jp"), headers: @headers

      assert_response :success

      assert response.body.include?("/verification/passkey/new") || response.body.include?("passkey")

      # Should NOT have email link (no emails route for org)
      assert_select "a[href*='email']", count: 0
      assert_select "a[href*='verification/totp']", count: 0
    end
  end

  test "org can verify with passkey" do
    return_to = Base64.urlsafe_encode64(sign_org_settings_passkeys_path(ri: "jp"))

    StepUpAvailableMethods.stub(:call, [:passkey]) do
      WebAuthn::Credential.stub(:options_for_get, OpenStruct.new(id: "test")) do
        WebAuthn::Credential.stub(:from_get, passkey_credential_stub("webauthn_id_1")) do
          get auth_org_verification_url(scope: "settings_passkey", return_to: return_to, ri: "jp"),
              headers: @headers
          get new_sign_org_verification_passkey_url(ri: "jp"), headers: @headers

          post sign_org_verification_passkey_url(ri: "jp"),
               params: { verification: { challenge_id: "test", credential_json: '{"id":"webauthn_id_1"}' } },
               headers: @headers

          assert_response :redirect
          assert_redirected_to sign_org_settings_url(ri: "jp")
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
