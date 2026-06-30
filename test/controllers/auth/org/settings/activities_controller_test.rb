# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Auth::Org::Settings::ActivitiesControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_token_kinds

  setup do
    @host = ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost")
    @acme_host = ENV.fetch("PRIVATE_BASE_STAFF_URL", "www.org.localhost")
    @staff = operators(:one)
    @token = OperatorToken.create!(staff: @staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)
    host! @host
  end

  test "sign settings activities renders sign settings authority" do
    get auth_org_settings_activities_url(ri: "jp"), headers: session_headers

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
