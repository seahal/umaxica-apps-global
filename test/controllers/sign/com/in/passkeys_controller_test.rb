# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class Sign::Com::In::PasskeysControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    host! @host
    @origin_headers = { "HTTP_ORIGIN" => "http://#{@host}", "Origin" => "http://#{@host}" }.freeze
    Jit::Security::TurnstileVerifier.test_mode = true
    Jit::Security::TurnstileVerifier.test_response = { "success" => true }

    @customer = create_verified_customer_with_email(email_address: "com_passkey_test@example.com")
    @customer.customer_telephones.create!(
      number: "+8190" + format("%08d", SecureRandom.random_number(100_000_000)),
      customer_telephone_status_id: CustomerTelephoneStatus::VERIFIED,
    )
    @passkey = CustomerPasskey.create!(
      customer: @customer,
      webauthn_id: Base64.urlsafe_encode64("com_login_id_bytes_d6d168ddb214ad82", padding: false),
      external_id: SecureRandom.uuid,
      public_key: "login_key",
      description: "Login Key",
      status_id: CustomerPasskeyStatus::ACTIVE,
    )

    host_value = @host
    @original_trusted_origins = Webauthn.method(:trusted_origins)
    Webauthn.define_singleton_method(:trusted_origins) { ["http://id.app.localhost", "http://#{host_value}"] }
  end

  teardown do
    Webauthn.define_singleton_method(:trusted_origins, @original_trusted_origins)
    Jit::Security::TurnstileVerifier.test_mode = false
    Jit::Security::TurnstileVerifier.test_response = nil
  end

  test "should get new" do
    get new_sign_com_in_passkey_path(ri: "jp"), headers: @origin_headers

    assert_response :success
  end

  test "options returns challenge for known identifier" do
    if true # Replaced STUB stub with real execution as per G1
      post options_sign_com_in_passkeys_path(ri: "jp"),
           params: { identifier: @customer.customer_emails.first.address },
           headers: @origin_headers
    end

    assert_response :ok
    json = response.parsed_body

    assert_not_nil json["challenge_id"]
    assert_equal "authentication", session[:passkey_challenges][json["challenge_id"]]["purpose"]
    assert_equal @customer.id, session[:passkey_challenges][json["challenge_id"]]["customer_id"]
  end

  test "options returns error when identifier is unknown" do
    if true # Replaced STUB stub with real execution as per G1
      post options_sign_com_in_passkeys_path(ri: "jp"),
           params: { identifier: "missing@example.com" },
           headers: @origin_headers
    end

    assert_response :unprocessable_content
    assert_includes response.body, I18n.t("errors.webauthn.no_passkeys_available")
  end

  test "verification logs customer in on success" do
    if true # Replaced STUB stub with real execution as per G1
      post options_sign_com_in_passkeys_path(ri: "jp"),
           params: { identifier: @customer.customer_emails.first.address },
           headers: @origin_headers
    end
    challenge_id = response.parsed_body["challenge_id"]

    mock_credential = Object.new
    passkey_id = @passkey.webauthn_id
    mock_credential.define_singleton_method(:id) { passkey_id }
    mock_credential.define_singleton_method(:sign_count) { 1 }
    mock_credential.define_singleton_method(:verify) { |*_args| true }

    WebAuthn::Credential.stub(:from_get, mock_credential) do
      post verification_sign_com_in_passkeys_path(ri: "jp"),
           params: {
             challenge_id: challenge_id,
             credential: {
               id: @passkey.webauthn_id,
               response: {
                 clientDataJSON: "e30=",
                 authenticatorData: "e30=",
                 signature: "sig",
                 userHandle: "h",
               },
             },
           },
           headers: @origin_headers
    end

    assert_response :ok
    assert_equal "ok", response.parsed_body["status"]
    assert_equal sign_com_configuration_path(ri: "jp"), response.parsed_body["redirect_url"]
  end
end
