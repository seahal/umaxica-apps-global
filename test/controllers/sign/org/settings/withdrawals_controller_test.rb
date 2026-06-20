# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::Settings::WithdrawalsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @acme_host = ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
    @staff = operators(:one)
    @token = OperatorToken.create!(staff: @staff)
    mark_token_step_up_satisfied_for_test(@token, scope: "withdrawal")
  end

  test "show renders sign withdrawal entry" do
    get sign_org_settings_withdrawal_url(ri: "jp"), headers: session_headers

    assert_response :success
  end

  private

  def session_headers
    {
      "Host" => @host,
      "X-TEST-CURRENT-STAFF" => @staff.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }
  end
end
