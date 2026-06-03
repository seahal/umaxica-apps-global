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
  end

  test "show_redirects_to_acme_account_authority" do
    get sign_org_settings_withdrawal_url(ri: "jp"), headers: session_headers

    assert_redirect_to_acme_withdrawal
  end

  private

  def session_headers
    {
      "Host" => @host,
      "X-TEST-CURRENT-STAFF" => @staff.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }
  end

  def assert_redirect_to_acme_withdrawal
    assert_response :see_other
    location = URI.parse(response.location)

    assert_equal @acme_host, location.host
    assert_equal "/settings/withdrawal", location.path
    assert_equal "ri=jp", location.query
  end
end
