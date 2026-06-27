# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Org::OrganizationsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  setup do
    @host = ENV.fetch("BASE_STAFF_URL", "www.org.localhost")
    @staff = operators(:one)
    @bootstrap = BaseSelectorBootstrapAuthority.call(surface: :org, principal: @staff)
  end

  test "index renders" do
    get base_org_organizations_url(ri: "jp", host: @host), headers: as_staff_headers(@staff, host: @host)

    assert_response :success
  end

  test "show resolves by public_id" do
    get "/organizations/#{@bootstrap.collective.public_id}?ri=jp", headers: as_staff_headers(@staff, host: @host)

    assert_response :success
  end

  test "unknown public_id returns 404" do
    get "/organizations/unknown-organization?ri=jp", headers: as_staff_headers(@staff, host: @host)

    assert_response :not_found
  end
end
