# typed: false
# frozen_string_literal: true

require "test_helper"

class Org::OperatorLifecycle::ApproveTest < ActiveSupport::TestCase
  fixtures :operators

  test "prevents requester from approving their own request" do
    request = create_request(requested_by_operator: operators(:one))

    result = Org::OperatorLifecycle::Approve.call(request: request, actor: operators(:one))

    assert_not result.success?
    assert_predicate request.reload, :pending?
  end

  test "approves pending request by another operator" do
    request = create_request(requested_by_operator: operators(:one))

    result = Org::OperatorLifecycle::Approve.call(request: request, actor: operators(:two))

    assert_predicate result, :success?
    assert_predicate request.reload, :approved?
    assert_equal operators(:two), request.approved_by_operator
    assert_not_nil request.approved_at
  end

  private

  def create_request(requested_by_operator:)
    OperatorLifecycleRequest.create!(
      action: OperatorLifecycleRequest::ACTION_WITHDRAW,
      target_operator: operators(:one),
      requested_by_operator: requested_by_operator,
      reason: "leaving",
    )
  end
end
