# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::Configuration::TotpsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    host! @host
    @customer = create_verified_customer_with_email(email_address: "com-totp-#{SecureRandom.hex(4)}@example.com")
    @customer.customer_telephones.create!(
      number: "+819055555555",
      customer_telephone_status_id: CustomerTelephoneStatus::VERIFIED,
    )
    @token = CustomerToken.create!(customer: @customer, customer_token_kind_id: CustomerTokenKind::BROWSER_WEB)
    satisfy_customer_verification(@token)
    @headers = as_customer_headers(@customer, host: @host).merge("X-TEST-SESSION-PUBLIC-ID" => @token.public_id)
  end

  test "redirects index because totp is unavailable" do
    get sign_com_configuration_totps_path(ri: "jp"), headers: @headers

    assert_response :see_other
    assert_redirected_to sign_com_configuration_path(ri: "jp")
  end

  test "redirects create because totp is unavailable" do
    post sign_com_configuration_totps_path(ri: "jp"),
         params: { user_one_time_password: { first_token: "123456" } },
         headers: @headers

    assert_response :see_other
    assert_redirected_to sign_com_configuration_path(ri: "jp")
  end
end
