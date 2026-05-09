# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class Sign::Com::Configuration::PasskeysControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    host! @host
    @origin_headers = { "HTTP_ORIGIN" => "http://#{@host}", "Origin" => "http://#{@host}" }.freeze
    @customer = create_verified_customer_with_email(email_address: "com_passkey_config@example.com")
    @customer.customer_telephones.create!(
      number: "+819044444444",
      customer_telephone_status_id: CustomerTelephoneStatus::VERIFIED,
    )
    @headers = as_customer_headers(@customer, host: @host)
    @token = CustomerToken.find_by!(public_id: @headers["X-TEST-SESSION-PUBLIC-ID"])
    satisfy_customer_verification(@token)

    host_value = @host
    @original_trusted_origins = Webauthn.method(:trusted_origins)
    Webauthn.define_singleton_method(:trusted_origins) { ["http://id.app.localhost", "http://#{host_value}"] }

    @passkey = CustomerPasskey.create!(
      customer: @customer,
      webauthn_id: Base64.urlsafe_encode64("com_existing_credential", padding: false),
      public_key: "public_key_#{SecureRandom.hex(4)}",
      sign_count: 0,
      description: "My Passkey",
      status_id: CustomerPasskeyStatus::ACTIVE,
    )
  end

  teardown do
    Webauthn.define_singleton_method(:trusted_origins, @original_trusted_origins) if @original_trusted_origins
  end

  test "redirects unauthenticated user to login" do
    get sign_com_configuration_passkeys_path(ri: "jp")

    assert_response :redirect
  end

  test "should get index" do
    get sign_com_configuration_passkeys_path(ri: "jp"), headers: @headers

    assert_response :success
  end

  test "options returns challenge and options" do
    if true # Replaced STUB stub with real execution as per G1
      post options_sign_com_configuration_passkeys_path(ri: "jp"), headers: @headers.merge(@origin_headers)
    end

    assert_response :ok
    assert_not_nil response.parsed_body["challenge_id"]
  end

  test "verification creates passkey on success" do
    if true # Replaced STUB stub with real execution as per G1
      post options_sign_com_configuration_passkeys_path(ri: "jp"), headers: @headers.merge(@origin_headers)
    end
    challenge_id = response.parsed_body["challenge_id"]

    mock_credential = Object.new
    mock_credential.define_singleton_method(:id) { "new_webauthn_id" }
    mock_credential.define_singleton_method(:public_key) { "new_public_key" }
    mock_credential.define_singleton_method(:sign_count) { 1 }
    mock_credential.define_singleton_method(:verify) { |*_args| true }

    WebAuthn::Credential.stub(:from_create, mock_credential) do
      assert_difference("CustomerPasskey.count", 1) do
        post verification_sign_com_configuration_passkeys_path(ri: "jp"),
             params: {
               challenge_id: challenge_id,
               credential: {
                 id: "new_webauthn_id",
                 response: { clientDataJSON: "e30=", attestationObject: "e30=" },
               },
               description: "New Passkey",
             },
             headers: @headers.merge(@origin_headers)
      end
    end

    assert_response :created
    assert_equal "ok", response.parsed_body["status"]
  end

  test "create json returns not implemented" do
    I18n.backend.store_translations(:ja, messages: { not_implemented: "Not implemented" })
    post sign_com_configuration_passkeys_path(ri: "jp", format: :json), headers: @headers

    assert_response :unprocessable_content
    assert_equal I18n.t("messages.not_implemented"), response.parsed_body["error"]
  end

  test "destroy json returns no content" do
    delete sign_com_configuration_passkey_path(@passkey.id, ri: "jp", format: :json), headers: @headers

    assert_response :no_content
  end
end
