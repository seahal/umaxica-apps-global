# typed: false
# frozen_string_literal: true

require "test_helper"

class Sign::Org::DashboardsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators

  setup do
    @host = ENV.fetch("ID_STAFF_URL", "id.org.localhost")
    @acme_host = ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
    @staff = operators(:one)
  end

  test "show_redirects_to_acme_dashboard_authority" do
    get sign_org_dashboard_url(ri: "jp"), headers: as_staff_headers(@staff, host: @host)

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
