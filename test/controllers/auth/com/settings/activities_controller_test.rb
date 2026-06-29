# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class Auth::Com::Settings::ActivitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost")
    @visitor = create_verified_visitor_with_email(email_address: "activities-#{SecureRandom.hex(4)}@example.com")
    @visitor.visitor_telephones.create!(
      number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
    @token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)
    host! @host
  end

  test "sign settings activities renders sign authority" do
    get auth_com_settings_activities_url(ri: "jp"), headers: session_headers

    assert_response :success
    assert_select "h1"
  end

  private

  def session_headers
    {
      "Host" => @host,
      "X-TEST-CURRENT-RESOURCE" => @visitor.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => @token.public_id,
    }
  end
end
