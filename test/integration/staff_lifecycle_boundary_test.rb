# frozen_string_literal: true

require "test_helper"

class StaffLifecycleBoundaryTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    host! @host
    @staff = operators(:one)
    @token = OperatorToken.create!(staff: @staff)
    mark_token_step_up_satisfied_for_test(@token, scope: "withdrawal")
  end

  test "org withdrawal route is informational and exposes lifecycle request entry instead of destructive self service" do # rubocop:disable Layout/LineLength
    get auth_org_settings_withdrawal_url(ri: "jp"), headers: headers

    assert_response :success
    assert_nil @staff.reload.deactivated_at
    assert_select "a[href=?]",
                  new_auth_org_settings_operator_lifecycle_request_path(
                    action_kind: OperatorLifecycleRequest::ACTION_WITHDRAW,
                    ri: "jp",
                  )
  end

  test "org withdrawal endpoint does not accept app com destructive withdrawal verbs" do
    patch auth_org_settings_withdrawal_url(ri: "jp"),
          params: { ack_deactivate_today: "1" },
          headers: headers

    assert_response :not_found

    delete auth_org_settings_withdrawal_url(ri: "jp"), headers: headers

    assert_response :not_found
    assert_nil @staff.reload.deactivated_at
    assert_not @token.reload.revoked?
  end

  private

  def headers
    browser_headers.merge(
      "Host" => @host,
      "X-TEST-CURRENT-STAFF" => @staff.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    )
  end
end
