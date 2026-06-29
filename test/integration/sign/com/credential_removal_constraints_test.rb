# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class SignComCredentialRemovalConstraintsTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PRIVATE_AUTH_CORPORATE_URL", "sign.com.localhost")
    @acme_host = ENV.fetch("PRIVATE_ACME_CORPORATE_URL", "www.com.localhost")
    host! @host
    Prosopite.pause do
      VisitorStatus.find_or_create_by!(id: VisitorStatus::ACTIVE)
      VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
      VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
      VisitorTelephoneStatus.find_or_create_by!(id: VisitorTelephoneStatus::VERIFIED)
      VisitorPasskeyStatus.find_or_create_by!(id: VisitorPasskeyStatus::ACTIVE)
      VisitorSecretCredentialKind.find_or_create_by!(id: VisitorSecretCredentialKind::LOGIN)
      VisitorSecretCredentialStatus.find_or_create_by!(id: VisitorSecretCredentialStatus::ACTIVE)
      VisitorTokenKind.find_or_create_by!(id: VisitorTokenKind::BROWSER_WEB)
      VisitorTokenBindingMethod.find_or_create_by!(id: VisitorTokenBindingMethod::NOTHING)
      VisitorTokenStatus.ensure_defaults!
      VisitorTokenDbscStatus.find_or_create_by!(id: VisitorTokenDbscStatus::NOTHING)
    end
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  test "email removal preserves aal methods when contactability remains" do
    visitor = create_visitor
    email = create_verified_email(visitor, "com-removal-contact-email@example.com")
    create_verified_telephone(visitor, "+819022220000")

    assert_no_difference("VisitorEmail.count") do
      delete auth_com_settings_email_url(email.public_id, ri: "jp", host: @host),
             headers: visitor_headers(visitor, scope: "settings_email", host: @host)
    end

    assert_redirected_to auth_com_settings_emails_url(ri: "jp", host: @host)
    assert_equal I18n.t("sign.app.settings.email.destroy.last_method"), flash[:alert]
  end

  test "telephone removal preserves contactability even when aal methods remain" do
    visitor = create_visitor
    telephone = create_verified_telephone(visitor, "+819022220001")
    create_active_passkey(visitor)

    assert_no_difference("VisitorTelephone.count") do
      delete auth_com_settings_telephone_url(telephone.public_id, ri: "jp", host: @host),
             headers: visitor_headers(visitor, scope: "settings_telephone", host: @host)
    end

    assert_redirected_to auth_com_settings_telephones_url(ri: "jp", host: @host)
    assert_equal I18n.t("sign.app.settings.telephone.destroy.last_method"), flash[:alert]
  end

  test "passkey removal preserves aal2 when only secret_credential remains for aal1" do
    visitor = create_visitor
    create_verified_telephone(visitor, "+819022220002")
    create_active_secret_credential(visitor)
    passkey = create_active_passkey(visitor)

    assert_no_difference("VisitorPasskey.count") do
      delete auth_com_settings_passkey_url(passkey.public_id, ri: "jp", host: @host),
             headers: visitor_headers(visitor, scope: "settings_passkey", host: @host)
    end

    assert_redirected_to auth_com_settings_passkeys_url(ri: "jp", host: @host)
    assert_equal I18n.t("messages.cannot_delete_last_passkey"), flash[:alert]
  end

  test "secret_credential removal preserves aal1 when passkey does not remain" do
    visitor = create_visitor
    create_verified_telephone(visitor, "+819022220003")
    secret_credential = create_active_secret_credential(visitor)

    assert_no_difference(
      "VisitorSecretCredential.where(visitor_secret_credential_status_id: VisitorSecretCredentialStatus::ACTIVE).count",
    ) do
      delete auth_com_settings_secret_credential_url(secret_credential.public_id, ri: "jp", host: @host),
             headers: visitor_headers(visitor, scope: "settings_secret_credential", host: @host)
    end

    assert_redirected_to auth_com_settings_secret_credentials_url(ri: "jp", host: @host)
    assert_equal I18n.t("sign.app.settings.secret_credentials.destroy.last_method"), flash[:alert]
  end

  test "email and passkey removals are allowed when all dimensions remain" do
    visitor = create_visitor
    email = create_verified_email(visitor, "com-removal-email-allowed@example.com")
    create_verified_telephone(visitor, "+819022220004")
    passkey = create_active_passkey(visitor)
    create_active_passkey(visitor)

    assert_difference("VisitorEmail.count", -1) do
      delete auth_com_settings_email_url(email.public_id, ri: "jp", host: @host),
             headers: visitor_headers(visitor, scope: "settings_email", host: @host)
    end

    assert_difference("VisitorPasskey.count", -1) do
      delete auth_com_settings_passkey_url(passkey.public_id, ri: "jp", host: @host),
             headers: visitor_headers(visitor, scope: "settings_passkey", host: @host)
    end
  end

  private

  def create_visitor
    Visitor.create!(
      status_id: VisitorStatus::ACTIVE,
      visibility_id: VisitorVisibility::VISITOR,
    )
  end

  def visitor_headers(visitor, scope:, host: @host)
    token = VisitorToken.create!(visitor: visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    satisfy_visitor_verification(token)
    mark_token_step_up_satisfied_for_test(token, scope: scope)

    {
      "Host" => host,
      "X-TEST-CURRENT-RESOURCE" => visitor.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
  end

  def create_verified_email(visitor, address)
    VisitorEmail.create!(
      visitor: visitor,
      address: address,
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      confirm_policy: true,
    )
  end

  def create_verified_telephone(visitor, number)
    VisitorTelephone.create!(
      visitor: visitor,
      number: number,
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
  end

  def create_active_passkey(visitor)
    VisitorPasskey.create!(
      visitor: visitor,
      webauthn_id: "com_removal_passkey_#{SecureRandom.hex(8)}",
      public_key: "public_key_#{SecureRandom.hex(8)}",
      sign_count: 0,
      description: "Removal guard passkey",
      status_id: VisitorPasskeyStatus::ACTIVE,
    )
  end

  def create_active_secret_credential(visitor)
    VisitorSecretCredential.create!(
      visitor: visitor,
      name: "Removal guard secret_credential",
      password: "a" * 32,
      visitor_secret_credential_kind_id: VisitorSecretCredentialKind::LOGIN,
      visitor_secret_credential_status_id: VisitorSecretCredentialStatus::ACTIVE,
    )
  end
end
