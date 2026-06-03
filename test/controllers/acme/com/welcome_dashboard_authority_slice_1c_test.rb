# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::Com::WelcomeDashboardAuthoritySlice1CTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
    @visitor = create_verified_visitor_with_email(email_address: "acme-dashboard-#{SecureRandom.hex(4)}@example.com")
    @visitor.visitor_telephones.create!(
      number: "+8190#{SecureRandom.random_number(10**8).to_s.rjust(8, "0")}",
      visitor_telephone_status_id: VisitorTelephoneStatus::VERIFIED,
    )
  end

  test "dashboard_requires_authentication" do
    get acme_com_dashboard_url(ri: "jp"), headers: host_headers(@host)

    assert_response :redirect
  end

  test "dashboard_renders_when_signed_in" do
    token = VisitorToken.create!(visitor: @visitor, visitor_token_kind_id: VisitorTokenKind::BROWSER_WEB)

    get acme_com_dashboard_url(ri: "jp"), headers: session_headers(token)

    assert_response :success
    assert_select "h1", "Dashboard"
    assert_no_match(/id\.umaxica/, response.body)
    assert_select "a[href=?]", acme_com_settings_path(ri: "jp")
  end

  test "welcome_route_exists" do
    route = Rails.application.routes.recognize_path(
      "https://#{@host}/welcome",
      method: :get,
    )

    assert_equal "acme/com/welcomes", route.fetch(:controller)
  end

  private

  def session_headers(token)
    {
      "Host" => @host,
      "X-TEST-CURRENT-RESOURCE" => @visitor.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
  end
end
