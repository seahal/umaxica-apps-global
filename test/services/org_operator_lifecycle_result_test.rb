# typed: false
# frozen_string_literal: true

require "test_helper"

class OrgOperatorLifecycleResultTest < ActiveSupport::TestCase
  test "success? returns true when success is true" do
    result = OrgOperatorLifecycleResult.new(success: true, request: nil, error: nil, invitation: nil)

    assert_predicate result, :success?
  end

  test "success? returns false when success is false" do
    result = OrgOperatorLifecycleResult.new(success: false, request: nil, error: "error", invitation: nil)

    assert_not_predicate result, :success?
  end

  test "data equality works" do
    result1 = OrgOperatorLifecycleResult.new(success: true, request: nil, error: nil, invitation: nil)
    result2 = OrgOperatorLifecycleResult.new(success: true, request: nil, error: nil, invitation: nil)

    assert_equal result1, result2
  end

  test "stores attributes" do
    result = OrgOperatorLifecycleResult.new(success: false, request: "req", error: "err", invitation: "inv")

    assert_equal "req", result.request
    assert_equal "err", result.error
    assert_equal "inv", result.invitation
  end
end
