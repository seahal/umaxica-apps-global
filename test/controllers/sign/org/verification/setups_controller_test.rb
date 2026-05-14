# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class Sign::Org::Verification::SetupsControllerTest < ActionDispatch::IntegrationTest
  fixtures :staffs, :staff_statuses, :staff_token_statuses, :staff_token_kinds

  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    host! @host
    @staff = Operator.create!(status_id: OperatorIdentityStatus::ACTIVE, visibility_id: OperatorVisibility::STAFF)
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

  test "new shows a back link above registration methods when rt is present" do
    rt = Base64.urlsafe_encode64(sign_org_configuration_passkeys_path(ri: "jp"))

    get new_sign_org_verification_setup_url(ri: "jp", rt: rt), headers: @headers

    assert_response :success
    assert_select "a[href=?]", sign_org_configuration_path(ri: "jp"), text: I18n.t("actions.back")
    assert_operator response.body.index(I18n.t("actions.back")), :<, response.body.index("<ul>")
  end
end
