# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::CredentialRemovalConstraintsTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    host! @host
    CloudflareTurnstile.test_mode = true
    CloudflareTurnstile.test_validation_response = { "success" => true }
  end

  teardown do
    CloudflareTurnstile.test_mode = false
    CloudflareTurnstile.test_validation_response = nil
  end

  test "email removal preserves contactability even when aal methods remain" do
    operator = create_operator
    email = create_verified_email(operator, "org-removal-contact-email@example.com")
    create_active_passkey(operator)
    create_active_secret_credential(operator)

    assert_no_difference("OperatorEmail.count") do
      delete sign_org_settings_email_url(email.public_id, ri: "jp"),
             headers: operator_headers(operator, scope: "settings_email")
    end

    assert_redirected_to sign_org_settings_emails_url(ri: "jp")
    assert_equal I18n.t("sign.org.settings.email.destroy.last_method"), flash[:alert]
  end

  test "telephone removal preserves contactability even when aal methods remain" do
    operator = create_operator
    telephone = create_verified_telephone(operator, "+819033330001")
    create_active_passkey(operator)
    create_active_secret_credential(operator)

    assert_no_difference("OperatorTelephone.count") do
      delete sign_org_settings_telephone_url(telephone.id, ri: "jp"),
             headers: operator_headers(operator, scope: "settings_telephone")
    end

    assert_redirected_to sign_org_settings_telephones_url(ri: "jp")
    assert_equal I18n.t("sign.org.settings.telephone.destroy.last_method"), flash[:alert]
  end

  test "passkey removal preserves aal2" do
    operator = create_operator
    create_verified_telephone(operator, "+819033330002")
    create_active_secret_credential(operator)
    passkey = create_active_passkey(operator)

    assert_no_difference("OperatorPasskey.count") do
      delete sign_org_settings_passkey_url(passkey, ri: "jp"),
             headers: operator_headers(operator, scope: "settings_passkey")
    end

    assert_redirected_to sign_org_settings_passkeys_url(ri: "jp")
    assert_equal I18n.t("messages.cannot_delete_last_passkey"), flash[:alert]
  end

  test "secret_credential removal preserves aal1" do
    operator = create_operator
    create_verified_telephone(operator, "+819033330003")
    secret_credential = create_active_secret_credential(operator)

    assert_no_difference("OperatorSecretCredential.count") do
      delete sign_org_settings_secret_credential_url(secret_credential.public_id, ri: "jp"),
             headers: operator_headers(operator, scope: "settings_secret_credential")
    end

    assert_redirected_to sign_org_settings_secret_credentials_url(ri: "jp")
    assert_equal I18n.t("sign.org.settings.secret_credentials.destroy.last_method"), flash[:alert]
  end

  test "email telephone passkey and secret_credential removals are allowed when dimensions remain" do
    operator = create_operator
    email = create_verified_email(operator, "org-removal-email-allowed@example.com")
    create_verified_telephone(operator, "+819033330004")
    telephone = create_verified_telephone(operator, "+819033330005")
    passkey = create_active_passkey(operator)
    create_active_passkey(operator)
    secret_credential = create_active_secret_credential(operator)
    create_active_secret_credential(operator)

    assert_difference("OperatorEmail.count", -1) do
      delete sign_org_settings_email_url(email.public_id, ri: "jp"),
             headers: operator_headers(operator, scope: "settings_email")
    end

    assert_difference("OperatorTelephone.count", -1) do
      delete sign_org_settings_telephone_url(telephone.id, ri: "jp"),
             headers: operator_headers(operator, scope: "settings_telephone")
    end

    assert_difference("OperatorPasskey.count", -1) do
      delete sign_org_settings_passkey_url(passkey, ri: "jp"),
             headers: operator_headers(operator, scope: "settings_passkey")
    end

    assert_difference("OperatorSecretCredential.count", -1) do
      delete sign_org_settings_secret_credential_url(secret_credential.public_id, ri: "jp"),
             headers: operator_headers(operator, scope: "settings_secret_credential")
    end
  end

  private

  def create_operator
    Operator.create!(status_id: OperatorStatus::ACTIVE)
  end

  def operator_headers(operator, scope:)
    token = OperatorToken.where(staff: operator).first ||
      OperatorToken.create!(staff: operator, staff_token_status_id: OperatorTokenStatus::ACTIVE)
    satisfy_staff_verification(token)
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    {
      "Host" => @host,
      "X-TEST-CURRENT-STAFF" => operator.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
  end

  def create_verified_email(operator, address)
    OperatorEmail.create!(
      staff: operator,
      address: address,
      staff_email_status_id: OperatorEmailStatus::VERIFIED,
    )
  end

  def create_verified_telephone(operator, number)
    OperatorTelephone.create!(
      staff: operator,
      number: number,
      staff_telephone_status_id: OperatorTelephoneStatus::VERIFIED,
    )
  end

  def create_active_passkey(operator)
    OperatorPasskey.create!(
      staff: operator,
      webauthn_id: "org_removal_passkey_#{SecureRandom.hex(8)}",
      external_id: SecureRandom.uuid,
      public_key: "public_key_#{SecureRandom.hex(8)}",
      name: "Removal guard passkey",
      status_id: OperatorPasskeyStatus::ACTIVE,
    )
  end

  def create_active_secret_credential(operator)
    OperatorSecretCredential.create!(
      staff: operator,
      name: "Removal guard secret_credential",
      password_digest: "digest",
      staff_secret_kind_id: OperatorSecretCredentialKind::LOGIN,
      staff_secret_status_id: OperatorSecretCredentialStatus::ACTIVE,
    )
  end
end
