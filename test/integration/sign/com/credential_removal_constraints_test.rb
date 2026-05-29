# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::CredentialRemovalConstraintsTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    host! @host
    Prosopite.pause do
      VisitorStatus.find_or_create_by!(id: VisitorStatus::ACTIVE)
      VisitorVisibility.find_or_create_by!(id: VisitorVisibility::VISITOR)
      VisitorEmailStatus.find_or_create_by!(id: VisitorEmailStatus::VERIFIED)
      VisitorTelephoneStatus.find_or_create_by!(id: VisitorTelephoneStatus::VERIFIED)
      VisitorPasskeyStatus.find_or_create_by!(id: VisitorPasskeyStatus::ACTIVE)
      VisitorSecretKind.find_or_create_by!(id: VisitorSecretKind::LOGIN)
      VisitorSecretStatus.find_or_create_by!(id: VisitorSecretStatus::ACTIVE)
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
      delete sign_com_configuration_email_url(email.public_id, ri: "jp"),
             headers: visitor_headers(visitor, scope: "configuration_email")
    end

    assert_redirected_to sign_com_configuration_emails_url(ri: "jp")
    assert_equal I18n.t("sign.app.configuration.email.destroy.last_method"), flash[:alert]
  end

  test "telephone removal preserves contactability even when aal methods remain" do
    visitor = create_visitor
    telephone = create_verified_telephone(visitor, "+819022220001")
    create_active_passkey(visitor)

    assert_no_difference("VisitorTelephone.count") do
      delete sign_com_configuration_telephone_url(telephone.public_id, ri: "jp"),
             headers: visitor_headers(visitor, scope: "configuration_telephone")
    end

    assert_redirected_to sign_com_configuration_telephones_url(ri: "jp")
    assert_equal I18n.t("sign.app.configuration.telephone.destroy.last_method"), flash[:alert]
  end

  test "passkey removal preserves aal2 when only secret remains for aal1" do
    visitor = create_visitor
    create_verified_telephone(visitor, "+819022220002")
    create_active_secret(visitor)
    passkey = create_active_passkey(visitor)

    assert_no_difference("VisitorPasskey.count") do
      delete sign_com_configuration_passkey_url(passkey.public_id, ri: "jp"),
             headers: visitor_headers(visitor, scope: "configuration_passkey")
    end

    assert_redirected_to sign_com_configuration_passkeys_url(ri: "jp")
    assert_equal I18n.t("messages.cannot_delete_last_passkey"), flash[:alert]
  end

  test "secret removal preserves aal1 when passkey does not remain" do
    visitor = create_visitor
    create_verified_telephone(visitor, "+819022220003")
    secret = create_active_secret(visitor)

    assert_no_difference("VisitorSecret.where(visitor_secret_status_id: VisitorSecretStatus::ACTIVE).count") do
      delete sign_com_configuration_secret_url(secret.public_id, ri: "jp"),
             headers: visitor_headers(visitor, scope: "configuration_secret")
    end

    assert_redirected_to sign_com_configuration_secrets_url(ri: "jp")
    assert_equal I18n.t("sign.app.configuration.secrets.destroy.last_method"), flash[:alert]
  end

  test "email and passkey removals are allowed when all dimensions remain" do
    visitor = create_visitor
    email = create_verified_email(visitor, "com-removal-email-allowed@example.com")
    create_verified_telephone(visitor, "+819022220004")
    passkey = create_active_passkey(visitor)
    create_active_passkey(visitor)

    assert_difference("VisitorEmail.count", -1) do
      delete sign_com_configuration_email_url(email.public_id, ri: "jp"),
             headers: visitor_headers(visitor, scope: "configuration_email")
    end

    assert_difference("VisitorPasskey.count", -1) do
      delete sign_com_configuration_passkey_url(passkey.public_id, ri: "jp"),
             headers: visitor_headers(visitor, scope: "configuration_passkey")
    end
  end

  private

  def create_visitor
    Visitor.create!(
      status_id: VisitorStatus::ACTIVE,
      visibility_id: VisitorVisibility::VISITOR,
    )
  end

  def visitor_headers(visitor, scope:)
    headers = as_visitor_headers(visitor, host: @host)
    token = VisitorToken.find_by!(public_id: headers["X-TEST-SESSION-PUBLIC-ID"])
    satisfy_visitor_verification(token)
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    headers
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

  def create_active_secret(visitor)
    VisitorSecret.create!(
      visitor: visitor,
      name: "Removal guard secret",
      password: "a" * 32,
      visitor_secret_kind_id: VisitorSecretKind::LOGIN,
      visitor_secret_status_id: VisitorSecretStatus::ACTIVE,
    )
  end
end
