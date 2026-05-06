# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::Configuration::ChallengesControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    CustomerStatus.find_or_create_by!(id: CustomerStatus::ACTIVE)
    CustomerVisibility.find_or_create_by!(id: CustomerVisibility::CUSTOMER)
    CustomerEmailStatus.find_or_create_by!(id: CustomerEmailStatus::VERIFIED)
    CustomerTelephoneStatus.find_or_create_by!(id: CustomerTelephoneStatus::VERIFIED)
    CustomerTokenKind.find_or_create_by!(id: CustomerTokenKind::BROWSER_WEB)
    CustomerTokenBindingMethod.find_or_create_by!(id: CustomerTokenBindingMethod::NOTHING)
    CustomerTokenStatus.find_or_create_by!(id: CustomerTokenStatus::NOTHING)
    CustomerTokenDbscStatus.find_or_create_by!(id: CustomerTokenDbscStatus::NOTHING)
    CustomerPasskeyStatus.find_or_create_by!(id: CustomerPasskeyStatus::ACTIVE)
    CustomerSecretKind.find_or_create_by!(id: CustomerSecretKind::LOGIN)
    CustomerSecretStatus.find_or_create_by!(id: CustomerSecretStatus::ACTIVE)
    @customer = Customer.create!(
      status_id: CustomerStatus::ACTIVE,
      visibility_id: CustomerVisibility::CUSTOMER,
    )
    CustomerEmail.create!(
      customer: @customer,
      address: "com-mfa-#{SecureRandom.hex(4)}@example.com",
      customer_email_status_id: CustomerEmailStatus::VERIFIED,
      confirm_policy: "1",
    )
    @customer.customer_telephones.create!(
      number: "+819000000004",
      customer_telephone_status_id: CustomerTelephoneStatus::VERIFIED,
    )
    @token = CustomerToken.create!(
      customer: @customer,
      customer_token_kind_id: CustomerTokenKind::BROWSER_WEB,
      customer_token_binding_method_id: CustomerTokenBindingMethod::NOTHING,
      customer_token_status_id: CustomerTokenStatus::NOTHING,
      customer_token_dbsc_status_id: CustomerTokenDbscStatus::NOTHING,
    )
    satisfy_customer_verification(@token)
    @passkey = @customer.customer_passkeys.create!(
      webauthn_id: "challenge-passkey",
      public_key: "public-key",
      description: "Passkey",
      status_id: CustomerPasskeyStatus::ACTIVE,
    )
    @secret = @customer.customer_secrets.create!(
      name: "Recovery",
      password: "a" * 32,
      customer_secret_kind_id: CustomerSecretKind::LOGIN,
      customer_secret_status_id: CustomerSecretStatus::ACTIVE,
    )
  end

  def request_headers
    {
      "Host" => @host,
      "X-TEST-CURRENT-RESOURCE" => @customer.id,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }
  end

  test "show renders current passkeys and secrets" do
    get sign_com_configuration_challenge_url(ri: "jp"), headers: request_headers

    assert_response :success
    assert_includes response.body, "MFA settings"
  end

  test "update enables mfa" do
    patch sign_com_configuration_challenge_url(ri: "jp"),
          params: { user: { multi_factor_enabled: "1" } },
          headers: request_headers

    assert_redirected_to sign_com_configuration_challenge_url(ri: "jp")
    assert_predicate @customer.reload, :multi_factor_enabled?
  end
end
