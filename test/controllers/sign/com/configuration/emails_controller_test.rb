# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::Configuration::EmailsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    @customer = create_verified_customer_with_email(
      email_address: "config-#{SecureRandom.hex(4)}@example.com",
    )
    @customer.customer_telephones.create!(
      number: "+15550001110",
      customer_telephone_status_id: CustomerTelephoneStatus::VERIFIED,
    )
    @headers = as_customer_headers(@customer, host: @host)
    @token = CustomerToken.find_by!(public_id: @headers["X-TEST-SESSION-PUBLIC-ID"])
    satisfy_customer_verification(@token)
  end

  test "should get index" do
    get sign_com_configuration_emails_url(ri: "jp"), headers: @headers

    assert_response :success
  end

  test "destroy removes email when not last method" do
    email = CustomerEmail.create!(
      customer: @customer,
      address: "delete-com@example.com",
      customer_email_status_id: CustomerEmailStatus::VERIFIED,
      confirm_policy: true,
    )

    assert_difference("CustomerEmail.count", -1) do
      delete sign_com_configuration_email_url(email, ri: "jp"), headers: @headers
    end

    assert_response :see_other
  end

  test "destroy blocks removing an undeletable email" do
    email = CustomerEmail.create!(
      customer: @customer,
      address: "protected-com@example.com",
      customer_email_status_id: CustomerEmailStatus::VERIFIED,
      confirm_policy: true,
      undeletable: true,
    )

    assert_no_difference("CustomerEmail.count") do
      delete sign_com_configuration_email_url(email, ri: "jp"), headers: @headers
    end

    assert_redirected_to sign_com_configuration_emails_url(ri: "jp")
    assert_equal I18n.t("sign.app.configuration.email.destroy.protected"), flash[:alert]
  end

  test "destroy blocks removing last email when telephone exists but no passkey or social" do
    customer = create_verified_customer_with_email(
      email_address: "last-method-#{SecureRandom.hex(4)}@example.com",
    )
    customer.customer_telephones.create!(
      number: "+15550001112",
      customer_telephone_status_id: CustomerTelephoneStatus::VERIFIED,
    )
    headers = as_customer_headers(customer, host: @host)
    token = CustomerToken.find_by!(public_id: headers["X-TEST-SESSION-PUBLIC-ID"])
    satisfy_customer_verification(token)
    email = customer.customer_emails.find_by!(
      customer_email_status_id: CustomerEmailStatus::VERIFIED,
    )

    assert_no_difference("CustomerEmail.count") do
      delete sign_com_configuration_email_url(email, ri: "jp"), headers: headers
    end

    assert_redirected_to sign_com_configuration_emails_url(ri: "jp")
    assert_equal I18n.t("sign.app.configuration.email.destroy.last_method"), flash[:alert]
  end
end
