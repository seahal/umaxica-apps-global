# typed: false
# frozen_string_literal: true

require "test_helper"
require "minitest/mock"
require "base64"

class Sign::Org::In::PasskeysControllerTest < ActionDispatch::IntegrationTest
  fixtures :staffs, :staff_statuses, :staff_passkeys, :staff_passkey_statuses

  setup do
    host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    host! host
    Jit::Security::TurnstileVerifier.test_mode = true
    Jit::Security::TurnstileVerifier.test_response = { "success" => true }
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
    @original_trusted_origins = Webauthn.method(:trusted_origins)
    Webauthn.define_singleton_method(:trusted_origins) { ["http://id.app.localhost", "http://#{host}"] }

    # Setup active staff with email and passkey
    @staff = staffs(:one)
    @staff.update!(status_id: StaffStatus::ACTIVE)
    StaffToken.where(staff_id: @staff.id).delete_all

    @staff_passkey = StaffPasskey.create!(
      staff: @staff,
      webauthn_id: Base64.urlsafe_encode64("staff_login_id_bytes_12345", padding: false),
      external_id: SecureRandom.uuid,
      public_key: "staff_login_key",
      name: "Staff Login Key",
      status_id: StaffPasskeyStatus::ACTIVE,
    )
  end

  teardown do
    Webauthn.define_singleton_method(:trusted_origins, @original_trusted_origins)
    Jit::Security::TurnstileVerifier.test_mode = false
    Jit::Security::TurnstileVerifier.test_response = nil
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  test "should get new" do
    get new_sign_org_in_passkey_url(ri: "jp")

    assert_response :success
    assert_select "label", text: "ID"
    assert_select "input#identifier[required]"
    assert_select "input#identifier[minlength='16']"
    assert_select "input#identifier[maxlength='16']"
    assert_select "input#identifier[pattern='[0-9A-FGHJKMNPQRSTVWXYZ]{16}']"
    assert_select "input#identifier[autocapitalize='characters']"
    assert_select "input#identifier[spellcheck='false']"
  end

  test "options returns error if identifier blank" do
    post options_sign_org_in_passkeys_url(ri: "jp"), params: { identifier: "" }

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("errors.webauthn.identifier_required")
  end

  test "options returns error if identifier not found" do
    post options_sign_org_in_passkeys_url(ri: "jp"), params: { identifier: "unknown@example.com" }

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("errors.webauthn.identifier_invalid")
  end

  test "options returns error if staff has no passkeys" do
    staff_no_passkey = staffs(:two)
    staff_no_passkey.update!(status_id: StaffStatus::ACTIVE)

    post options_sign_org_in_passkeys_url(ri: "jp"), params: { identifier: staff_no_passkey.public_id }

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("errors.webauthn.no_passkeys_available")
  end

  test "options rejects email identifier" do
    post options_sign_org_in_passkeys_url(ri: "jp"), params: { identifier: "staff_test@example.com" }

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("errors.webauthn.identifier_invalid")
  end

  test "options returns challenge and allowCredentials for lowercase staff public_id identifier" do
    post options_sign_org_in_passkeys_url(ri: "jp"), params: { identifier: @staff.public_id.downcase }

    assert_response :ok
    json = response.parsed_body

    assert_not_nil json["challenge_id"]
    options = json["options"]

    assert_not_empty options["allowCredentials"]

    # Verify allowCredentials contains our passkey ID
    match = options["allowCredentials"].any? { |c| c["id"] == @staff_passkey.webauthn_id }

    assert match, "Expected allowCredentials to contain #{@staff_passkey.webauthn_id}"

    # Verify challenge saved with correct purpose
    assert_not_nil session[:passkey_challenges][json["challenge_id"]]
    assert_equal "authentication", session[:passkey_challenges][json["challenge_id"]]["purpose"]
    assert_equal @staff.id, session[:passkey_challenges][json["challenge_id"]]["staff_id"]
  end

  test "options returns challenge and allowCredentials for staff public_id identifier" do
    post options_sign_org_in_passkeys_url(ri: "jp"), params: { identifier: @staff.public_id }

    assert_response :ok
    json = response.parsed_body

    assert_not_nil json["challenge_id"]
    assert_not_empty json.dig("options", "allowCredentials")
  end

  test "verification returns error if challenge_id blank" do
    post verification_sign_org_in_passkeys_url(ri: "jp"), params: { challenge_id: "" }

    assert_response :bad_request
    assert_includes response.body, I18n.t("errors.webauthn.challenge_id_required")
  end

  test "verification returns error if challenge invalid" do
    post verification_sign_org_in_passkeys_url(ri: "jp"), params: { challenge_id: "invalid_challenge" }

    assert_response :bad_request
    assert_includes response.body, I18n.t("errors.webauthn.challenge_invalid")
  end

  test "verification returns bad request on challenge purpose mismatch" do
    post options_sign_org_in_passkeys_url(ri: "jp"), params: { identifier: @staff.public_id }
    challenge_id = response.parsed_body["challenge_id"]
    mismatch_error = Sign::Webauthn::ChallengePurposeMismatchError.new("purpose mismatch")

    original_method = Sign::Org::In::PasskeysController.instance_method(:with_challenge)
    Sign::Org::In::PasskeysController.define_method(:with_challenge) do |*_args|
      raise mismatch_error
    end

    begin
      post(
        verification_sign_org_in_passkeys_url(ri: "jp"), params: {
          challenge_id: challenge_id,
          credential: {
            id: @staff_passkey.webauthn_id,
            response: { clientDataJSON: "e30=", authenticatorData: "e30=", signature: "sig", userHandle: "h" },
          },
        },
      )
    ensure
      Sign::Org::In::PasskeysController.define_method(:with_challenge, original_method)
    end

    assert_response :bad_request
    assert_includes response.body, I18n.t("errors.webauthn.challenge_invalid")
  end

  test "verification logs staff in on success" do
    assert_not_nil @staff_passkey, "Passkey must exist"
    post options_sign_org_in_passkeys_url(ri: "jp"), params: { identifier: @staff.public_id }
    explanation = response.parsed_body
    challenge_id = explanation["challenge_id"]

    # Mock WebAuthn verification
    mock_credential = Object.new
    passkey_id = @staff_passkey.webauthn_id
    mock_credential.define_singleton_method(:id) { passkey_id }
    mock_credential.define_singleton_method(:sign_count) { 1 }
    mock_credential.define_singleton_method(:verify) { |*_args| true }

    WebAuthn::Credential.stub(:from_get, mock_credential) do
      params = {
        challenge_id: challenge_id,
        credential: {
          id: @staff_passkey.webauthn_id,
          response: { clientDataJSON: "e30=", authenticatorData: "e30=", signature: "sig", userHandle: "h" },
        },
      }

      # Should log in
      post verification_sign_org_in_passkeys_url(ri: "jp", rd: "/configuration/passkeys"), params: params

      assert_response :ok
      json = response.parsed_body

      assert_equal "ok", json["status"]
      assert_not_nil json["access_token"]
      assert_equal "Bearer", json["token_type"]
      assert_equal Authentication::Base::ACCESS_TOKEN_TTL.to_i, json["expires_in"]
      assert_equal sign_org_root_path(ri: "jp"), json["redirect_url"]

      # Challenge verification updates sign count
      assert_equal 1, @staff_passkey.reload.sign_count
      assert_not_nil @staff_passkey.reload.last_used_at
    end
  end

  test "verification returns unauthorized for credential mismatch" do
    post options_sign_org_in_passkeys_url(ri: "jp"), params: { identifier: @staff.public_id }
    challenge_id = response.parsed_body["challenge_id"]

    mock_credential = Object.new
    mock_credential.define_singleton_method(:id) {
      Base64.urlsafe_encode64("unknown_credential", padding: false)
    }
    mock_credential.define_singleton_method(:sign_count) { 1 }
    mock_credential.define_singleton_method(:verify) { |*_args| true }

    WebAuthn::Credential.stub(:from_get, mock_credential) do
      post verification_sign_org_in_passkeys_url(ri: "jp"), params: {
        challenge_id: challenge_id,
        credential: {
          id: Base64.urlsafe_encode64("unknown_credential", padding: false),
          response: { clientDataJSON: "e30=", authenticatorData: "e30=", signature: "sig", userHandle: "h" },
        },
      }

      assert_response :unauthorized
      assert_includes response.body, I18n.t("errors.webauthn.credential_not_found")
    end
  end

  test "verification returns unauthorized when challenge actor and passkey owner mismatch" do
    post options_sign_org_in_passkeys_url(ri: "jp"), params: { identifier: @staff.public_id }
    challenge_id = response.parsed_body["challenge_id"]

    other_staff = staffs(:two)
    other_staff.update!(status_id: StaffStatus::ACTIVE)
    other_passkey = StaffPasskey.create!(
      staff: other_staff,
      webauthn_id: Base64.urlsafe_encode64("other_staff_key_#{SecureRandom.hex(4)}", padding: false),
      external_id: SecureRandom.uuid,
      public_key: "other_staff_key",
      name: "Other Staff Key",
      status_id: StaffPasskeyStatus::ACTIVE,
    )

    mock_credential = Object.new
    mock_credential.define_singleton_method(:id) { other_passkey.webauthn_id }
    mock_credential.define_singleton_method(:sign_count) { 1 }
    mock_credential.define_singleton_method(:verify) { |*_args| true }

    WebAuthn::Credential.stub(:from_get, mock_credential) do
      post verification_sign_org_in_passkeys_url(ri: "jp"), params: {
        challenge_id: challenge_id,
        credential: {
          id: other_passkey.webauthn_id,
          response: { clientDataJSON: "e30=", authenticatorData: "e30=", signature: "sig", userHandle: "h" },
        },
      }
    end

    assert_response :unauthorized
    assert_includes response.body, I18n.t("errors.webauthn.credential_not_found")
  end

  test "verification returns 422 when login result status is unknown" do
    post options_sign_org_in_passkeys_url(ri: "jp"), params: { identifier: @staff.public_id }
    challenge_id = response.parsed_body["challenge_id"]

    passkey_id = @staff_passkey.webauthn_id
    mock_credential = Object.new
    mock_credential.define_singleton_method(:id) { passkey_id }
    mock_credential.define_singleton_method(:sign_count) { 1 }
    mock_credential.define_singleton_method(:verify) { |*_args| true }

    original_method = Sign::Org::In::PasskeysController.instance_method(:perform_passkey_sign_in)
    Sign::Org::In::PasskeysController.define_method(:perform_passkey_sign_in) do |*_args|
      { status: :unknown_status }
    end

    begin
      WebAuthn::Credential.stub(:from_get, mock_credential) do
        post(
          verification_sign_org_in_passkeys_url(ri: "jp"), params: {
            challenge_id: challenge_id,
            credential: {
              id: @staff_passkey.webauthn_id,
              response: { clientDataJSON: "e30=",
                          authenticatorData: "e30=",
                          signature: "sig",
                          userHandle: "h", },
            },
          },
        )
      end
    ensure
      Sign::Org::In::PasskeysController.define_method(:perform_passkey_sign_in, original_method)
    end

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("errors.login_failed")
  end

  test "verification for staff with mfa enabled succeeds (MFA not enforced for staff)" do
    @staff.update!(multi_factor_enabled: true)

    post options_sign_org_in_passkeys_url(ri: "jp"), params: { identifier: @staff.public_id }
    challenge_id = response.parsed_body["challenge_id"]

    mock_credential = Object.new
    passkey_id = @staff_passkey.webauthn_id
    mock_credential.define_singleton_method(:id) { passkey_id }
    mock_credential.define_singleton_method(:sign_count) { 1 }
    mock_credential.define_singleton_method(:verify) { |*_args| true }

    WebAuthn::Credential.stub(:from_get, mock_credential) do
      params = {
        challenge_id: challenge_id,
        credential: {
          id: @staff_passkey.webauthn_id,
          response: { clientDataJSON: "e30=", authenticatorData: "e30=", signature: "sig", userHandle: "h" },
        },
      }

      post verification_sign_org_in_passkeys_url(ri: "jp"), params: params

      assert_response :ok
      json = response.parsed_body

      assert_equal "ok", json["status"]
    end
  end

  test "verification returns session_restricted when one logical session has many rotated ancestors" do
    create_rotated_active_staff_session(@staff, rotations: 4)

    post options_sign_org_in_passkeys_url(ri: "jp"), params: { identifier: @staff.public_id }
    challenge_id = response.parsed_body["challenge_id"]

    mock_credential = Object.new
    passkey_id = @staff_passkey.webauthn_id
    mock_credential.define_singleton_method(:id) { passkey_id }
    mock_credential.define_singleton_method(:sign_count) { 1 }
    mock_credential.define_singleton_method(:verify) { |*_args| true }

    WebAuthn::Credential.stub(:from_get, mock_credential) do
      post verification_sign_org_in_passkeys_url(ri: "jp"), params: {
        challenge_id: challenge_id,
        credential: {
          id: @staff_passkey.webauthn_id,
          response: { clientDataJSON: "e30=", authenticatorData: "e30=", signature: "sig", userHandle: "h" },
        },
      }
    end

    assert_response :ok
    json = response.parsed_body

    assert_equal "session_restricted", json["status"]
    assert_equal sign_org_in_session_path(ri: "jp"), json["redirect_url"]
    assert_equal 1, StaffToken.where(staff_id: @staff.id, status: StaffToken::STATUS_RESTRICTED).count
  end

  test "verification returns unauthorized for malformed credential payload" do
    post options_sign_org_in_passkeys_url(ri: "jp"), params: { identifier: @staff.public_id }
    challenge_id = response.parsed_body["challenge_id"]

    post verification_sign_org_in_passkeys_url(ri: "jp"), params: {
      challenge_id: challenge_id,
      credential: { invalid: "payload" },
    }

    assert_response :unauthorized
    assert_includes response.body, I18n.t("errors.webauthn.credential_not_found")
  end

  private

  def create_rotated_active_staff_session(staff, rotations:)
    token = StaffToken.create!(staff: staff, status: StaffToken::STATUS_ACTIVE)
    refresh = token.rotate_refresh_token!

    rotations.times do
      refresh = Sign::RefreshTokenService.call(refresh_token: refresh)[:refresh_token]
    end
  end
end
