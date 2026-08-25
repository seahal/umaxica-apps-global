# typed: false
# frozen_string_literal: true

require "test_helper"

class OtpEmailNotifierAdapterTest < ActiveSupport::TestCase
  test "deliver forwards the record and otp to the injected notifier" do
    calls = []
    record = Object.new
    fake_notifier = Object.new
    fake_notifier.define_singleton_method(:issue) { |**kwargs| calls << kwargs }

    OtpEmailNotifierAdapter.new(fake_notifier).deliver(record: record, otp_code: "123456")

    assert_equal(
      [{ record: record, otp_code: "123456", verification_token: nil, public_id: nil }],
      calls,
    )
  end

  test "deliver forwards optional verification params" do
    calls = []
    record = Object.new
    fake_notifier = Object.new
    fake_notifier.define_singleton_method(:issue) { |**kwargs| calls << kwargs }

    OtpEmailNotifierAdapter.new(fake_notifier).deliver(
      record: record,
      otp_code: "654321",
      verification_token: "verify-token",
      public_id: "email-public-id",
    )

    assert_equal(
      [{
        record: record,
        otp_code: "654321",
        verification_token: "verify-token",
        public_id: "email-public-id",
      }],
      calls,
    )
  end

  # Parity with OtpEmailAdapter, whose `**` sink lets call sites pass channel
  # specific options such as message_style without knowing which adapter they got.
  test "deliver ignores unexpected keyword arguments" do
    calls = []
    fake_notifier = Object.new
    fake_notifier.define_singleton_method(:issue) { |**kwargs| calls << kwargs }

    OtpEmailNotifierAdapter.new(fake_notifier).deliver(
      record: Object.new,
      otp_code: "123456",
      message_style: :localized_verification,
    )

    assert_equal 1, calls.length
    assert_not calls.first.key?(:message_style)
  end
end
