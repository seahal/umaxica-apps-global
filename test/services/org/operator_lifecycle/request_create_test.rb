# typed: false
# frozen_string_literal: true

require "test_helper"

class Org::OperatorLifecycle::RequestCreateTest < ActiveSupport::TestCase
  fixtures :operators

  test "creates withdrawal request for requesting operator when target is omitted" do
    actor = operators(:one)

    result = Org::OperatorLifecycle::RequestCreate.call(
      actor: actor,
      attributes: {
        action: OperatorLifecycleRequest::ACTION_WITHDRAW,
        reason: "leaving org",
      },
    )

    assert_predicate result, :success?
    assert_equal actor, result.request.requested_by_operator
    assert_equal actor, result.request.target_operator
    assert_equal OperatorLifecycleRequest::STATUS_PENDING, result.request.status
  end

  test "rejects non join request when target operator is unknown" do
    result = Org::OperatorLifecycle::RequestCreate.call(
      actor: operators(:one),
      attributes: {
        action: OperatorLifecycleRequest::ACTION_SUSPEND,
        target_operator_public_id: "UNKNOWN",
      },
    )

    assert_not result.success?
    assert_predicate result.request.errors[:target_operator], :present?
  end

  test "creates join request with normalized email" do
    result = Org::OperatorLifecycle::RequestCreate.call(
      actor: operators(:one),
      attributes: {
        action: OperatorLifecycleRequest::ACTION_JOIN,
        target_email: " INVITEE@EXAMPLE.COM ",
        organization_id: 123,
        role_id: 4,
      },
    )

    assert_predicate result, :success?
    assert_equal "invitee@example.com", result.request.target_email
    assert_equal 123, result.request.organization_id
    assert_equal 4, result.request.role_id
  end
end
