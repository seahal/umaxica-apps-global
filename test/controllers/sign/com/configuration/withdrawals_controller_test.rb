# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::Configuration::WithdrawalsControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    host! @host
    @customer = create_verified_customer_with_email(email_address: "withdrawal-#{SecureRandom.hex(4)}@example.com")
    @customer.customer_telephones.create!(
      number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
      customer_telephone_status_id: CustomerTelephoneStatus::VERIFIED,
    )
    @token = CustomerToken.create!(customer: @customer, customer_token_kind_id: CustomerTokenKind::BROWSER_WEB)
    satisfy_customer_verification(@token)
    @headers = as_customer_headers(@customer, host: @host).merge("X-TEST-SESSION-PUBLIC-ID" => @token.public_id)
  end

  test "new requires schedule confirmation to proceed" do
    get new_sign_com_configuration_withdrawal_url(ri: "jp"), headers: @headers

    assert_response :success

    get new_sign_com_configuration_withdrawal_url(ri: "jp", ack_schedule_purge: "0"), headers: @headers

    assert_response :unprocessable_content

    get new_sign_com_configuration_withdrawal_url(ri: "jp", ack_schedule_purge: "1"), headers: @headers

    assert_response :success
    assert_select "label"
  end

  test "update requires deactivate confirmation" do
    patch sign_com_configuration_withdrawal_url(ri: "jp"),
          params: { ack_deactivate_today: "0" },
          headers: @headers

    assert_response :unprocessable_content
    assert_nil @customer.reload.deactivated_at
  end

  test "update sets deactivation timestamps" do
    travel_to Time.zone.parse("2026-02-09 10:00:00") do
      patch sign_com_configuration_withdrawal_url(ri: "jp"),
            params: { ack_deactivate_today: "1" },
            headers: @headers
    end

    assert_response :see_other
    assert_redirected_to edit_sign_com_configuration_url(ri: "jp")

    @customer.reload

    assert_not_nil @customer.withdrawal_started_at
    assert_not_nil @customer.deactivated_at
    assert_not_nil @customer.scheduled_purge_at
    assert_equal @customer.deactivated_at + 31.days, @customer.scheduled_purge_at
  end

  test "edit shows recoverable state within 31 days" do
    @customer.update!(
      deactivated_at: 10.days.ago,
      withdrawal_started_at: 10.days.ago,
      scheduled_purge_at: 21.days.from_now,
    )

    get edit_sign_com_configuration_withdrawal_url(ri: "jp"), headers: @headers

    assert_response :success
    assert_includes response.body, "復旧"
  end

  test "create recovers account within 31 days" do
    @customer.update!(
      deactivated_at: 10.days.ago,
      withdrawal_started_at: 10.days.ago,
      scheduled_purge_at: 21.days.from_now,
    )

    post sign_com_configuration_withdrawal_url(ri: "jp"), headers: @headers

    assert_response :see_other
    assert_redirected_to sign_com_configuration_url(ri: "jp")
    @customer.reload

    assert_nil @customer.deactivated_at
    assert_nil @customer.withdrawal_started_at
    assert_nil @customer.scheduled_purge_at
  end

  test "create does not recover account after 31 days" do
    @customer.update!(
      deactivated_at: 31.days.ago,
      withdrawal_started_at: 31.days.ago,
      scheduled_purge_at: 1.day.ago,
    )

    post sign_com_configuration_withdrawal_url(ri: "jp"), headers: @headers

    assert_response :see_other
    @customer.reload

    assert_not_nil @customer.deactivated_at
  end
end
