# typed: false
# frozen_string_literal: true

require "test_helper"

class AcmeAuthenticatorLifecycleAuthorityTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses, :client_secret_credential_kinds, :client_secret_credential_statuses,
           :client_totp_credential_statuses, :client_email_statuses, :client_google_identity_statuses,
           :client_apple_identity_statuses

  setup do
    @acme_host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    @sign_host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @client = Client.create!(status_id: ClientStatus::NOTHING, public_id: "acl_#{SecureRandom.hex(4)}")
    ClientEmail.create!(
      user: @client,
      address: "auth-lifecycle-#{SecureRandom.hex(4)}@example.com",
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
    @token = ClientToken.create!(user: @client, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    @token.update!(last_step_up_at: Time.current, last_step_up_scope: "settings_passkey")
    satisfy_user_verification(@token)

    @passkey = ClientPasskey.create!(
      user: @client,
      webauthn_id: "auth_lifecycle_passkey_#{SecureRandom.hex(4)}",
      public_key: "public_key_#{SecureRandom.hex(4)}",
      sign_count: 0,
      description: "Original Passkey",
    )
    @totp = ClientTotpCredential.create!(
      user: @client,
      private_key: ROTP::Base32.random_base32,
      last_otp_at: Time.zone.at(0),
      title: "Original TOTP",
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
    @secret_credential = ClientSecretCredential.create!(
      user: @client,
      name: "Original Secret",
      password_digest: "test_password_digest",
      user_secret_kind_id: ClientSecretCredentialKinds::LOGIN,
    )

    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
    CloudflareTurnstile.validation_override_enabled = true
    CloudflareTurnstile.validation_override_response = { "success" => true }
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
    CloudflareTurnstile.validation_override_enabled = false
    CloudflareTurnstile.validation_override_response = nil
  end

  test "acme passkey index renders lifecycle page with acme enrollment action" do
    get acme_app_settings_passkeys_url(ri: "jp", host: @acme_host), headers: app_headers(@acme_host)

    assert_response :success
    assert_includes response.body, "Original Passkey"
    assert_select "form[action=?][method=?]", enrollment_acme_app_settings_passkeys_path(ri: "jp"), "post"
  end

  test "acme passkey enrollment creates transaction and redirects to sign ceremony" do
    assert_difference -> { ClientPasskeyCeremonyTransaction.count }, 1 do
      post enrollment_acme_app_settings_passkeys_url(ri: "jp", host: @acme_host),
           headers: app_headers(@acme_host)
    end

    assert_response :see_other
    uri = URI.parse(response.location)

    assert_equal @sign_host, uri.host
    assert_equal "/settings/passkeys/new", uri.path
    assert URI.decode_www_form(uri.query).assoc("passkey_ceremony_grant")
  end

  test "acme passkey update mutates owner scoped metadata" do
    patch acme_app_settings_passkey_url(@passkey.public_id, ri: "jp", host: @acme_host),
          params: { client_passkey: { description: "Updated Passkey" } },
          headers: app_headers(@acme_host)

    assert_response :see_other
    assert_equal "Updated Passkey", @passkey.reload.description
  end

  test "sign passkey lifecycle update redirects to acme without local mutation" do
    patch sign_app_settings_passkey_url(@passkey.public_id, ri: "jp", host: @sign_host),
          params: { client_passkey: { description: "Sign Mutation" } },
          headers: app_headers(@sign_host)

    assert_response :see_other
    assert_equal "Original Passkey", @passkey.reload.description
    assert_equal @acme_host, URI.parse(response.location).host
    assert_equal "/settings/passkeys/#{@passkey.public_id}", URI.parse(response.location).path
  end

  test "sign passkey lifecycle delete redirects to acme without local mutation" do
    assert_no_difference -> { ClientPasskey.count } do
      delete sign_app_settings_passkey_url(@passkey.public_id, ri: "jp", host: @sign_host),
             headers: app_headers(@sign_host)
    end

    assert_response :see_other
    assert_equal @acme_host, URI.parse(response.location).host
  end

  test "acme app totp lifecycle update and delete own account record" do
    @token.update!(last_step_up_scope: "settings_totp")

    patch acme_app_settings_totp_url(@totp.public_id, ri: "jp", host: @acme_host),
          params: { user_totp_credential: { title: "Updated TOTP" } },
          headers: app_headers(@acme_host)

    assert_response :see_other
    assert_equal "Updated TOTP", @totp.reload.title

    assert_difference -> { ClientTotpCredential.count }, -1 do
      delete acme_app_settings_totp_url(@totp.public_id, ri: "jp", host: @acme_host),
             headers: app_headers(@acme_host)
    end
  end

  test "acme app totp enrollment creates transaction and redirects to sign ceremony" do
    @token.update!(last_step_up_scope: "settings_totp")

    assert_difference -> { ClientTotpCeremonyTransaction.count }, 1 do
      post enrollment_acme_app_settings_totps_url(ri: "jp", host: @acme_host),
           headers: app_headers(@acme_host)
    end

    assert_response :see_other
    uri = URI.parse(response.location)

    assert_equal @sign_host, uri.host
    assert_equal "/settings/totps/new", uri.path
    assert URI.decode_www_form(uri.query).assoc("totp_ceremony_grant")
  end

  test "sign app totp lifecycle index redirects to acme authority" do
    get sign_app_settings_totps_url(ri: "jp", host: @sign_host), headers: app_headers(@sign_host)

    assert_response :see_other
    assert_equal @acme_host, URI.parse(response.location).host
    assert_equal "/settings/totps", URI.parse(response.location).path
  end

  test "acme secret credential update mutates owner scoped metadata" do
    @token.update!(last_step_up_scope: "settings_secret_credential")

    patch acme_app_settings_secret_url(@secret_credential.public_id, ri: "jp", host: @acme_host),
          params: { user_secret_credential: { name: "Updated Secret", enabled: "1" } },
          headers: app_headers(@acme_host)

    assert_response :found
    assert_equal "Updated Secret", @secret_credential.reload.name
  end

  test "acme secret credential index renders enrollment action" do
    @token.update!(last_step_up_scope: "settings_secret_credential")

    get acme_app_settings_secrets_url(ri: "jp", host: @acme_host),
        headers: app_headers(@acme_host)

    assert_response :success
    assert_includes response.body, "Original Secret"
    assert_select "form[action=?][method=?]",
                  enrollment_acme_app_settings_secrets_path(ri: "jp"),
                  "post"
  end

  test "acme secret credential enrollment creates transaction and redirects to sign ceremony" do
    @token.update!(last_step_up_scope: "settings_secret_credential")

    assert_difference -> { ClientSecretCredentialCeremonyTransaction.count }, 1 do
      post enrollment_acme_app_settings_secrets_url(ri: "jp", host: @acme_host),
           headers: app_headers(@acme_host)
    end

    assert_response :see_other
    uri = URI.parse(response.location)

    assert_equal @sign_host, uri.host
    assert_equal "/settings/secret_credentials/new", uri.path
    assert URI.decode_www_form(uri.query).assoc("secret_credential_ceremony_grant")
  end

  test "sign secret credential lifecycle delete redirects to acme without local mutation" do
    assert_no_difference -> { ClientSecretCredential.count } do
      delete sign_app_settings_secret_credential_url(@secret_credential.public_id, ri: "jp", host: @sign_host),
             headers: app_headers(@sign_host)
    end

    assert_response :see_other
    assert_equal @acme_host, URI.parse(response.location).host
  end

  test "credential ceremony routes remain on sign" do
    assert_equal(
      { controller: "sign/app/settings/passkeys", action: "new" },
      recognize_sign_path("/settings/passkeys/new", method: :get),
    )
    assert_equal(
      { controller: "sign/app/settings/passkeys/options", action: "create" },
      recognize_sign_path("/settings/passkeys/options", method: :post),
    )
    assert_equal(
      { controller: "sign/app/settings/totps", action: "new" },
      recognize_sign_path("/settings/totps/new", method: :get),
    )
    assert_equal(
      { controller: "sign/app/settings/secret_credentials", action: "new" },
      recognize_sign_path("/settings/secret_credentials/new", method: :get),
    )
    assert_equal(
      { controller: "sign/app/settings/mfa/challenges", action: "show" },
      recognize_sign_path("/settings/mfa/challenge", method: :get),
    )
  end

  private

  def app_headers(host)
    {
      "Host" => host,
      "X-TEST-CURRENT-USER" => @client.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }
  end

  def recognize_sign_path(path, method:)
    Rails.application.routes.recognize_path("https://#{@sign_host}#{path}", method: method).except(:host)
  end

  def create_google_identity!(client, uid:)
    ClientGoogleIdentity.create!(
      user: client,
      uid: uid,
      provider: "google_app",
      token: "token-#{uid}",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )
  end

  def create_apple_identity!(client, uid:)
    ClientAppleIdentity.create!(
      user: client,
      uid: uid,
      provider: "apple",
      token: "token-#{uid}",
      expires_at: 1.week.from_now.to_i,
      user_apple_identity_status: client_apple_identity_statuses(:active),
    )
  end
end
