# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"
require "ostruct"

class Sign::Org::In::Challenge::PasskeysControllerTest < ActionDispatch::IntegrationTest
  fixtures :staffs, :staff_statuses, :staff_passkey_statuses, :staff_passkeys, :staff_secrets,
           :staff_secret_kinds, :staff_secret_statuses, :staff_email_statuses

  setup do
    host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    host! host
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }

    @original_trusted_origins = Webauthn.method(:trusted_origins)
    Webauthn.define_singleton_method(:trusted_origins) { ["http://#{host}", "http://id.app.localhost"] }

    @staff = staffs(:one)
    @staff.update!(status_id: StaffStatus::ACTIVE, multi_factor_enabled: true)

    @passkey = StaffPasskey.create!(
      staff: @staff,
      webauthn_id: Base64.urlsafe_encode64("mfa_passkey_org_st12", padding: false),
      external_id: SecureRandom.uuid,
      public_key: "mfa-passkey-public",
      sign_count: 5,
      name: "MFA Passkey",
      status_id: StaffPasskeyStatus::ACTIVE,
    )

    _secret, @raw_secret = StaffSecret.issue!(
      name: "MFA Secret",
      staff_id: @staff.id,
      staff_secret_kind_id: StaffSecretKind::PERMANENT,
      uses: 10,
      status: :active,
    )

    unless @staff.staff_emails.exists?
      StaffEmail.create!(
        staff: @staff,
        address: "mfa_org_test_#{@staff.id}@example.com",
        staff_email_status_id: StaffEmailStatus::VERIFIED,
      )
    end
  end

  teardown do
    Webauthn.define_singleton_method(:trusted_origins, @original_trusted_origins) if @original_trusted_origins
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  test "new requires pending MFA session" do
    get new_sign_org_in_challenge_passkey_path(ri: "jp")

    assert_redirected_to new_sign_org_in_path(ri: "jp")
    assert_equal I18n.t("sign.org.in.mfa.session_expired"), flash[:alert]
  end

  test "new redirects when no passkeys available" do
    establish_pending_mfa!
    @staff.staff_passkeys.update_all(status_id: StaffPasskeyStatus::REVOKED)

    get new_sign_org_in_challenge_passkey_path(ri: "jp")

    assert_redirected_to sign_org_in_challenge_path(ri: "jp")
    assert_equal I18n.t("errors.webauthn.no_passkeys_available"), flash[:alert]
  end

  test "new renders page with challenge when MFA pending" do
    establish_pending_mfa!

    get new_sign_org_in_challenge_passkey_path(ri: "jp")

    assert_response :success
    assert_not_nil session[:passkey_challenges]
    assert_not_nil session[:passkey_challenges].keys.first
  end

  test "new handles origin validation error" do
    Webauthn.define_singleton_method(:trusted_origins) { [] }

    establish_pending_mfa!
    get new_sign_org_in_challenge_passkey_path(ri: "jp")

    assert_redirected_to sign_org_in_challenge_path(ri: "jp")
    assert_predicate flash[:alert], :present?
  end

  test "create requires cloudflare turnstile validation" do
    establish_pending_mfa!
    CloudflareTurnstile.test_validation_response = { "success" => false }

    get new_sign_org_in_challenge_passkey_path(ri: "jp")
    session[:passkey_challenges] = { "test-id" => { "challenge" => "test", "purpose" => "authentication" } }

    post sign_org_in_challenge_passkey_path(ri: "jp"), params: {
      mfa_passkey_form: {
        challenge_id: "test-id",
        credential_json: { id: @passkey.webauthn_id, rawId: "test" }.to_json,
      },
    }

    assert_redirected_to new_sign_org_in_challenge_passkey_path(ri: "jp")
    assert_predicate flash[:alert], :present?
  end

  test "create redirects on invalid challenge" do
    establish_pending_mfa!

    post sign_org_in_challenge_passkey_path(ri: "jp"), params: {
      mfa_passkey_form: {
        challenge_id: "invalid_challenge_id",
        credential_json: { id: @passkey.webauthn_id }.to_json,
      },
    }

    assert_redirected_to sign_org_in_challenge_path(ri: "jp")
    assert_equal I18n.t("errors.webauthn.challenge_invalid"), flash[:alert]
  end

  test "create verifies passkey and redirects on success" do
    establish_pending_mfa!

    get new_sign_org_in_challenge_passkey_path(ri: "jp")
    challenge_id = session[:passkey_challenges].keys.first

    mock_credential = OpenStruct.new(
      id: @passkey.webauthn_id,
      sign_count: 6,
    )
    mock_credential.define_singleton_method(:verify) { |*_args| true }

    WebAuthn::Credential.stub(:from_get, mock_credential) do
      post sign_org_in_challenge_passkey_path(ri: "jp"),
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

    get new_sign_org_in_challenge_passkey_path(ri: "jp")
    challenge_id = session[:passkey_challenges].keys.first

    mock_credential = OpenStruct.new(
      id: Base64.urlsafe_encode64("wrong_credential", padding: false),
      sign_count: 1,
    )
    mock_credential.define_singleton_method(:verify) { |*_args| true }

    WebAuthn::Credential.stub(:from_get, mock_credential) do
      post sign_org_in_challenge_passkey_path(ri: "jp"), params: {
        mfa_passkey_form: {
          challenge_id: challenge_id,
          credential_json: {
            id: Base64.urlsafe_encode64("wrong_credential", padding: false),
            type: "public-key",
            response: {},
          }.to_json,
        },
      }
    end

    assert_redirected_to sign_org_in_challenge_path(ri: "jp")
  end

  test "create handles sign count verification error" do
    establish_pending_mfa!

    get new_sign_org_in_challenge_passkey_path(ri: "jp")
    challenge_id = session[:passkey_challenges].keys.first

    mock_credential = OpenStruct.new(
      id: @passkey.webauthn_id,
      sign_count: 6,
    )
    mock_credential.define_singleton_method(:verify) do |*_args|
      raise WebAuthn::SignCountVerificationError, "Sign count mismatch"
    end

    WebAuthn::Credential.stub(:from_get, mock_credential) do
      post sign_org_in_challenge_passkey_path(ri: "jp"), params: {
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

    assert_redirected_to sign_org_in_challenge_path(ri: "jp")
    assert_equal I18n.t("errors.webauthn.sign_count_mismatch"), flash[:alert]
  end

  test "create handles generic WebAuthn error" do
    establish_pending_mfa!

    get new_sign_org_in_challenge_passkey_path(ri: "jp")
    challenge_id = session[:passkey_challenges].keys.first

    mock_credential = OpenStruct.new(
      id: @passkey.webauthn_id,
      sign_count: 6,
    )
    mock_credential.define_singleton_method(:verify) do |*_args|
      raise WebAuthn::Error, "Generic verification error"
    end

    WebAuthn::Credential.stub(:from_get, mock_credential) do
      post sign_org_in_challenge_passkey_path(ri: "jp"), params: {
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

    assert_redirected_to sign_org_in_challenge_path(ri: "jp")
    assert_equal I18n.t("errors.webauthn.verification_failed"), flash[:alert]
  end

  test "create handles challenge not found error" do
    establish_pending_mfa!

    get new_sign_org_in_challenge_passkey_path(ri: "jp")

    # Clear challenge from session to simulate expired challenge
    session.delete(:passkey_challenges)

    post sign_org_in_challenge_passkey_path(ri: "jp"), params: {
      mfa_passkey_form: {
        challenge_id: "old-challenge-id",
        credential_json: { id: @passkey.webauthn_id }.to_json,
      },
    }

    assert_redirected_to sign_org_in_challenge_path(ri: "jp")
    assert_equal I18n.t("errors.webauthn.challenge_invalid"), flash[:alert]
  end

  test "complete_mfa_login! handles session limit hard reject" do
    establish_pending_mfa!

    get new_sign_org_in_challenge_passkey_path(ri: "jp")
    challenge_id = session[:passkey_challenges].keys.first

    mock_credential = OpenStruct.new(
      id: @passkey.webauthn_id,
      sign_count: 6,
    )
    mock_credential.define_singleton_method(:verify) { |*_args| true }

    WebAuthn::Credential.stub(:from_get, mock_credential) do
      post sign_org_in_challenge_passkey_path(ri: "jp"),
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

    get new_sign_org_in_challenge_passkey_path(ri: "jp")
    challenge_id = session[:passkey_challenges].keys.first

    mock_credential = OpenStruct.new(
      id: @passkey.webauthn_id,
      sign_count: 6,
    )
    mock_credential.define_singleton_method(:verify) { |*_args| true }

    WebAuthn::Credential.stub(:from_get, mock_credential) do
      post sign_org_in_challenge_passkey_path(ri: "jp"),
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

    get new_sign_org_in_challenge_passkey_path(ri: "jp")
    challenge_id = session[:passkey_challenges].keys.first

    mock_credential = OpenStruct.new(
      id: @passkey.webauthn_id,
      sign_count: 6,
    )
    mock_credential.define_singleton_method(:verify) { |*_args| true }

    WebAuthn::Credential.stub(:from_get, mock_credential) do
      post sign_org_in_challenge_passkey_path(ri: "jp", rd: "/bulleting/path"),
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
      sign_org_in_secret_url(ri: "jp"), params: {
        secret_login_form: {
          identifier: @staff.public_id.downcase,
          secret_value: @raw_secret,
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
    token = StaffToken.create!(staff: staff, status: StaffToken::STATUS_ACTIVE)
    refresh = token.rotate_refresh_token!

    rotations.times do
      refresh = Sign::RefreshTokenService.call(refresh_token: refresh)[:refresh_token]
    end
  end
end
