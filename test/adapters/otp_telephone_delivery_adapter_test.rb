# typed: false
# frozen_string_literal: true

require "test_helper"

class OtpTelephoneDeliveryAdapterTest < ActiveSupport::TestCase
  test "deliver calls SignTelephoneOtpDelivery with correct arguments" do
    record = Object.new
    otp_code = "654321"
    delivered = []

    SignTelephoneOtpDelivery.stub(:deliver!, ->(r, c) { delivered << [r, c] }) do
      OtpTelephoneDeliveryAdapter.new.deliver(record: record, otp_code: otp_code)
    end

    assert_equal [[record, otp_code]], delivered
  end

  test "deliver ignores unexpected keyword arguments" do
    record = Object.new
    delivered = []

    SignTelephoneOtpDelivery.stub(:deliver!, ->(r, c) { delivered << [r, c] }) do
      OtpTelephoneDeliveryAdapter.new.deliver(
        record: record,
        otp_code: "111111",
        encrypted_hotp_token: "ignored",
        email_address: "ignored@example.com",
      )
    end

    assert_equal 1, delivered.size
    assert_equal record, delivered.first.first
  end
end
