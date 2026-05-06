# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class Sign::Com::VerificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    host! @host
    @customer = create_verified_customer_with_email(
      email_address: "com-verification-#{SecureRandom.hex(4)}@example.com",
    )
    @customer.customer_telephones.create!(
      number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
      customer_telephone_status_id: CustomerTelephoneStatus::VERIFIED,
    )
    @headers = as_customer_headers(@customer, host: @host)
  end

  test "should get show" do
    get sign_com_verification_url(ri: "jp"), headers: @headers

    assert_response :success
  end

  test "redirects to setup page when no verification methods are registered" do
    customer = Customer.create!(visibility_id: CustomerVisibility::CUSTOMER)
    customer.customer_telephones.create!(
      number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
      customer_telephone_status_id: CustomerTelephoneStatus::VERIFIED,
    )
    headers = as_customer_headers(customer, host: @host)

    get sign_com_verification_url(ri: "jp"), headers: headers

    assert_response :redirect
    uri = URI.parse(response.location)
    query = Rack::Utils.parse_query(uri.query)

    assert_equal "/verification/setup/new", uri.path
    assert_predicate query["rd"], :present?
  end

  test "show renders only email and passkey method links" do
    return_to = Base64.urlsafe_encode64(sign_com_configuration_emails_path(ri: "jp"))
    CustomerPasskey.create!(
      customer: @customer,
      webauthn_id: Base64.urlsafe_encode64("com_verification_passkey", padding: false),
      external_id: SecureRandom.uuid,
      public_key: "verification_key",
      description: "Verification Key",
      status_id: CustomerPasskeyStatus::ACTIVE,
    )

    get sign_com_verification_url(scope: "configuration_email", return_to: return_to, ri: "jp"),
        headers: @headers

    assert_response :success
    assert_includes response.body, new_sign_com_verification_email_path(ri: "jp")
    assert_includes response.body, new_sign_com_verification_passkey_path(ri: "jp")
    assert_not_includes response.body, "/verification/totp"
  end
end
