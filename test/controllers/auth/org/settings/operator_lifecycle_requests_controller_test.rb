# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class Auth::Org::Settings::OperatorLifecycleRequestsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses, :operator_tokens, :operator_token_statuses,
           :operator_token_kinds, :operator_token_binding_methods, :operator_token_dbsc_statuses

  setup do
    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")
    @operator = operators(:one)
    @token = operator_tokens(:one)
    satisfy_staff_verification(@token)
    @token.update!(last_step_up_at: Time.current, last_step_up_scope: "operator_lifecycle")
  end

  test "index renders for authenticated operator" do
    get auth_org_settings_operator_lifecycle_requests_url(ri: "jp"), headers: authenticated_headers

    assert_response :success
  end

  test "new renders withdrawal request for current operator" do
    get new_auth_org_settings_operator_lifecycle_request_url(
      action_kind: OperatorLifecycleRequest::ACTION_WITHDRAW,
      ri: "jp",
    ), headers: authenticated_headers

    assert_response :success
    assert_select "input[value=?]", @operator.public_id
  end

  test "create stores lifecycle request" do
    assert_difference -> { OperatorLifecycleRequest.count }, 1 do
      post auth_org_settings_operator_lifecycle_requests_url(ri: "jp"),
           params: {
             operator_lifecycle_request: {
               action: OperatorLifecycleRequest::ACTION_WITHDRAW,
               reason: "leaving",
             },
           },
           headers: authenticated_headers
    end

    assert_response :redirect
    request = OperatorLifecycleRequest.order(:created_at).last

    assert_equal @operator, request.target_operator
    assert_equal @operator, request.requested_by_operator
  end

  private

  def authenticated_headers
    browser_headers.merge(
      "X-TEST-CURRENT-STAFF" => @operator.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    )
  end
end
