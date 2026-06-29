# typed: false
# frozen_string_literal: true

require "test_helper"

class OtpEmailDeliveryAdapterTest < ActiveSupport::TestCase
  test "deliver queues mail via the injected mailer" do
    calls = []
    fake_mail = Object.new
    fake_mail.define_singleton_method(:deliver_later) { calls << :delivered }

    fake_message = Object.new
    fake_message.define_singleton_method(:create) { fake_mail }

    fake_mailer = Object.new
    fake_mailer.define_singleton_method(:with) do |**kwargs|
      calls << kwargs
      fake_message
    end

    adapter = OtpEmailDeliveryAdapter.new(fake_mailer)
    adapter.deliver(encrypted_hotp_token: "token", email_address: "user@example.com")

    assert_equal({ encrypted_hotp_token: "token", email_address: "user@example.com" }, calls.first)
    assert_includes calls, :delivered
  end

  test "deliver ignores unexpected keyword arguments" do
    calls = []
    fake_mail = Object.new
    fake_mail.define_singleton_method(:deliver_later) { calls << :delivered }

    fake_message = Object.new
    fake_message.define_singleton_method(:create) { fake_mail }

    fake_mailer = Object.new
    fake_mailer.define_singleton_method(:with) { |**_| fake_message }

    adapter = OtpEmailDeliveryAdapter.new(fake_mailer)
    adapter.deliver(
      encrypted_hotp_token: "token",
      email_address: "addr@example.com",
      record: Object.new,
      otp_code: "123456",
    )

    assert_includes calls, :delivered
  end
end
