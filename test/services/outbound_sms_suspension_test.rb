# typed: false
# frozen_string_literal: true

require "test_helper"

class OutboundSmsSuspensionTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  teardown do
    Flipper.disable(:outbound_sms_suspended)
  end

  test "deliver_later enqueues nothing while the sms channel is suspended" do
    Flipper.enable(:outbound_sms_suspended)

    result = nil
    assert_no_enqueued_jobs(only: Outbound::SmsDeliveryJob) do
      result = OutboundSms.deliver_later(to: "+819012345678", title: "Verification code", body: "123456")
    end

    assert_not result.accepted?
    assert_equal :sms, result.channel
    assert_equal OutboundSms::SUSPENDED_ERROR, result.error
  end

  test "deliver_now sends nothing while the sms channel is suspended" do
    Flipper.enable(:outbound_sms_suspended)

    OutboundSms.stub(:provider, ->(*) { raise RuntimeError, "provider must not be resolved while suspended" }) do
      result = OutboundSms.deliver_now(to: "+819012345678", title: "Verification code", body: "123456")

      assert_not result.accepted?
      assert_equal OutboundSms::SUSPENDED_ERROR, result.error
    end
  end

  test "deliver_later enqueues normally while the sms channel is running" do
    assert_enqueued_jobs(1, only: Outbound::SmsDeliveryJob) do
      result = OutboundSms.deliver_later(to: "+819012345678", title: "Verification code", body: "123456")

      assert_predicate result, :accepted?
    end
  end
end
