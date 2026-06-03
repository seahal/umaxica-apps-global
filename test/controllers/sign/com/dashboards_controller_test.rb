# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Com::DashboardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ID_CORPORATE_URL", "id.com.localhost")
    @acme_host = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
    @visitor = create_verified_visitor_with_email(email_address: "dashboard-#{SecureRandom.hex(4)}@example.com")
  end

  test "show_redirects_to_acme_dashboard_authority" do
    get sign_com_dashboard_url(ri: "jp"), headers: as_visitor_headers(@visitor, host: @host)

    assert_redirect_to_acme_dashboard
  end

  private

  def assert_redirect_to_acme_dashboard
    assert_response :see_other
    location = URI.parse(response.location)

    assert_equal @acme_host, location.host
    assert_equal "/dashboard", location.path
    assert_equal "ri=jp", location.query
  end
end
