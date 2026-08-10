# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "minitest/mock"
require "base64"

class Auth::Org::Sign::In::PasskeysControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses, :operator_passkeys, :operator_passkey_statuses

  setup do
    host = ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")
    host! host
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    # Setup active staff with email and passkey
    @staff = operators(:one)
    @staff.update!(status_id: OperatorStatus::ACTIVE)
    OperatorToken.where(staff_id: @staff.id).delete_all

    @staff_passkey = OperatorPasskey.create!(
      staff: @staff,
      webauthn_id: Base64.urlsafe_encode64("staff_login_id_bytes_12345", padding: false),
      external_id: SecureRandom.uuid,
      public_key: "staff_login_key",
      description: "Staff Login Key",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )
  end

  teardown do
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.response = nil
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
  end

  test "should get new" do
    get new_auth_org_sign_in_passkey_url(ri: "jp")

    assert_response :success
    assert_select "label", text: "ID"
    assert_select "input#identifier[required]"
    assert_select "input#identifier[minlength='16']"
    assert_select "input#identifier[maxlength='16']"
    assert_select "input#identifier[pattern='[0-9A-FGHJKMNPQRSTVWXYZ]{16}']"
    assert_select "input#identifier[autocapitalize='characters']"
    assert_select "input#identifier[spellcheck='false']"
    assert_select "[data-passkey-authentication-options-url-value=?]", auth_org_sign_in_passkey_options_path(ri: "jp")
    assert_select "[data-passkey-authentication-verification-url-value=?]",
                  auth_org_sign_in_passkey_verification_path(ri: "jp")
    assert_select "[data-passkey-authentication-region-value=?]", "jp"
  end

  test "options returns error if identifier blank" do
    post auth_org_sign_in_passkey_options_url(ri: "jp"), params: { identifier: "" }

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("errors.webauthn.identifier_required")
  end

  test "options returns error if identifier missing" do
    post auth_org_sign_in_passkey_options_url(ri: "jp"), params: {}

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("errors.webauthn.identifier_required")
  end

  test "options returns error if identifier not found" do
    post auth_org_sign_in_passkey_options_url(ri: "jp"), params: { identifier: "unknown@example.com" }

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("errors.webauthn.identifier_invalid")
  end

  test "options returns an indistinguishable padded challenge if staff has no passkeys" do
    staff_no_passkey = operators(:two)
    staff_no_passkey.update!(status_id: OperatorStatus::ACTIVE)

    post auth_org_sign_in_passkey_options_url(ri: "jp"), params: { identifier: staff_no_passkey.public_id }

    assert_response :ok
    assert_predicate response.parsed_body["challenge_id"], :present?
    assert_equal 4, response.parsed_body.dig("options", "allowCredentials").size
  end

  test "options returns an indistinguishable padded challenge for an unknown valid staff identifier" do
    post auth_org_sign_in_passkey_options_url(ri: "jp"), params: { identifier: "0000000000000000" }

    assert_response :ok
    assert_predicate response.parsed_body["challenge_id"], :present?
    assert_equal 4, response.parsed_body.dig("options", "allowCredentials").size
  end

  test "options rejects email identifier" do
    post auth_org_sign_in_passkey_options_url(ri: "jp"), params: { identifier: "staff_test@example.com" }

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("errors.webauthn.identifier_invalid")
  end

  test "options returns challenge and allowCredentials for lowercase staff public_id identifier" do
    post auth_org_sign_in_passkey_options_url(ri: "jp"), params: { identifier: @staff.public_id.downcase }

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
    assert_equal "org:#{@staff.id}",
                 session[:passkey_challenges][json["challenge_id"]]["actor_global_key"]
  end

  test "options returns challenge and allowCredentials for staff public_id identifier" do
    post auth_org_sign_in_passkey_options_url(ri: "jp"), params: { identifier: @staff.public_id }

    assert_response :ok
    json = response.parsed_body

    assert_not_nil json["challenge_id"]
    assert_not_empty json.dig("options", "allowCredentials")
  end

  test "verification returns error if challenge_id blank" do
    post auth_org_sign_in_passkey_verification_url(ri: "jp"), params: { challenge_id: "" }

    assert_response :bad_request
    assert_includes response.body, I18n.t("errors.webauthn.challenge_id_required")
  end

  test "verification returns error if challenge invalid" do
    post auth_org_sign_in_passkey_verification_url(ri: "jp"), params: { challenge_id: "invalid_challenge" }

    assert_response :bad_request
    assert_includes response.body, I18n.t("errors.webauthn.challenge_invalid")
  end

  test "verification returns bad request on challenge purpose mismatch" do
    post auth_org_sign_in_passkey_options_url(ri: "jp"), params: { identifier: @staff.public_id }
    challenge_id = response.parsed_body["challenge_id"]
    mismatch_error = Webauthn::ChallengeStore::ChallengePurposeMismatchError.new("purpose mismatch")

    original_method =
      Auth::Org::Sign::In::Passkey::VerificationsController
        .instance_method(:consume_passkey_challenge_with_actor!)
    Auth::Org::Sign::In::Passkey::VerificationsController
      .define_method(:consume_passkey_challenge_with_actor!) do |*_args|
      raise mismatch_error
    end

    begin
      post(
        auth_org_sign_in_passkey_verification_url(ri: "jp"), params: {
          challenge_id: challenge_id,
          credential: {
            id: @staff_passkey.webauthn_id,
            response: { clientDataJSON: "e30=", authenticatorData: "e30=", signature: "sig", userHandle: "h" },
          },
        },
      )
    ensure
      Auth::Org::Sign::In::Passkey::VerificationsController
        .define_method(:consume_passkey_challenge_with_actor!, original_method)
    end

    assert_response :bad_request
    assert_includes response.body, I18n.t("errors.webauthn.challenge_invalid")
  end

  test "verification logs staff in on success" do
    assert_not_nil @staff_passkey, "Passkey must exist"
    post auth_org_sign_in_passkey_options_url(ri: "jp"), params: { identifier: @staff.public_id }
    explanation = response.parsed_body
    challenge_id = explanation["challenge_id"]

    verified_at = Time.current
    verification_context = Struct.new(:sign_count, :verified_at).new(1, verified_at)

    Webauthn::AssertionVerifier.stub(:verify!, verification_context) do
      params = {
        challenge_id: challenge_id,
        credential: {
          id: @staff_passkey.webauthn_id,
          response: { clientDataJSON: "e30=", authenticatorData: "e30=", signature: "sig", userHandle: "h" },
        },
      }

      # Should log in
      post auth_org_sign_in_passkey_verification_url(ri: "jp", pt: "/settings/passkeys"), params: params

      assert_response :ok
      json = response.parsed_body

      assert_equal "ok", json["status"]
      assert_not_nil json["access_token"]
      assert_equal "Bearer", json["token_type"]
      assert_equal AuthenticationBase::ACCESS_TOKEN_TTL.to_i, json["expires_in"]
      assert_equal auth_org_sign_in_check_path(ri: "jp"), json["redirect_url"]

      # Challenge verification updates sign count
      assert_equal 1, @staff_passkey.reload.sign_count
      assert_not_nil @staff_passkey.reload.last_used_at
    end
  end

  test "verification returns unauthorized for credential mismatch" do
    post auth_org_sign_in_passkey_options_url(ri: "jp"), params: { identifier: @staff.public_id }
    challenge_id = response.parsed_body["challenge_id"]

    post auth_org_sign_in_passkey_verification_url(ri: "jp"), params: {
      challenge_id: challenge_id,
      credential: {
        id: Base64.urlsafe_encode64("unknown_credential", padding: false),
        response: { clientDataJSON: "e30=", authenticatorData: "e30=", signature: "sig", userHandle: "h" },
      },
    }

    assert_response :unauthorized
    assert_includes response.body, I18n.t("errors.webauthn.credential_not_found")
  end

  test "verification returns unauthorized when challenge actor and passkey owner mismatch" do
    post auth_org_sign_in_passkey_options_url(ri: "jp"), params: { identifier: @staff.public_id }
    challenge_id = response.parsed_body["challenge_id"]

    other_staff = operators(:two)
    other_staff.update!(status_id: OperatorStatus::ACTIVE)
    other_passkey = OperatorPasskey.create!(
      staff: other_staff,
      webauthn_id: Base64.urlsafe_encode64("other_staff_key_#{SecureRandom.hex(4)}", padding: false),
      external_id: SecureRandom.uuid,
      public_key: "other_staff_key",
      description: "Other Staff Key",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )

    post auth_org_sign_in_passkey_verification_url(ri: "jp"), params: {
      challenge_id: challenge_id,
      credential: {
        id: other_passkey.webauthn_id,
        response: { clientDataJSON: "e30=", authenticatorData: "e30=", signature: "sig", userHandle: "h" },
      },
    }

    assert_response :unauthorized
    assert_includes response.body, I18n.t("errors.webauthn.credential_not_found")
  end

  test "verification returns 422 when login result status is unknown" do
    post auth_org_sign_in_passkey_options_url(ri: "jp"), params: { identifier: @staff.public_id }
    challenge_id = response.parsed_body["challenge_id"]

    verification_context = Struct.new(:sign_count, :verified_at).new(1, Time.current)

    original_method = Auth::Org::Sign::In::Passkey::VerificationsController.instance_method(:perform_passkey_sign_in)
    Auth::Org::Sign::In::Passkey::VerificationsController.define_method(:perform_passkey_sign_in) do |*_args|
      { status: :unknown_status }
    end

    begin
      Webauthn::AssertionVerifier.stub(:verify!, verification_context) do
        post(
          auth_org_sign_in_passkey_verification_url(ri: "jp"), params: {
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
      Auth::Org::Sign::In::Passkey::VerificationsController.define_method(:perform_passkey_sign_in, original_method)
    end

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("errors.login_failed")
  end

  test "verification for staff with mfa enabled succeeds (MFA not enforced for staff)" do
    @staff.update!(mfa_level_enabled: true)

    post auth_org_sign_in_passkey_options_url(ri: "jp"), params: { identifier: @staff.public_id }
    challenge_id = response.parsed_body["challenge_id"]

    verification_context = Struct.new(:sign_count, :verified_at).new(1, Time.current)

    Webauthn::AssertionVerifier.stub(:verify!, verification_context) do
      params = {
        challenge_id: challenge_id,
        credential: {
          id: @staff_passkey.webauthn_id,
          response: { clientDataJSON: "e30=", authenticatorData: "e30=", signature: "sig", userHandle: "h" },
        },
      }

      post auth_org_sign_in_passkey_verification_url(ri: "jp"), params: params

      assert_response :ok
      json = response.parsed_body

      assert_equal "ok", json["status"]
    end
  end

  test "verification returns session_restricted when one logical session has many rotated ancestors" do
    create_rotated_active_staff_session(@staff, rotations: 4)

    post auth_org_sign_in_passkey_options_url(ri: "jp"), params: { identifier: @staff.public_id }
    challenge_id = response.parsed_body["challenge_id"]

    verification_context = Struct.new(:sign_count, :verified_at).new(1, Time.current)

    Webauthn::AssertionVerifier.stub(:verify!, verification_context) do
      post auth_org_sign_in_passkey_verification_url(ri: "jp"), params: {
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
    assert_equal auth_org_sign_in_session_path(ri: "jp"), json["redirect_url"]
    assert_equal 0, OperatorToken.where(staff_id: @staff.id, staff_token_status_id: OperatorTokenStatus::RESTRICTED).count
  end

  test "verification returns unauthorized for malformed credential payload" do
    post auth_org_sign_in_passkey_options_url(ri: "jp"), params: { identifier: @staff.public_id }
    challenge_id = response.parsed_body["challenge_id"]

    post auth_org_sign_in_passkey_verification_url(ri: "jp"), params: {
      challenge_id: challenge_id,
      credential: { invalid: "payload" },
    }

    assert_response :unauthorized
    assert_includes response.body, I18n.t("errors.webauthn.credential_not_found")
  end

  private

  def create_rotated_active_staff_session(staff, rotations:)
    token = OperatorToken.create!(staff: staff, staff_token_status_id: OperatorTokenStatus::ACTIVE)
    refresh = token.rotate_refresh_token!

    rotations.times do
      refresh = SignRefreshTokenIssuer.call(refresh_token: refresh)[:refresh_token]
    end
  end
end
