# typed: false
# frozen_string_literal: true

require "test_helper"

module Outbound
  class SensitivePayloadTest < ActiveSupport::TestCase
    test "encrypts and decrypts sms bodies without embedding plaintext" do
      token = SensitivePayload.encrypt_sms_body("Your code is 123456")

      assert_not_includes token, "123456"
      assert_equal "Your code is 123456", SensitivePayload.decrypt_sms_body(token)
    end

    test "email otp tokens cannot be decrypted with sms purpose" do
      token = SensitivePayload.encrypt_email_otp("123456")

      assert_raises(ActiveSupport::MessageEncryptor::InvalidMessage) do
        SensitivePayload.decrypt_sms_body(token)
      end
    end

    test "blank payloads are rejected" do
      assert_raises(ArgumentError) { SensitivePayload.encrypt_email_otp("") }
      assert_raises(ArgumentError) { SensitivePayload.decrypt_email_otp("") }
    end
  end
end
