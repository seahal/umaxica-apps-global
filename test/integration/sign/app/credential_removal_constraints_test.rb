# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::CredentialRemovalConstraintsTest < ActionDispatch::IntegrationTest
  fixtures :client_statuses, :client_token_kinds, :client_token_statuses, :client_email_statuses,
           :client_telephone_statuses, :client_secret_credential_kinds, :client_secret_credential_statuses,
           :client_totp_credential_statuses, :client_passkey_statuses

  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    @acme_host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    host! @host
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  test "email removal preserves contactability even when aal methods remain" do
    client = Client.create!(status_id: ClientStatus::NOTHING)
    email = create_verified_email(client, "app-removal-contact-email@example.com")
    create_active_passkey(client)

    assert_no_difference("ClientEmail.count") do
      delete acme_app_settings_email_url(email.public_id, ri: "jp", host: @acme_host),
             headers: client_headers(client, scope: "settings_email", host: @acme_host)
    end

    assert_redirected_to acme_app_settings_emails_url(ri: "jp", host: @acme_host)
    assert_equal I18n.t("sign.app.settings.email.destroy.last_method"), flash[:alert]
  end

  test "telephone removal preserves contactability even when aal methods remain" do
    client = Client.create!(status_id: ClientStatus::NOTHING)
    telephone = create_verified_telephone(client, "+819011110001")
    create_active_passkey(client)

    assert_no_difference("ClientTelephone.count") do
      delete acme_app_settings_telephone_url(telephone.public_id, ri: "jp", host: @acme_host),
             headers: client_headers(client, scope: "settings_telephone", host: @acme_host)
    end

    assert_redirected_to acme_app_settings_telephones_url(ri: "jp", host: @acme_host)
    assert_equal I18n.t("sign.app.settings.telephone.destroy.last_method"), flash[:alert]
  end

  test "passkey removal preserves aal2 even when aal1 and contactability remain" do
    client = Client.create!(status_id: ClientStatus::NOTHING)
    create_verified_telephone(client, "+819011110002")
    create_active_secret_credential(client)
    passkey = create_active_passkey(client)

    assert_no_difference("ClientPasskey.count") do
      delete acme_app_settings_passkey_url(passkey.public_id, ri: "jp", host: @acme_host),
             headers: client_headers(client, scope: "settings_passkey", host: @acme_host)
    end

    assert_redirected_to acme_app_settings_passkeys_url(ri: "jp", host: @acme_host)
    assert_equal I18n.t("messages.cannot_delete_last_passkey"), flash[:alert]
  end

  test "secret_credential removal preserves aal1 even when aal2 and contactability remain" do
    client = Client.create!(status_id: ClientStatus::NOTHING)
    create_verified_telephone(client, "+819011110005")
    create_active_totp(client)
    secret_credential = create_active_secret_credential(client)

    assert_no_difference("ClientSecretCredential.count") do
      delete acme_app_settings_secret_credential_url(secret_credential.public_id, ri: "jp", host: @acme_host),
             headers: client_browser_headers(client, scope: "settings_secret_credential", host: @acme_host)
    end

    assert_redirected_to acme_app_settings_secret_credentials_url(ri: "jp", host: @acme_host)
    assert_equal I18n.t("sign.app.settings.secret_credentials.destroy.last_method"), flash[:alert]
  end

  test "totp removal preserves aal2 even when aal1 and contactability remain" do
    client = Client.create!(status_id: ClientStatus::NOTHING)
    create_verified_telephone(client, "+819011110003")
    create_active_secret_credential(client)
    totp = create_active_totp(client)

    assert_no_difference("ClientTotpCredential.count") do
      delete acme_app_settings_totp_url(totp.public_id, ri: "jp", host: @acme_host),
             headers: client_headers(client, scope: "settings_totp", host: @acme_host)
    end

    assert_redirected_to acme_app_settings_totps_url(ri: "jp", host: @acme_host)
    assert_equal I18n.t("sign.app.settings.totps.destroy.last_method"), flash[:alert]
  end

  test "totp removal is allowed when another aal2 method remains" do
    client = Client.create!(status_id: ClientStatus::NOTHING)
    create_verified_telephone(client, "+819011110004")
    create_active_secret_credential(client)
    create_active_passkey(client)
    totp = create_active_totp(client)

    assert_difference("ClientTotpCredential.count", -1) do
      delete acme_app_settings_totp_url(totp.public_id, ri: "jp", host: @acme_host),
             headers: client_headers(client, scope: "settings_totp", host: @acme_host)
    end

    assert_redirected_to acme_app_settings_totps_url(ri: "jp", host: @acme_host)
  end

  test "email removal is allowed when aal1 aal2 and contactability remain" do
    client = Client.create!(status_id: ClientStatus::NOTHING)
    email = create_verified_email(client, "app-removal-email-allowed@example.com")
    create_verified_telephone(client, "+819011110006")
    create_active_passkey(client)

    assert_difference("ClientEmail.count", -1) do
      delete acme_app_settings_email_url(email.public_id, ri: "jp", host: @acme_host),
             headers: client_headers(client, scope: "settings_email", host: @acme_host)
    end

    assert_redirected_to acme_app_settings_emails_url(ri: "jp", host: @acme_host)
  end

  test "telephone removal is allowed when contactability remains" do
    client = Client.create!(status_id: ClientStatus::NOTHING)
    telephone = create_verified_telephone(client, "+819011110007")
    create_verified_email(client, "app-removal-telephone-allowed@example.com")

    assert_difference("ClientTelephone.count", -1) do
      delete acme_app_settings_telephone_url(telephone.public_id, ri: "jp", host: @acme_host),
             headers: client_headers(client, scope: "settings_telephone", host: @acme_host)
    end

    assert_redirected_to acme_app_settings_telephones_url(ri: "jp", host: @acme_host)
  end

  test "passkey removal is allowed when another aal2 method remains" do
    client = Client.create!(status_id: ClientStatus::NOTHING)
    create_verified_email(client, "app-removal-passkey-allowed@example.com")
    passkey = create_active_passkey(client)

    assert_difference("ClientPasskey.count", -1) do
      delete acme_app_settings_passkey_url(passkey.public_id, ri: "jp", host: @acme_host),
             headers: client_headers(client, scope: "settings_passkey", host: @acme_host)
    end

    assert_redirected_to acme_app_settings_passkeys_url(ri: "jp", host: @acme_host)
  end

  test "secret_credential removal is allowed when another aal1 method remains" do
    client = Client.create!(status_id: ClientStatus::NOTHING)
    create_verified_email(client, "app-removal-secret_credential-allowed@example.com")
    secret_credential = create_active_secret_credential(client)

    delete acme_app_settings_secret_credential_url(secret_credential.public_id, ri: "jp", host: @acme_host),
           headers: client_browser_headers(client, scope: "settings_secret_credential", host: @acme_host)

    assert_redirected_to acme_app_settings_secret_credentials_url(ri: "jp", host: @acme_host)
    # ClientSecretCredentialsDestroy soft-deletes via discard_now! — count does not change.
    # Assert the credential is logically deleted instead.
    assert_predicate secret_credential.reload, :lapsed?
  end

  # Regression guard: destroying a credential must revoke ALL existing sessions so that
  # an attacker holding a stolen token loses access immediately on the next request.
  test "destroying a secret credential revokes all existing client tokens" do
    client = Client.create!(status_id: ClientStatus::NOTHING)
    create_verified_email(client, "revoke-all-sessions-#{SecureRandom.hex(4)}@example.com")
    secret_credential = create_active_secret_credential(client)

    # Create the session token first so the session limit is not exceeded by the extra token.
    headers = client_browser_headers(client, scope: "settings_secret_credential", host: @acme_host)

    # Represents an attacker's stolen session that should be cut off after credential change.
    stolen_token = ClientToken.new(
      user: client, user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    stolen_token.send(:skip_session_limit_check=, true)
    stolen_token.save!

    delete acme_app_settings_secret_credential_url(secret_credential.public_id, ri: "jp", host: @acme_host),
           headers: headers

    assert_redirected_to acme_app_settings_secret_credentials_url(ri: "jp", host: @acme_host)
    assert_predicate stolen_token.reload, :revoked?
  end

  private

  def client_headers(client, scope:, host: @host)
    token = ClientToken.new(
      user: client,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      user_token_status_id: ClientTokenStatus::ACTIVE,
    )
    token.send(:skip_session_limit_check=, true)
    token.save!
    satisfy_user_verification(token)
    mark_token_step_up_satisfied_for_test(token, scope: scope)

    {
      "Host" => host,
      "X-TEST-CURRENT-USER" => client.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
  end

  def client_browser_headers(client, scope:, host: @host)
    token = ClientToken.create!(user: client, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    satisfy_user_verification(token)
    mark_token_step_up_satisfied_for_test(token, scope: scope)

    headers = browser_headers.merge(
      "Host" => @host,
      "X-TEST-CURRENT-USER" => client.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    )
    csrf_token = cookies["csrf_token"]
    verification_token = cookies[ClientVerification.cookie_name]
    headers["Cookie"] = [
      headers["Cookie"],
      ("csrf_token=#{csrf_token}" if csrf_token.present?),
      "#{ClientVerification.cookie_name}=#{verification_token}",
    ]
      .compact_blank
      .join("; ")
    headers
      .merge("Host" => host)
  end

  def create_verified_email(client, address)
    ClientEmail.create!(
      user: client,
      address: address,
      user_email_status_id: ClientEmailStatus::VERIFIED,
    )
  end

  def create_verified_telephone(client, number)
    ClientTelephone.create!(
      user: client,
      number: number,
      user_identity_telephone_status_id: ClientTelephoneStatus::VERIFIED,
    )
  end

  def create_active_passkey(client)
    passkey = client.client_passkeys.new(
      webauthn_id: "removal_guard_passkey_#{SecureRandom.hex(8)}",
      external_id: SecureRandom.uuid,
      public_key: "public_key_#{SecureRandom.hex(8)}",
      sign_count: 0,
      description: "Removal guard passkey",
      status_id: ClientPasskeyStatus::ACTIVE,
    )
    passkey.save!(validate: false)
    passkey
  end

  def create_active_secret_credential(client)
    ClientSecretCredential.create!(
      user: client,
      name: "Removal guard secret_credential",
      password_digest: "digest",
      user_secret_kind_id: ClientSecretCredentialKinds::LOGIN,
      user_identity_secret_status_id: ClientSecretCredentialStatus::ACTIVE,
    )
  end

  def create_active_totp(client)
    ClientTotpCredential.create!(
      user: client,
      private_key: ROTP::Base32.random_base32,
      last_otp_at: Time.zone.at(0),
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
    )
  end
end
