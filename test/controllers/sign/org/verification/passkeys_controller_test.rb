# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class Sign::Org::Verification::PasskeysControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_tokens

  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @staff = operators(:one)
    @headers = as_staff_headers(@staff, host: @host)
    @token = OperatorToken.find_by!(public_id: @headers.fetch("X-TEST-SESSION-PUBLIC-ID"))
  end

  test "creates verification on success" do
    pt = signed_step_up_pt(sign_org_settings_passkeys_path(ri: "jp"))

    StepUp::AvailableMethods.stub(:call, [:passkey]) do
      WebAuthn::Credential.stub(:options_for_get, OpenStruct.new(id: "test")) do
        WebAuthn::Credential.stub(:from_get, passkey_credential_stub("webauthn_id_1")) do
          get sign_org_verification_url(scope: "settings_passkey", pt: pt, ri: "jp"),
              headers: @headers

          assert_response :success

          get new_sign_org_verification_passkey_url(ri: "jp"), headers: @headers

          assert_response :success

          post sign_org_verification_passkey_url(ri: "jp"),
               params: { verification: { challenge_id: "test", credential_json: '{"id":"webauthn_id_1"}' } },
               headers: @headers

          assert_response :success
          assert_includes response.body, "step-up-completion-form"

          @token.reload

          assert_nil @token.last_step_up_at
          assert_nil @token.last_step_up_scope
          assert_nil @token.step_up_session
          assert_nil session[:step_up]

          submit_step_up_completion_if_present!(
            host: ENV.fetch("ACME_STAFF_URL", "www.org.localhost"),
            headers: as_staff_headers(
              @staff,
              host: ENV.fetch("ACME_STAFF_URL", "www.org.localhost"),
              session_public_id: @token.public_id,
            ),
          )

          assert_response :redirect
          assert_not_nil @token.reload.last_step_up_at
          assert_equal "settings_passkey", @token.last_step_up_scope
        end
      end
    end
  end

  private

  def signed_step_up_pt(return_to)
    step_up_pt_issuer.issue(return_to: return_to, surface: "org", session_nonce: @token.public_id)
  end

  def step_up_pt_issuer
    @step_up_pt_issuer ||= Class.new do
      include ::Redirects::SignedTargetSupport

      def issue(return_to:, surface:, session_nonce:)
        path = signed_target_internal_path(return_to)
        claims = signed_target_claims(flow: "step_up.bootstrap", surface: surface, session_nonce: session_nonce)
        issue_signed_target_token(
          payload: claims.merge("pt" => path),
          purpose: Verification::Base::STEP_UP_PATH_TARGET_TOKEN_PURPOSE,
          salt: Verification::Base::STEP_UP_PATH_TARGET_TOKEN_SALT,
          expires_in: Verification::Base::STEP_UP_TTL,
        )
      end
    end.new
  end

  def passkey_credential_stub(id)
    Struct.new(:id, :sign_count) do
      define_method(:verify) do |*|
        true
      end
    end.new(id, 1)
  end
end
