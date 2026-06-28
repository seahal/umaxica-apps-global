# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class Auth::Org::Verification::PasskeysControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_tokens

  setup do
    @host = ENV.fetch("AUTH_STAFF_URL")
    @staff = operators(:one)
    @token = operator_tokens(:one)
    trusted_origin_host = @host
    @headers = {
      "Host" => @host,
      "X-TEST-CURRENT-STAFF" => @staff.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }
    @original_trusted_origins = Webauthn.method(:trusted_origins)
    Webauthn.define_singleton_method(:trusted_origins) { ["http://auth.org.localhost", "http://#{trusted_origin_host}"] }
  end

  teardown do
    Webauthn.define_singleton_method(:trusted_origins, &@original_trusted_origins.to_proc) if @original_trusted_origins
  end

  test "creates verification on success" do
    return_to = auth_org_settings_passkeys_path(ri: "jp")
    pt = signed_step_up_pt(return_to)
    grant = signed_step_up_grant_for(
      actor: @staff, token: @token, scope: "settings_passkey", return_to: return_to, surface: "org",
    )

    StepUpAvailableMethods.stub(:call, [:passkey]) do
      WebAuthn::Credential.stub(:options_for_get, OpenStruct.new(id: "test")) do
        WebAuthn::Credential.stub(:from_get, passkey_credential_stub("webauthn_id_1")) do
          get auth_org_verification_url(scope: "settings_passkey", pt: pt, ri: "jp", step_up_ceremony_grant: grant),
              headers: @headers

          assert_response :success

          get new_auth_org_verification_passkey_url(ri: "jp"), headers: @headers

          assert_response :success

          post auth_org_verification_passkey_url(ri: "jp"),
               params: { verification: { challenge_id: "test", credential_json: '{"id":"webauthn_id_1"}' } },
               headers: @headers

          assert_response :success
          assert_includes response.body, "step-up-completion-form"

          @token.reload

          # sign no longer writes freshness; acme commits it on completion (asserted below).
          assert_nil @token.step_up_session
          assert_nil session[:step_up]

          submit_step_up_completion_if_present!(
            host: ENV.fetch("BASE_STAFF_URL"),
            headers: as_staff_headers(
              @staff,
              host: ENV.fetch("BASE_STAFF_URL"),
              session_public_id: @token.public_id,
            ),
          )

          assert_response :redirect
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
      include ::RedirectsSignedTargetSupport

      def issue(return_to:, surface:, session_nonce:)
        path = signed_target_internal_path(return_to)
        claims = signed_target_claims(flow: "step_up.bootstrap", surface: surface, session_nonce: session_nonce)
        issue_signed_target_token(
          payload: claims.merge("pt" => path),
          purpose: VerificationBase::STEP_UP_PATH_TARGET_TOKEN_PURPOSE,
          salt: VerificationBase::STEP_UP_PATH_TARGET_TOKEN_SALT,
          expires_in: VerificationBase::STEP_UP_TTL,
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
