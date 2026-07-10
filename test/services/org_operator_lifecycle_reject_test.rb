# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OrgOperatorLifecycleRejectTest < ActiveSupport::TestCase
  test "rejects pending request" do
    request = operator_lifecycle_requests(:pending_withdraw_two)
    actor = operators(:two)

    result = OrgOperatorLifecycleReject.call(request: request, actor: actor, reason: "not needed")

    assert_predicate result, :success?
    assert_equal operator_lifecycle_requests(:pending_withdraw_two).id, result.request.id
    request.reload

    assert_equal OperatorLifecycleRequest::STATUS_REJECTED, request.status
  end

  test "returns failure for non-pending request" do
    request = operator_lifecycle_requests(:approved_withdraw_one)
    actor = operators(:two)

    result = OrgOperatorLifecycleReject.call(request: request, actor: actor, reason: "too late")

    assert_not_predicate result, :success?
    assert_equal "Only pending requests can be rejected", result.error
  end

  test "returns failure when requester tries to reject own request" do
    request = operator_lifecycle_requests(:pending_withdraw_one)
    actor = operators(:one)

    result = OrgOperatorLifecycleReject.call(request: request, actor: actor)

    assert_not_predicate result, :success?
    assert_equal "Requester cannot reject their own lifecycle request", result.error
  end
end
