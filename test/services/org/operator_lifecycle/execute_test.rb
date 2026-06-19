# typed: false
# frozen_string_literal: true

require "test_helper"

class OrgOperatorLifecycleExecuteTest < ActiveSupport::TestCase
  fixtures :operators, :operator_tokens, :operator_token_statuses, :operator_token_kinds,
           :operator_token_binding_methods, :operator_token_dbsc_statuses

  test "executes approved withdrawal by suspending target operator and revoking sessions" do
    target = operators(:one)
    token = operator_tokens(:one)
    request = approved_request(
      action: OperatorLifecycleRequest::ACTION_WITHDRAW,
      target_operator: target,
      requested_by_operator: target,
    )

    result = OrgOperatorLifecycleExecute.call(request: request, actor: operators(:two))

    assert_predicate result, :success?
    assert_predicate request.reload, :executed?
    assert_not_nil target.reload.withdrawal_started_at
    assert_not_nil target.deactivated_at
    assert_operator target.purged_at, :>, target.deactivated_at
    assert_predicate token.reload, :revoked?
  end

  test "prevents requester from executing their own request" do
    request = approved_request(
      action: OperatorLifecycleRequest::ACTION_WITHDRAW,
      target_operator: operators(:two),
      requested_by_operator: operators(:one),
    )

    result = OrgOperatorLifecycleExecute.call(request: request, actor: operators(:one))

    assert_not result.success?
    assert_predicate request.reload, :approved?
  end

  test "executes approved join by creating organization invitation" do
    request = OperatorLifecycleRequest.create!(
      action: OperatorLifecycleRequest::ACTION_JOIN,
      status: OperatorLifecycleRequest::STATUS_APPROVED,
      target_email: "invitee@example.com",
      organization_id: 123,
      role_id: 7,
      requested_by_operator: operators(:one),
      approved_by_operator: operators(:two),
      approved_at: Time.current,
    )

    result = OrgOperatorLifecycleExecute.call(request: request, actor: operators(:two))

    assert_predicate result, :success?
    assert_predicate request.reload, :executed?
    assert_equal "invitee@example.com", result.invitation.email
    assert_equal 123, result.invitation.organization_id
    assert_equal 7, result.invitation.role_id
    assert_equal result.invitation.id, request.invitation_id
  end

  test "rejects non-approved requests before execution" do
    target = operators(:one)
    request = OperatorLifecycleRequest.create!(
      action: OperatorLifecycleRequest::ACTION_WITHDRAW,
      status: OperatorLifecycleRequest::STATUS_PENDING,
      target_operator: target,
      requested_by_operator: target,
      reason: "pending",
    )

    result = OrgOperatorLifecycleExecute.call(request: request, actor: operators(:two))

    assert_not result.success?
    assert_match(/Only approved/, result.error)
  end

  test "executes approved terminate by discarding target operator" do
    target = operators(:one)
    token = operator_tokens(:one)
    request = approved_request(
      action: OperatorLifecycleRequest::ACTION_TERMINATE,
      target_operator: target,
      requested_by_operator: target,
    )

    result = OrgOperatorLifecycleExecute.call(request: request, actor: operators(:two))

    assert_predicate result, :success?
    assert_predicate request.reload, :executed?
    assert_not_nil target.reload.withdrawn_at
    assert_not_nil target.deactivated_at
    assert_equal target.discarded_at, target.purged_at
    assert_predicate token.reload, :revoked?
  end

  test "executes approved restore by clearing deactivation dates" do
    target = operators(:one)
    now = Time.current
    target.update!(
      withdrawal_started_at: now,
      deactivated_at: now,
      withdrawn_at: now,
      discarded_at: now,
      purged_at: now,
    )
    request = approved_request(
      action: OperatorLifecycleRequest::ACTION_RESTORE,
      target_operator: target,
      requested_by_operator: target,
    )

    result = OrgOperatorLifecycleExecute.call(request: request, actor: operators(:two))

    assert_predicate result, :success?
    assert_nil target.reload.withdrawal_started_at
    assert_nil target.deactivated_at
    assert_nil target.withdrawn_at
    assert_operator target.discarded_at, :>, Time.current
  end

  test "suspend fails when target would be the last active operator" do
    target = operators(:one)
    # Deactivate all other operators so :one is the last active
    Operator.where.not(id: target.id).update_all(deactivated_at: Time.current)

    request = approved_request(
      action: OperatorLifecycleRequest::ACTION_WITHDRAW,
      target_operator: target,
      requested_by_operator: operators(:two),
    )

    result = OrgOperatorLifecycleExecute.call(request: request, actor: operators(:two))

    assert_not result.success?
    assert_match(/last active operator/, result.error)
  end

  private

  def approved_request(action:, target_operator:, requested_by_operator:)
    OperatorLifecycleRequest.create!(
      action: action,
      status: OperatorLifecycleRequest::STATUS_APPROVED,
      target_operator: target_operator,
      requested_by_operator: requested_by_operator,
      approved_by_operator: operators(:two),
      approved_at: Time.current,
      reason: "approved",
    )
  end
end
