# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class Sign::Com::Up::CheckpointPasskeysControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    cookies["csrf_token"] = csrf_token_value

    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }

    Prosopite.pause do
      [1, 2, 3].each { |id| VisitorStatus.find_or_create_by!(id: id) }
      [0, 1, 2, 3].each { |id| VisitorVisibility.find_or_create_by!(id: id) }
      [
        VisitorTelephoneStatus::UNVERIFIED,
        VisitorTelephoneStatus::VERIFIED,
        VisitorTelephoneStatus::UNVERIFIED_WITH_SIGN_UP,
        VisitorTelephoneStatus::VERIFIED_WITH_SIGN_UP,
      ].each { |id| VisitorTelephoneStatus.find_or_create_by!(id: id) }
      VisitorTokenDbscStatus.ensure_defaults!
      VisitorTokenStatus::DEFAULTS.each do |id|
        VisitorTokenStatus.find_or_create_by!(id: id)
      end
      VisitorPasskeyStatus.find_or_create_by!(id: VisitorPasskeyStatus::ACTIVE)
      VisitorSecretCredentialStatus::DEFAULTS.each do |id|
        VisitorSecretCredentialStatus.find_or_create_by!(id: id)
      end
      VisitorSecretCredentialKind::DEFAULTS.each do |id|
        VisitorSecretCredentialKind.find_or_create_by!(id: id)
      end
    end

    @original_trusted_origins = Webauthn.method(:trusted_origins)
    allowed_origins = [
      "http://id.com.localhost",
      "http://www.example.com",
      "http://#{ENV.fetch("ID_CORPORATE_URL", "id.umaxica.com")}",
      "https://#{ENV.fetch("ID_CORPORATE_URL", "id.umaxica.com")}",
    ].uniq
    Webauthn.define_singleton_method(:trusted_origins) { allowed_origins }
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil

    Webauthn.define_singleton_method(:trusted_origins, @original_trusted_origins)
  end

  test "telephone sign up finalizes and establishes login after otp passkey passcode and birthdate" do
    telephone = verify_telephone_via_otp!
    cycle = current_sign_up_flow(telephone)

    post sign_com_sign_up_check_telephone_passkey_url(ri: "jp")
    challenge_id = response.parsed_body["challenge_id"]

    mock_credential = Object.new
    mock_credential.define_singleton_method(:id) { "com_finalize_webauthn_id" }
    mock_credential.define_singleton_method(:public_key) { "com_finalize_public_key" }
    mock_credential.define_singleton_method(:sign_count) { 1 }
    mock_credential.define_singleton_method(:verify) { |_challenge| true }

    WebAuthn::Credential.stub(:from_create, mock_credential) do
      patch sign_com_sign_up_check_telephone_passkey_url(ri: "jp"), params: {
        challenge_id: challenge_id,
        checkpoint_version: cycle.checkpoint_version,
        credential: {
          id: "com_finalize_webauthn_id",
          response: { clientDataJSON: "e30=", attestationObject: "e30=" },
        },
        description: "Finalize Passkey",
      }
    end

    assert_response :created
    assert_equal sign_com_sign_up_check_telephone_passcode_path(ri: "jp"),
                 response.parsed_body["redirect_url"]
    assert cycle.reload.requirement_cleared?(:passkey)

    get sign_com_sign_up_check_telephone_passcode_url(ri: "jp")

    assert_response :success

    patch sign_com_sign_up_check_telephone_passcode_url(ri: "jp"), params: {
      checkpoint_version: cycle.reload.checkpoint_version,
    }

    assert_redirected_to sign_com_sign_up_check_telephone_birthdate_url(ri: "jp")
    assert cycle.reload.requirement_cleared?(:passcode)

    get sign_com_sign_up_check_telephone_birthdate_url(ri: "jp")

    assert_response :success

    patch sign_com_sign_up_check_telephone_birthdate_url(ri: "jp"), params: {
      requirement: "birthdate",
      birthdate: "2000-01-01",
      checkpoint_version: cycle.reload.checkpoint_version,
    }

    assert_response :redirect

    visitor = telephone.visitor.reload

    assert_equal VisitorSignUpFlowStatus::COMPLETED, cycle.reload.status_id
    assert_equal VisitorStatus::ACTIVE, visitor.status_id
    assert VisitorToken.exists?(visitor_id: visitor.id)
  end

  private

  def verify_telephone_via_otp!
    post(
      sign_com_sign_up_telephone_url,
      params: {
        visitor_telephone: {
          raw_number: "+1234567891",
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
      sign_com_sign_up_check_telephone_otp_url(ri: "jp"), params: {
        visitor_telephone: { pass_code: code },
      },
    )

    assert_redirected_to sign_com_sign_up_guard_telephone_url(ri: "jp")

    get(sign_com_sign_up_guard_telephone_url(ri: "jp"))

    assert_redirected_to sign_com_sign_up_check_telephone_passkey_url(ri: "jp")

    get(sign_com_sign_up_check_telephone_passkey_url(ri: "jp"))

    assert_response :success

    telephone.reload
  end

  def current_sign_up_flow(telephone)
    VisitorSignUpFlow.order(:id).find_by!(
      principal_id: telephone.visitor_id,
      pending_contact_type: "telephone",
      pending_contact_id: telephone.id,
    )
  end

  def registration_telephone
    registration_session = session[:visitor_telephone_registration] || {}
    public_id = registration_session[:public_id] || registration_session["public_id"]
    VisitorTelephone.find_by!(public_id: public_id)
  end
end
