# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"
require "ostruct"

class Sign::Com::In::Challenge::PasskeysControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    host! @host
    @origin_headers = { "HTTP_ORIGIN" => "http://#{@host}", "Origin" => "http://#{@host}" }.freeze
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }

    host_value = @host
    @original_trusted_origins = Webauthn.method(:trusted_origins)
    Webauthn.define_singleton_method(:trusted_origins) { ["http://#{host_value}", "http://id.app.localhost"] }

    @visitor = create_verified_visitor_with_email(email_address: "com_mfa_passkey_#{SecureRandom.hex(4)}@example.com")
    @visitor.update!(multi_factor_enabled: true)
    @visitor.visitor_telephones.create!(
      number: "+8190" + format("%08d", SecureRandom.random_number(100_000_000)),
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )

    @passkey = VisitorPasskey.create!(
      visitor: @visitor,
      webauthn_id: Base64.urlsafe_encode64("com_mfa_passkey_id_eeec6cca6c4c1cbd", padding: false),
      external_id: SecureRandom.uuid,
      public_key: "mfa-passkey-public",
      sign_count: 5,
      description: "MFA Passkey",
      status_id: VisitorPasskeyStatus::ACTIVE,
    )

    @secret = @visitor.visitor_secrets.create!(name: "Passkey MFA secret", password: "a" * 32)
    @raw_secret = "a" * 32
  end

  teardown do
    Webauthn.define_singleton_method(:trusted_origins, @original_trusted_origins) if @original_trusted_origins
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  test "new requires pending MFA session" do
    get new_sign_com_in_challenge_passkey_path(ri: "jp"), headers: @origin_headers

    assert_response :redirect

    assert_redirected_to new_sign_com_in_path(ri: "jp")
  end

  test "create verifies passkey and redirects on success" do
    establish_pending_mfa!

    if true # Replaced STUB stub with real execution as per G1
      get new_sign_com_in_challenge_passkey_path(ri: "jp"), headers: @origin_headers

      assert_response :success
    end

    challenge_id = session[:passkey_challenges].keys.first

    mock_credential = OpenStruct.new(id: @passkey.webauthn_id, sign_count: 6)
    mock_credential.define_singleton_method(:verify) { |*_args| true }

    WebAuthn::Credential.stub(:from_get, mock_credential) do
      post sign_com_in_challenge_passkey_path(ri: "jp"),
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
                   userHandle: @visitor.public_id,
                 },
               }.to_json,
             },
           },
           headers: @origin_headers
    end

    assert_response :redirect

    assert_redirected_to sign_com_welcome_entry_path(ri: "jp")
    assert_nil session[:pending_mfa]
    assert_equal 6, @passkey.reload.sign_count
  end

  private

  def establish_pending_mfa!
    post(
      sign_com_in_secret_path(ri: "jp"), params: {
        secret_login_form: {
          identifier: @visitor.visitor_emails.first.address,
          secret_value: @raw_secret,
        },
        "cf-turnstile-response": "test_token",
      },
    )

    assert_response :redirect
  end
end
