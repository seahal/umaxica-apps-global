# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::Settings::OperatorLifecycleRequestActionsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses, :operator_tokens, :operator_token_statuses,
           :operator_token_kinds, :operator_token_binding_methods, :operator_token_dbsc_statuses

  setup do
    host! ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @operator = operators(:two)
    @token = operator_tokens(:two)
    satisfy_staff_verification(@token)
    @token.update!(last_step_up_at: Time.current, last_step_up_scope: "operator_lifecycle")
  end

  test "another operator can approve a pending request" do
    request = lifecycle_request(status: OperatorLifecycleRequest::STATUS_PENDING)

    post sign_org_settings_operator_lifecycle_request_approval_url(request, ri: "jp"),
         headers: authenticated_headers

    assert_response :redirect
    assert_predicate request.reload, :approved?
    assert_equal @operator, request.approved_by_operator
  end

  test "another operator can execute an approved request" do
    request = lifecycle_request(status: OperatorLifecycleRequest::STATUS_APPROVED, approved_by_operator: @operator)

    post sign_org_settings_operator_lifecycle_request_execution_url(request, ri: "jp"),
         headers: authenticated_headers

    assert_response :redirect
    assert_predicate request.reload, :executed?
    assert_not_nil operators(:one).reload.deactivated_at
  end

  private

  def lifecycle_request(status:, approved_by_operator: nil)
    OperatorLifecycleRequest.create!(
      action: OperatorLifecycleRequest::ACTION_WITHDRAW,
      status: status,
      target_operator: operators(:one),
      requested_by_operator: operators(:one),
      approved_by_operator: approved_by_operator,
      approved_at: approved_by_operator ? Time.current : nil,
      reason: "leaving",
    )
  end

  def authenticated_headers
    browser_headers.merge(
      "X-TEST-CURRENT-STAFF" => @operator.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    )
  end
end
