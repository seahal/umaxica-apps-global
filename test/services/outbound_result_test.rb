# typed: false
# frozen_string_literal: true

require "test_helper"

class OutboundResultTest < ActiveSupport::TestCase
  test "accepted creates a successful result" do
    result = OutboundResult.accepted(channel: :sms, delivery_id: "D123")

    assert_predicate result, :accepted?
    assert_equal :sms, result.channel
    assert_equal "D123", result.delivery_id
    assert_nil result.error
  end

  test "rejected creates a failed result" do
    result = OutboundResult.rejected(channel: :email, error: "bounced")

    assert_not_predicate result, :accepted?
    assert_equal :email, result.channel
    assert_equal "bounced", result.error
    assert_nil result.delivery_id
  end

  test "accepted? is false when accepted field is false" do
    result = OutboundResult.new(
      accepted: false,
      channel: :sms,
      delivery_id: nil,
      error: "failed",
    )

    assert_not_predicate result, :accepted?
  end
end
