# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class OperatorLifecycleRequestPolicyTest < ActiveSupport::TestCase
  def policy_for(user:, record:)
    OperatorLifecycleRequestPolicy.new(record, user: user)
  end

  test "show? is true for an operator actor" do
    policy = policy_for(user: Operator.new(id: 1), record: OperatorLifecycleRequest.new)

    assert_predicate policy, :show?
  end

  test "show? is false for a non-operator actor" do
    policy = policy_for(user: Client.new, record: OperatorLifecycleRequest.new)

    assert_not policy.show?
  end

  test "reject? is true when an operator reviews a pending request from a different operator" do
    record = OperatorLifecycleRequest.new(
      status: OperatorLifecycleRequest::STATUS_PENDING,
      requested_by_operator_id: 999,
    )

    assert_predicate policy_for(user: Operator.new(id: 1), record: record), :reject?
  end

  test "reject? is false when the requester is the same operator" do
    operator = Operator.new(id: 7)
    record = OperatorLifecycleRequest.new(
      status: OperatorLifecycleRequest::STATUS_PENDING,
      requested_by_operator_id: 7,
    )

    assert_not policy_for(user: operator, record: record).reject?
  end

  test "reject? is false when the request is not pending" do
    record = OperatorLifecycleRequest.new(
      status: OperatorLifecycleRequest::STATUS_APPROVED,
      requested_by_operator_id: 999,
    )

    assert_not policy_for(user: Operator.new(id: 1), record: record).reject?
  end
end
