# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class Auth::Org::Verification::SetupsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses, :operator_token_statuses, :operator_token_kinds

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")
    host! @host
    @staff = Operator.create!(status_id: OperatorStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
    @token = OperatorToken.create!(
      staff: @staff,
      staff_token_status_id: OperatorTokenStatus::ACTIVE,
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
    )
    satisfy_staff_verification(@token)
    @headers = {
      "Host" => @host,
      "X-TEST-CURRENT-STAFF" => @staff.id,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }
  end

  test "new shows a back link above registration methods when pt is present" do
    pt = Base64.urlsafe_encode64(auth_org_settings_passkeys_path(ri: "jp"))

    get new_auth_org_verification_setup_url(ri: "jp", pt: pt), headers: @headers

    assert_response :success
    assert_select "a[href=?]", auth_org_settings_path(ri: "jp"), count: 0
    assert_select "ul"
  end
end
