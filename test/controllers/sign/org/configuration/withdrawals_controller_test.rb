# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::Configuration::WithdrawalsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_identity_statuses

  setup do
    host! ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @staff = operators(:one)
    @token = OperatorToken.create!(staff: @staff)
    satisfy_staff_verification(@token)
    mark_token_step_up_satisfied_for_test(@token, scope: "withdrawal")
  end

  def authenticated_headers
    browser_headers.merge(
      "X-TEST-CURRENT-STAFF" => @staff.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    )
  end

  test "should get show" do
    get sign_org_configuration_withdrawal_url(ri: "jp"), headers: authenticated_headers

    assert_response :success
    assert_select "a[href=?]",
                  new_sign_org_configuration_operator_lifecycle_request_path(
                    action_kind: OperatorLifecycleRequest::ACTION_WITHDRAW,
                    ri: "jp",
                  )
  end
end
