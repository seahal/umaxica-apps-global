# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::App::CredentialRemovalConstraintsTest < ActionDispatch::IntegrationTest
  fixtures :client_statuses, :client_token_kinds, :client_email_statuses, :client_telephone_statuses,
           :client_secret_kinds, :client_secret_statuses, :client_one_time_password_statuses,
           :client_passkey_statuses

  setup do
    @host = ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
    host! @host
  end

  test "email removal preserves contactability even when aal methods remain" do
    client = Client.create!(status_id: ClientStatus::NOTHING)
    email = create_verified_email(client, "app-removal-contact-email@example.com")
    create_active_passkey(client)

    assert_no_difference("ClientEmail.count") do
      delete sign_app_configuration_email_url(email.public_id, ri: "jp"),
             headers: client_headers(client, scope: "configuration_email")
    end

    assert_redirected_to sign_app_configuration_emails_url(ri: "jp")
    assert_equal I18n.t("sign.app.configuration.email.destroy.last_method"), flash[:alert]
  end

  test "telephone removal preserves contactability even when aal methods remain" do
    client = Client.create!(status_id: ClientStatus::NOTHING)
    telephone = create_verified_telephone(client, "+819011110001")
    create_active_passkey(client)

    assert_no_difference("ClientTelephone.count") do
      delete sign_app_configuration_telephone_url(telephone.public_id, ri: "jp"),
             headers: client_headers(client, scope: "configuration_telephone")
    end

    assert_redirected_to sign_app_configuration_telephones_url(ri: "jp")
    assert_equal I18n.t("sign.app.configuration.telephone.destroy.last_method"), flash[:alert]
  end

  test "passkey removal preserves aal2 even when aal1 and contactability remain" do
    client = Client.create!(status_id: ClientStatus::NOTHING)
    create_verified_telephone(client, "+819011110002")
    create_active_secret(client)
    passkey = create_active_passkey(client)

    assert_no_difference("ClientPasskey.count") do
      delete sign_app_configuration_passkey_url(passkey.public_id, ri: "jp"),
             headers: client_headers(client, scope: "configuration_passkey")
    end

    assert_redirected_to sign_app_configuration_passkeys_url(ri: "jp")
    assert_equal I18n.t("messages.cannot_delete_last_passkey"), flash[:alert]
  end

  test "secret removal preserves aal1 even when aal2 and contactability remain" do
    client = Client.create!(status_id: ClientStatus::NOTHING)
    create_verified_telephone(client, "+819011110005")
    create_active_totp(client)
    secret = create_active_secret(client)

    assert_no_difference("ClientSecret.count") do
      delete sign_app_configuration_secret_url(secret.public_id, ri: "jp"),
             headers: client_browser_headers(client, scope: "configuration_secret")
    end

    assert_redirected_to sign_app_configuration_secrets_url(ri: "jp")
    assert_equal I18n.t("sign.app.configuration.secrets.destroy.last_method"), flash[:alert]
  end

  test "totp removal preserves aal2 even when aal1 and contactability remain" do
    client = Client.create!(status_id: ClientStatus::NOTHING)
    create_verified_telephone(client, "+819011110003")
    create_active_secret(client)
    totp = create_active_totp(client)

    assert_no_difference("ClientOneTimePassword.count") do
      delete sign_app_configuration_totp_url(totp.public_id, ri: "jp"),
             headers: client_headers(client, scope: "configuration_totp")
    end

    assert_redirected_to sign_app_configuration_totps_url(ri: "jp")
    assert_equal I18n.t("sign.app.configuration.totps.destroy.last_method"), flash[:alert]
  end

  test "totp removal is allowed when another aal2 method remains" do
    client = Client.create!(status_id: ClientStatus::NOTHING)
    create_verified_telephone(client, "+819011110004")
    create_active_secret(client)
    create_active_passkey(client)
    totp = create_active_totp(client)

    assert_difference("ClientOneTimePassword.count", -1) do
      delete sign_app_configuration_totp_url(totp.public_id, ri: "jp"),
             headers: client_headers(client, scope: "configuration_totp")
    end

    assert_redirected_to sign_app_configuration_totps_url(ri: "jp")
  end

  test "email removal is allowed when aal1 aal2 and contactability remain" do
    client = Client.create!(status_id: ClientStatus::NOTHING)
    email = create_verified_email(client, "app-removal-email-allowed@example.com")
    create_verified_telephone(client, "+819011110006")
    create_active_passkey(client)

    assert_difference("ClientEmail.count", -1) do
      delete sign_app_configuration_email_url(email.public_id, ri: "jp"),
             headers: client_headers(client, scope: "configuration_email")
    end

    assert_redirected_to sign_app_configuration_emails_url(ri: "jp")
  end

  test "telephone removal is allowed when contactability remains" do
    client = Client.create!(status_id: ClientStatus::NOTHING)
    telephone = create_verified_telephone(client, "+819011110007")
    create_verified_email(client, "app-removal-telephone-allowed@example.com")

    assert_difference("ClientTelephone.count", -1) do
      delete sign_app_configuration_telephone_url(telephone.public_id, ri: "jp"),
             headers: client_headers(client, scope: "configuration_telephone")
    end

    assert_redirected_to sign_app_configuration_telephones_url(ri: "jp")
  end

  test "passkey removal is allowed when another aal2 method remains" do
    client = Client.create!(status_id: ClientStatus::NOTHING)
    create_verified_email(client, "app-removal-passkey-allowed@example.com")
    passkey = create_active_passkey(client)

    assert_difference("ClientPasskey.count", -1) do
      delete sign_app_configuration_passkey_url(passkey.public_id, ri: "jp"),
             headers: client_headers(client, scope: "configuration_passkey")
    end

    assert_redirected_to sign_app_configuration_passkeys_url(ri: "jp")
  end

  test "secret removal is allowed when another aal1 method remains" do
    client = Client.create!(status_id: ClientStatus::NOTHING)
    create_verified_email(client, "app-removal-secret-allowed@example.com")
    secret = create_active_secret(client)

    assert_difference("ClientSecret.count", -1) do
      delete sign_app_configuration_secret_url(secret.public_id, ri: "jp"),
             headers: client_browser_headers(client, scope: "configuration_secret")
    end

    assert_redirected_to sign_app_configuration_secrets_url(ri: "jp")
  end

  private

  def client_headers(client, scope:)
    token = ClientToken.create!(user: client, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    satisfy_user_verification(token)
    token.update!(last_step_up_at: Time.current, last_step_up_scope: scope)

    as_user_headers(client, host: @host, session_public_id: token.public_id)
  end

  def client_browser_headers(client, scope:)
    token = ClientToken.create!(user: client, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    satisfy_user_verification(token)
    token.update!(last_step_up_at: Time.current, last_step_up_scope: scope)

    headers = browser_headers.merge(
      "Host" => @host,
      "X-TEST-CURRENT-USER" => client.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    )
    verification_token = cookies[ClientVerification.cookie_name]
    headers["Cookie"] = "#{headers["Cookie"]}; #{ClientVerification.cookie_name}=#{verification_token}"
    headers
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

  def create_active_secret(client)
    ClientSecret.create!(
      user: client,
      name: "Removal guard secret",
      password_digest: "digest",
      user_secret_kind_id: ClientSecret::Kinds::LOGIN,
      user_identity_secret_status_id: ClientSecretStatus::ACTIVE,
    )
  end

  def create_active_totp(client)
    ClientOneTimePassword.create!(
      user: client,
      private_key: ROTP::Base32.random_base32,
      last_otp_at: Time.zone.at(0),
      user_one_time_password_status_id: ClientOneTimePasswordStatus::ACTIVE,
    )
  end
end
