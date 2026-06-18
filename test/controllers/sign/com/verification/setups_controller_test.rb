# typed: false
# frozen_string_literal: true

require "test_helper"
require "base64"

class Sign::Com::Verification::SetupsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    host! @host
    ensure_visitor_reference_records!
    ensure_visitor_token_reference_records!
    @visitor = Visitor.create!(status_id: VisitorStatus::ACTIVE, visibility_id: VisitorVisibility::VISITOR)
    VisitorEmail.create!(
      visitor: @visitor,
      address: "com-setup-#{SecureRandom.hex(4)}@example.com",
      visitor_email_status_id: VisitorEmailStatus::VERIFIED,
      confirm_policy: "1",
    )
    @visitor.visitor_telephones.create!(
      number: "+8190#{SecureRandom.random_number(10 ** 8).to_s.rjust(8, "0")}",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    @token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    satisfy_visitor_verification(@token)
    @headers = {
      "Host" => @host,
      "X-TEST-CURRENT-RESOURCE" => @visitor.id,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }
  end

  test "new shows a back link above registration methods when pt is present" do
    pt = Base64.urlsafe_encode64(sign_com_settings_telephones_path(ri: "jp"))

    get new_sign_com_verification_setup_url(ri: "jp", pt: pt), headers: @headers

    assert_response :success
    assert_select "a[href=?]", sign_com_settings_path(ri: "jp"), count: 0
    assert_select "ul"
  end
end
