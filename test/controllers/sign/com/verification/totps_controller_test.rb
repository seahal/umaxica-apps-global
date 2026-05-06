# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::Verification::TotpsControllerTest < ActionDispatch::IntegrationTest
  fixtures :users

  setup do
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    host! @host
    ensure_customer_reference_records!
    ensure_customer_token_reference_records!
    @customer = Customer.create!(
      status_id: CustomerStatus::ACTIVE,
      visibility_id: CustomerVisibility::CUSTOMER,
    )
    @customer.customer_telephones.create!(
      number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
      customer_telephone_status_id: CustomerTelephoneStatus::VERIFIED,
    )
    @headers = as_customer_headers(@customer, host: @host)
  end

  test "new redirects because totp step up is unavailable" do
    get new_sign_com_verification_totp_url(ri: "jp"), headers: @headers

    assert_response :see_other
    assert_redirected_to sign_com_verification_url(ri: "jp")
    assert_equal I18n.t("auth.step_up.method_unavailable"), flash[:alert]
  end

  test "create redirects because totp step up is unavailable" do
    post sign_com_verification_totp_url(ri: "jp"), headers: @headers

    assert_response :see_other
    assert_redirected_to sign_com_verification_url(ri: "jp")
    assert_equal I18n.t("auth.step_up.method_unavailable"), flash[:alert]
  end
end
