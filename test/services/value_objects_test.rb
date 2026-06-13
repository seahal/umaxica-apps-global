# frozen_string_literal: true

require "test_helper"

class ValueObjectsTest < ActiveSupport::TestCase
  test "logout result success exposes expected defaults and predicate" do
    result = LogoutResult.success(token: "token-1", revoked_tokens: %w[a b], redirect_to: "/home", message: "done")

    assert_equal :success, result.status
    assert_equal "token-1", result.token
    assert_equal %w[a b], result.revoked_tokens
    assert_equal "/home", result.redirect_to
    assert_equal :ok, result.response_status
    assert_equal "done", result.message
    assert_predicate result, :success?
  end

  test "outbound result accepted and rejected variants expose expected predicates" do
    accepted = OutboundResult.accepted(channel: :email, delivery_id: "d-1")
    rejected = OutboundResult.rejected(channel: :sms, error: "boom")

    assert_predicate accepted, :accepted?
    assert_equal :email, accepted.channel
    assert_equal "d-1", accepted.delivery_id
    assert_nil accepted.error

    assert_not_predicate rejected, :accepted?
    assert_equal :sms, rejected.channel
    assert_nil rejected.delivery_id
    assert_equal "boom", rejected.error
  end
end
