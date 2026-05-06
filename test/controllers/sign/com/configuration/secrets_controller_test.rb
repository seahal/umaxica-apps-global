# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::Configuration::SecretsControllerTest < ActionDispatch::IntegrationTest
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
    CustomerSecretKind.find_or_create_by!(id: CustomerSecretKind::LOGIN)
    CustomerSecretStatus.find_or_create_by!(id: CustomerSecretStatus::ACTIVE)
    @customer = Customer.create!(
      status_id: CustomerStatus::ACTIVE,
      visibility_id: CustomerVisibility::CUSTOMER,
    )
    CustomerEmail.create!(
      customer: @customer,
      address: "com-secret-#{SecureRandom.hex(4)}@example.com",
      customer_email_status_id: CustomerEmailStatus::VERIFIED,
      confirm_policy: "1",
    )
    @customer.customer_telephones.create!(
      number: "+819000000001",
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

    @secret = CustomerSecret.create!(
      customer: @customer,
      name: "Login Secret",
      password: "a" * 32,
      customer_secret_kind_id: CustomerSecretKind::LOGIN,
      customer_secret_status_id: CustomerSecretStatus::ACTIVE,
      last_used_at: Time.current,
    )
  end

  def request_headers
    {
      "Host" => @host,
      "X-TEST-CURRENT-RESOURCE" => @customer.id,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }
  end

  test "index show new edit and access by public id" do
    get sign_com_configuration_secrets_url(ri: "jp"), headers: request_headers

    assert_response :success

    get sign_com_configuration_secret_url(@secret.public_id, ri: "jp"), headers: request_headers

    assert_response :success

    get new_sign_com_configuration_secret_url(ri: "jp"), headers: request_headers

    assert_response :success

    get edit_sign_com_configuration_secret_url(@secret.public_id, ri: "jp"), headers: request_headers

    assert_response :success
  end

  test "ensure_verified_recovery_identity_for_registration! renders forbidden " \
       "plain text when recovery identity is missing" do
    controller = Sign::Com::Configuration::SecretsController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.instance_variable_set(:@_response, ActionDispatch::Response.new)
    controller.define_singleton_method(:current_customer) { Customer.new }

    controller.send(:ensure_verified_recovery_identity_for_registration!)

    assert_equal 403, controller.response.status
    assert_includes controller.response.body, Customer::RECOVERY_IDENTITY_REQUIRED_MESSAGE
  end

  test "create persists secret and redirects" do
    get new_sign_com_configuration_secret_url(ri: "jp"), headers: request_headers

    assert_difference("CustomerSecret.count", 1) do
      post sign_com_configuration_secrets_url(ri: "jp"),
           params: { customer_secret: { name: "New Secret", enabled: true } },
           headers: request_headers
    end

    assert_redirected_to sign_com_configuration_secrets_url(ri: "jp")
    assert_predicate flash[:notice], :present?
  end

  test "destroy redirects when last recovery method would be removed" do
    AuthMethodGuard.stub(:last_method?, true) do
      delete sign_com_configuration_secret_url(@secret.public_id, ri: "jp"), headers: request_headers
    end

    assert_redirected_to sign_com_configuration_secrets_url(ri: "jp")
    assert_predicate flash[:alert], :present?
  end

  test "destroy removes secret and regenerate is not implemented" do
    customer = create_verified_customer_with_email(email_address: "com-secret-allow-#{SecureRandom.hex(4)}@example.com")
    customer.customer_telephones.create!(
      number: "+819000000002",
      customer_telephone_status_id: CustomerTelephoneStatus::VERIFIED,
    )
    token = CustomerToken.create!(customer: customer, customer_token_kind_id: CustomerTokenKind::BROWSER_WEB)
    satisfy_customer_verification(token)
    secret = CustomerSecret.create!(
      customer: customer,
      name: "Destroy Secret",
      password: "a" * 32,
      customer_secret_kind_id: CustomerSecretKind::LOGIN,
      customer_secret_status_id: CustomerSecretStatus::ACTIVE,
    )

    UserSecrets::Destroy.stub(:call, true) do
      delete sign_com_configuration_secret_url(secret.public_id, ri: "jp"),
             headers: {
               "Host" => @host,
               "X-TEST-CURRENT-RESOURCE" => customer.id,
               "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
             }
    end

    assert_response :see_other

    I18n.backend.store_translations(:ja, messages: { not_implemented: "Not implemented" })
    post regenerate_sign_com_configuration_secret_url(secret.public_id, ri: "jp"), headers: {
      "Host" => @host,
      "X-TEST-CURRENT-RESOURCE" => customer.id,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    assert_response :see_other
    assert_equal I18n.t("messages.not_implemented"), flash[:alert]
  end
end
