# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "base64"
require "ostruct"

class Auth::Org::Sign::In::Challenge::PasskeysControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses, :operator_passkey_statuses, :operator_passkeys, :operator_secret_credentials,
           :operator_secret_credential_kinds, :operator_secret_credential_statuses, :operator_email_statuses,
           :operator_token_binding_methods, :operator_token_kinds, :operator_token_statuses,
           :operator_token_dbsc_statuses

  setup do
    host = ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")
    host! host
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }

    @staff = operators(:one)
    @staff.update!(status_id: OperatorStatus::ACTIVE, mfa_level_enabled: true)
    @staff.staff_secret_credentials.destroy_all

    @passkey = OperatorPasskey.create!(
      staff: @staff,
      webauthn_id: Base64.urlsafe_encode64("mfa_passkey_org_st12", padding: false),
      external_id: SecureRandom.uuid,
      public_key: "mfa-passkey-public",
      sign_count: 5,
      description: "MFA Passkey",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )

    _secret_credential, @raw_secret_credential = OperatorSecretCredential.issue!(
      name: "MFA Secret",
      staff_id: @staff.id,
      staff_secret_kind_id: OperatorSecretCredentialKind::LOGIN,
      uses: 10,
      status: :active,
    )

    unless @staff.operator_emails.exists?
      OperatorEmail.create!(
        staff: @staff,
        address: "mfa_org_test_#{@staff.id}@example.com",
        staff_email_status_id: OperatorEmailStatus::VERIFIED,
      )
    end
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  test "new requires pending MFA session" do
    get new_auth_org_sign_in_challenge_passkey_path(ri: "jp")

    assert_redirected_to auth_org_sign_in_path(ri: "jp")
  end

  test "new redirects when no passkeys available" do
    establish_pending_mfa!
    @staff.operator_passkeys.update_all(status_id: OperatorPasskeyStatus::REVOKED)

    get new_auth_org_sign_in_challenge_passkey_path(ri: "jp")

    assert_redirected_to auth_org_sign_in_challenge_path(ri: "jp")
  end

  test "new renders page with challenge when MFA pending" do
    establish_pending_mfa!

    get new_auth_org_sign_in_challenge_passkey_path(ri: "jp")

    assert_response :success
    assert_not_nil session[:passkey_challenges]
    assert_not_nil session[:passkey_challenges].keys.first
  end

  test "new binds challenge to the configured org relying party" do
    establish_pending_mfa!
    get(new_auth_org_sign_in_challenge_passkey_path(ri: "jp"))

    assert_response :success
    challenge = session[:passkey_challenges].values.first

    assert_equal "org:#{@staff.id}", challenge["actor_global_key"]
    assert_predicate challenge["rp_id"], :present?
    assert_predicate challenge["origin"], :present?
  end

  test "create requires cloudflare turnstile validation" do
    establish_pending_mfa!
    CloudflareTurnstile.test_validation_response = { "success" => false }

    get new_auth_org_sign_in_challenge_passkey_path(ri: "jp")
    session[:passkey_challenges] = { "test-id" => { "challenge" => "test", "purpose" => "authentication" } }

    post auth_org_sign_in_challenge_passkey_path(ri: "jp"), params: {
      mfa_passkey_form: {
        challenge_id: "test-id",
        credential_json: { id: @passkey.webauthn_id, rawId: "test" }.to_json,
      },
    }

    assert_redirected_to new_auth_org_sign_in_challenge_passkey_path(ri: "jp")
  end

  test "create redirects on invalid challenge" do
    establish_pending_mfa!

    post auth_org_sign_in_challenge_passkey_path(ri: "jp"), params: {
      mfa_passkey_form: {
        challenge_id: "invalid_challenge_id",
        credential_json: { id: @passkey.webauthn_id }.to_json,
      },
    }

    assert_redirected_to auth_org_sign_in_challenge_path(ri: "jp")
  end

  test "create verifies passkey and redirects on success" do
    establish_pending_mfa!

    get new_auth_org_sign_in_challenge_passkey_path(ri: "jp")
    challenge_id = session[:passkey_challenges].keys.first

    verification_context = Struct.new(:sign_count).new(6)

    Webauthn::AssertionVerifier.stub(:verify!, verification_context) do
      post auth_org_sign_in_challenge_passkey_path(ri: "jp"),
           headers: { "X-TEST-BULLETIN" => bulletin_json(issued_at: Time.current.to_i, state: "new") },
           params: {
             mfa_passkey_form: {
               challenge_id: challenge_id,
               credential_json: {
                 id: @passkey.webauthn_id,
                 type: "public-key",
                 response: {
                   clientDataJSON: "dummy",
                   authenticatorData: "dummy",
                   signature: "dummy",
                   userHandle: @staff.public_id,
                 },
               }.to_json,
             },
           }
    end

    assert_response :redirect
    assert_nil session[:pending_mfa]
    assert_equal 6, @passkey.reload.sign_count
    assert_not_nil @passkey.reload.last_used_at
  end

  test "create redirects when passkey credential mismatch" do
    establish_pending_mfa!

    get new_auth_org_sign_in_challenge_passkey_path(ri: "jp")
    challenge_id = session[:passkey_challenges].keys.first

    post auth_org_sign_in_challenge_passkey_path(ri: "jp"), params: {
      mfa_passkey_form: {
        challenge_id: challenge_id,
        credential_json: {
          id: Base64.urlsafe_encode64("wrong_credential", padding: false),
          type: "public-key",
          response: {},
        }.to_json,
      },
    }

    assert_redirected_to auth_org_sign_in_challenge_path(ri: "jp")
  end

  test "create handles sign count verification error" do
    establish_pending_mfa!

    get new_auth_org_sign_in_challenge_passkey_path(ri: "jp")
    challenge_id = session[:passkey_challenges].keys.first

    Webauthn::AssertionVerifier.stub(
      :verify!, ->(**) { raise WebAuthn::SignCountVerificationError, "Sign count mismatch" },
    ) do
      post auth_org_sign_in_challenge_passkey_path(ri: "jp"), params: {
        mfa_passkey_form: {
          challenge_id: challenge_id,
          credential_json: {
            id: @passkey.webauthn_id,
            type: "public-key",
            response: {},
          }.to_json,
        },
      }
    end

    assert_redirected_to auth_org_sign_in_challenge_path(ri: "jp")
  end

  test "create handles generic WebAuthn error" do
    establish_pending_mfa!

    get new_auth_org_sign_in_challenge_passkey_path(ri: "jp")
    challenge_id = session[:passkey_challenges].keys.first

    Webauthn::AssertionVerifier.stub(
      :verify!, ->(**) { raise WebAuthn::Error, "Generic verification error" },
    ) do
      post auth_org_sign_in_challenge_passkey_path(ri: "jp"), params: {
        mfa_passkey_form: {
          challenge_id: challenge_id,
          credential_json: {
            id: @passkey.webauthn_id,
            type: "public-key",
            response: {},
          }.to_json,
        },
      }
    end

    assert_redirected_to auth_org_sign_in_challenge_path(ri: "jp")
  end

  test "create handles challenge not found error" do
    establish_pending_mfa!

    get new_auth_org_sign_in_challenge_passkey_path(ri: "jp")

    # Clear challenge from session to simulate expired challenge
    session.delete(:passkey_challenges)

    post auth_org_sign_in_challenge_passkey_path(ri: "jp"), params: {
      mfa_passkey_form: {
        challenge_id: "old-challenge-id",
        credential_json: { id: @passkey.webauthn_id }.to_json,
      },
    }

    assert_redirected_to auth_org_sign_in_challenge_path(ri: "jp")
  end

  test "complete_mfa_login! handles session limit hard reject" do
    establish_pending_mfa!

    get new_auth_org_sign_in_challenge_passkey_path(ri: "jp")
    challenge_id = session[:passkey_challenges].keys.first

    verification_context = Struct.new(:sign_count).new(6)

    Webauthn::AssertionVerifier.stub(:verify!, verification_context) do
      post auth_org_sign_in_challenge_passkey_path(ri: "jp"),
           headers: { "X-TEST-BULLETIN" => bulletin_json(issued_at: Time.current.to_i, state: "new") },
           params: {
             mfa_passkey_form: {
               challenge_id: challenge_id,
               credential_json: {
                 id: @passkey.webauthn_id,
                 type: "public-key",
                 response: {
                   clientDataJSON: "dummy",
                   authenticatorData: "dummy",
                   signature: "dummy",
                 },
               }.to_json,
             },
           }
    end

    assert_response :redirect
  end

  test "complete_mfa_login! handles restricted session" do
    establish_pending_mfa!

    get new_auth_org_sign_in_challenge_passkey_path(ri: "jp")
    challenge_id = session[:passkey_challenges].keys.first

    verification_context = Struct.new(:sign_count).new(6)

    Webauthn::AssertionVerifier.stub(:verify!, verification_context) do
      post auth_org_sign_in_challenge_passkey_path(ri: "jp"),
           headers: { "X-TEST-BULLETIN" => bulletin_json(issued_at: Time.current.to_i, state: "new") },
           params: {
             mfa_passkey_form: {
               challenge_id: challenge_id,
               credential_json: {
                 id: @passkey.webauthn_id,
                 type: "public-key",
                 response: {
                   clientDataJSON: "dummy",
                   authenticatorData: "dummy",
                   signature: "dummy",
                 },
               }.to_json,
             },
           }
    end

    assert_response :found
  end

  test "complete_mfa_login! handles bulletin issue" do
    establish_pending_mfa!

    get new_auth_org_sign_in_challenge_passkey_path(ri: "jp")
    challenge_id = session[:passkey_challenges].keys.first

    verification_context = Struct.new(:sign_count).new(6)

    Webauthn::AssertionVerifier.stub(:verify!, verification_context) do
      post auth_org_sign_in_challenge_passkey_path(ri: "jp", pt: "/bulletin/path"),
           headers: { "X-TEST-BULLETIN" => bulletin_json(issued_at: Time.current.to_i, state: "new") },
           params: {
             mfa_passkey_form: {
               challenge_id: challenge_id,
               credential_json: {
                 id: @passkey.webauthn_id,
                 type: "public-key",
                 response: {
                   clientDataJSON: "dummy",
                   authenticatorData: "dummy",
                   signature: "dummy",
                 },
               }.to_json,
             },
           }
    end

    assert_response :redirect
  end

  private

  def establish_pending_mfa!
    post(
      auth_org_sign_in_secret_credential_url(ri: "jp"), params: {
        secret_credential_login_form: {
          identifier: @staff.public_id.downcase,
          secret_credential_value: @raw_secret_credential,
        },
        "cf-turnstile-response": "test_token",
      },
    )

    assert_response :redirect
    assert_not_nil session[:pending_mfa]
    assert_not_nil session[:mfa_user_id]
  end

  def bulletin_json(issued_at:, state:)
    { "issued_at" => issued_at, "kind" => "mock", "state" => state }.to_json
  end

  def create_rotated_active_staff_session(staff, rotations:)
    token = OperatorToken.create!(staff: staff, staff_token_status_id: OperatorTokenStatus::ACTIVE)
    refresh = token.rotate_refresh_token!

    rotations.times do
      refresh = SignRefreshTokenIssuer.call(refresh_token: refresh)[:refresh_token]
    end
  end
end
