# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::Configuration::TelephonesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    host! ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    @customer = create_verified_customer_with_email(email_address: "telephones-#{SecureRandom.hex(4)}@example.com")
    @customer.customer_telephones.create!(
      number: "+10000000027",
      customer_telephone_status_id: CustomerTelephoneStatus::VERIFIED,
    )
    @token = CustomerToken.create!(customer: @customer, customer_token_kind_id: CustomerTokenKind::BROWSER_WEB)
    satisfy_customer_verification(@token)
  end

  def request_headers
    {
      "Host" => @host,
      "X-TEST-CURRENT-RESOURCE" => @customer.id,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }
  end

  test "should get index" do
    get sign_com_configuration_telephones_url(ri: "jp"), headers: request_headers

    assert_response :success
  end

  test "index redirects customers without a verified telephone to registration" do
    customer = create_verified_customer_with_email(email_address: "unverified-#{SecureRandom.hex(4)}@example.com")
    token = CustomerToken.create!(customer: customer, customer_token_kind_id: CustomerTokenKind::BROWSER_WEB)
    satisfy_customer_verification(token)

    headers = {
      "Host" => @host,
      "X-TEST-CURRENT-RESOURCE" => customer.id,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }

    get sign_com_configuration_telephones_url(ri: "jp"), headers: headers

    assert_redirected_to new_sign_com_configuration_telephones_registration_url(ri: "jp")
  end

  test "create registers telephone" do
    assert_enqueued_jobs 1, only: SmsDeliveryJob do
      assert_difference("CustomerTelephone.count", 1) do
        post sign_com_configuration_telephones_url(ri: "jp"),
             params: { user_telephone: { raw_number: "+10000000028" } },
             headers: request_headers
      end
    end

    created = CustomerTelephone.order(created_at: :desc).first

    assert_redirected_to edit_sign_com_configuration_telephone_url(created.id, ri: "jp")
  end

  test "create reuses existing telephone and sends sms when same number is submitted again" do
    existing = CustomerTelephone.create!(
      number: "+10000000029",
      customer: @customer,
      customer_telephone_status_id: CustomerTelephoneStatus::VERIFIED,
    )

    assert_enqueued_jobs 1, only: SmsDeliveryJob do
      assert_no_difference("CustomerTelephone.count") do
        post sign_com_configuration_telephones_url(ri: "jp"),
             params: { user_telephone: { raw_number: "+10000000029" } },
             headers: request_headers
      end
    end

    assert_redirected_to edit_sign_com_configuration_telephone_url(existing.id, ri: "jp")
  end

  test "destroy removes telephone when not last method" do
    tel1 = CustomerTelephone.create!(
      number: "+10000000030",
      customer: @customer,
      customer_telephone_status_id: CustomerTelephoneStatus::VERIFIED,
    )
    CustomerTelephone.create!(
      number: "+10000000031",
      customer: @customer,
      customer_telephone_status_id: CustomerTelephoneStatus::VERIFIED,
    )

    assert_difference("CustomerTelephone.count", -1) do
      delete sign_com_configuration_telephone_url(tel1, ri: "jp"), headers: request_headers
    end

    assert_response :see_other
  end
end
