# typed: false
# frozen_string_literal: true

require "test_helper"

class OperatorLifecycleRequestTest < ActiveSupport::TestCase
  test "closed? returns true for rejected, executed or cancelled status" do
    req = OperatorLifecycleRequest.new(status: "rejected")

    assert_predicate req, :closed?

    req = OperatorLifecycleRequest.new(status: "executed")

    assert_predicate req, :closed?

    req = OperatorLifecycleRequest.new(status: "cancelled")

    assert_predicate req, :closed?

    req = OperatorLifecycleRequest.new(status: "pending")

    assert_not req.closed?
  end
end
