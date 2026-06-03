# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::Org::WelcomeDashboardAuthoritySlice1CTest < ActionDispatch::IntegrationTest
  fixtures :operators

  setup do
    @host = ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
    @staff = operators(:one)
    OperatorToken.where(staff: @staff).delete_all
  end

  test "dashboard_requires_authentication" do
    get acme_org_dashboard_url(ri: "jp"), headers: host_headers(@host)

    assert_response :redirect
  end

  test "dashboard_renders_when_signed_in" do
    token = OperatorToken.create!(staff: @staff, staff_token_kind_id: OperatorTokenKind::BROWSER_WEB)

    get acme_org_dashboard_url(ri: "jp"), headers: session_headers(token)

    assert_response :success
    assert_select "h1", "Dashboard"
  end

  test "welcome_route_exists" do
    route = Rails.application.routes.recognize_path(
      "https://#{@host}/welcome",
      method: :get,
    )

    assert_equal "acme/org/welcomes", route.fetch(:controller)
  end

  private

  def session_headers(token)
    {
      "Host" => @host,
      "X-TEST-CURRENT-STAFF" => @staff.id.to_s,
      "X-TEST-SESSION-PUBLIC-ID" => token.public_id,
    }
  end
end
