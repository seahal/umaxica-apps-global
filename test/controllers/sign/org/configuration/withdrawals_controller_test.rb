# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::Configuration::WithdrawalsControllerTest < ActionDispatch::IntegrationTest
  fixtures :staffs, :staff_statuses

  setup do
    host! ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @staff = staffs(:one)
    @token = StaffToken.create!(staff: @staff)
    satisfy_staff_verification(@token)
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
  end
end
