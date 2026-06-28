# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class Auth::Com::Settings::PasskeysControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("AUTH_CORPORATE_URL", "auth.com.localhost")
    host! @host
    @origin_headers = { "HTTP_ORIGIN" => "http://#{@host}", "Origin" => "http://#{@host}" }.freeze
    @visitor = create_verified_visitor_with_email(email_address: "com_passkey_config@example.com")
    @visitor.visitor_secret_credentials.destroy_all
    create_visitor_recovery_passcode!(@visitor, name: "recovery 1")
    create_visitor_recovery_passcode!(@visitor, name: "recovery 2")
    @visitor.visitor_telephones.create!(
      number: "+819044444444",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    @headers = as_visitor_headers(@visitor, host: @host)
    @token = VisitorToken.find_by!(public_id: @headers["X-TEST-SESSION-PUBLIC-ID"])
    satisfy_visitor_verification(@token)
    mark_token_step_up_satisfied_for_test(@token, scope: "settings_passkey")

    host_value = @host
    @original_trusted_origins = Webauthn.method(:trusted_origins)
    Webauthn.define_singleton_method(:trusted_origins) { ["http://auth.app.localhost", "http://#{host_value}"] }

    @passkey = VisitorPasskey.create!(
      visitor: @visitor,
      webauthn_id: Base64.urlsafe_encode64("com_existing_credential", padding: false),
      public_key: "public_key_#{SecureRandom.hex(4)}",
      sign_count: 0,
      description: "My Passkey",
      status_id: VisitorPasskeyStatus::ACTIVE,
    )

    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
    Webauthn.define_singleton_method(:trusted_origins, @original_trusted_origins) if @original_trusted_origins
  end

  test "redirects unauthenticated user to login" do
    get auth_com_settings_passkeys_path(ri: "jp")

    assert_response :redirect
  end

  test "index renders sign settings passkeys" do
    get auth_com_settings_passkeys_path(ri: "jp"), headers: @headers

    assert_response :success
    assert_includes response.body, @passkey.description
  end

  test "options returns challenge and options" do
    post auth_com_settings_passkeys_options_path(ri: "jp"),
         headers: @headers.merge(@origin_headers)

    assert_response :ok
    assert_not_nil response.parsed_body["challenge_id"]
  end

  test "options denies with fewer than two unused usable recovery passcodes" do
    @visitor.visitor_secret_credentials.destroy_all
    create_visitor_recovery_passcode!(@visitor, name: "only recovery")

    post auth_com_settings_passkeys_options_path(ri: "jp"), headers: @headers.merge(@origin_headers), as: :json

    assert_response :forbidden
    assert_equal "text/html", response.media_type
    assert_includes response.body, auth_com_settings_secret_credentials_url(
      ri: "jp",
      host: @host,
    )
  end

  test "verification creates passkey on success" do
    post auth_com_settings_passkeys_options_path(ri: "jp"),
         headers: @headers.merge(@origin_headers)
    challenge_id = response.parsed_body["challenge_id"]
    cookie_header = response_set_cookie_lines.map { |line| line.split(";", 2).first }.join("; ")

    mock_credential = Object.new
    mock_credential.define_singleton_method(:id) { "new_webauthn_id" }
    mock_credential.define_singleton_method(:public_key) { "new_public_key" }
    mock_credential.define_singleton_method(:sign_count) { 1 }
    mock_credential.define_singleton_method(:verify) { |*_args| true }

    WebAuthn::Credential.stub(:from_create, mock_credential) do
      assert_difference("VisitorPasskey.count", 1) do
        assert_difference(-> { @visitor.reload.visitor_secret_credentials.count }, 8) do
          post auth_com_settings_passkeys_verification_path(ri: "jp"),
               params: {
                 challenge_id: challenge_id,
                 credential: {
                   id: "new_webauthn_id",
                   response: { clientDataJSON: "e30=", attestationObject: "e30=" },
                 },
                 description: "New Passkey",
               },
               headers: @headers.merge(@origin_headers).merge("Cookie" => cookie_header)
        end
      end
    end

    assert_response :created
    assert_equal "ok", response.parsed_body["status"]
    assert_includes response.parsed_body["redirect_url"], "/settings/secrets"
  end

  test "verification succeeds without recovery passcodes on bootstrap and tops up to ten" do
    visitor = create_verified_visitor_with_email(email_address: "com-bootstrap-#{SecureRandom.hex(4)}@example.com")
    visitor.visitor_telephones.create!(
      number: "+819055555555",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    token = VisitorToken.create!(visitor: visitor, visitor_token_status_id: VisitorTokenStatus::ACTIVE)
    satisfy_visitor_verification(token)
    mark_token_step_up_satisfied_for_test(token, scope: "settings_passkey")
    headers = as_visitor_headers(visitor, host: @host, session_public_id: token.public_id)

    mock_credential = Object.new
    mock_credential.define_singleton_method(:id) { "bootstrap_new_webauthn_id" }
    mock_credential.define_singleton_method(:public_key) { "bootstrap_new_public_key" }
    mock_credential.define_singleton_method(:sign_count) { 1 }
    mock_credential.define_singleton_method(:verify) { |*_args| true }

    WebAuthn::Credential.stub(:from_create, mock_credential) do
      post auth_com_settings_passkeys_options_path(ri: "jp"),
           headers: headers.merge(@origin_headers)
      challenge_id = response.parsed_body["challenge_id"]
      cookie_header = response_set_cookie_lines.map { |line| line.split(";", 2).first }.join("; ")

      assert_difference("VisitorPasskey.count", 1) do
        assert_difference(-> { visitor.reload.visitor_secret_credentials.count }, 10) do
          post auth_com_settings_passkeys_verification_path(ri: "jp"),
               params: {
                 challenge_id: challenge_id,
                 credential: {
                   id: "bootstrap_new_webauthn_id",
                   response: { clientDataJSON: "e30=", attestationObject: "e30=" },
                 },
                 description: "Bootstrap Passkey",
               },
               headers: headers.merge(@origin_headers).merge("Cookie" => cookie_header)
        end
      end
    end

    assert_response :created
    assert_includes response.parsed_body["redirect_url"], "/settings/secrets"
  end

  test "create json returns registration ceremony handoff" do
    assert_no_difference("VisitorPasskey.count") do
      post auth_com_settings_passkeys_path(ri: "jp", format: :json), headers: @headers
    end

    assert_response :accepted
    assert_equal "registration_ceremony_required", response.parsed_body["status"]
    assert_equal new_auth_com_settings_passkey_path(ri: "jp"), response.parsed_body["redirect_path"]
  end

  test "update accepts visitor passkey form params" do
    patch auth_com_settings_passkey_path(@passkey.public_id, ri: "jp"),
          params: { visitor_passkey: { description: "Updated Passkey" } },
          headers: @headers

    assert_redirected_to auth_com_settings_passkey_path(@passkey.public_id, ri: "jp")
    assert_equal "Updated Passkey", @passkey.reload.description
  end

  test "destroy removes visitor passkey on sign settings authority" do
    assert_difference("VisitorPasskey.count", -1) do
      delete auth_com_settings_passkey_path(@passkey.public_id, ri: "jp"), headers: @headers
    end

    assert_redirected_to auth_com_settings_passkeys_path(ri: "jp")
  end

  private

  def create_visitor_recovery_passcode!(visitor, name:, last_used_at: nil)
    credential = visitor.visitor_secret_credentials.new(
      name: name,
      visitor_secret_credential_kind_id: VisitorSecretCredentialKind::RECOVERY,
      visitor_secret_credential_status_id: VisitorSecretCredentialStatus::ACTIVE,
      last_used_at: last_used_at,
    )
    credential.password = VisitorSecretCredential.generate_raw_secret_credential
    credential.save!
    credential
  end
end
