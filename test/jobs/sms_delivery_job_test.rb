# typed: false
# frozen_string_literal: true

require "test_helper"

class SmsDeliveryJobTest < ActiveSupport::TestCase
  test "perform calls AwsSmsService.send_message with arguments" do
    called = false
    AwsSmsService.stub(
      :send_message, ->(to:, message:, subject:) {
                       called = true

                       assert_equal "+819012345678", to
                       assert_equal "Your code is 123456", message
                       assert_nil subject
                       "message-id-123"
                     },
    ) do
      SmsDeliveryJob.perform_now(to: "+819012345678", message: "Your code is 123456")
    end

    assert called
  end

  test "perform calls AwsSmsService.send_message with subject" do
    called = false
    AwsSmsService.stub(
      :send_message, ->(to:, message:, subject:) {
                       called = true

                       assert_equal "+819012345678", to
                       assert_equal "Your code is 123456", message
                       assert_equal "Verification", subject
                       "message-id-456"
                     },
    ) do
      SmsDeliveryJob.perform_now(to: "+819012345678", message: "Your code is 123456", subject: "Verification")
    end

    assert called
  end

  test "queue name is default" do
    assert_equal "default", SmsDeliveryJob.queue_name
  end
end
