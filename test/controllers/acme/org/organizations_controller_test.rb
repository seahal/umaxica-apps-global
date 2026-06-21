# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::Org::OrganizationsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  setup do
    @host = ENV.fetch("ACME_STAFF_URL", "www.org.localhost")
    @staff = operators(:one)
    @organization_public_id = "test-org-public-id"
  end

  test "unauthenticated cannot access organizations" do
    get acme_org_organizations_url(ri: "jp", host: @host), headers: host_headers(@host)

    assert_response :redirect
  end

  test "index renders" do
    get acme_org_organizations_url(ri: "jp", host: @host), headers: as_staff_headers(@staff, host: @host)

    assert_response :success
  end

  test "show renders" do
    get acme_org_organization_url(@organization_public_id, ri: "jp", host: @host),
        headers: as_staff_headers(@staff, host: @host)

    assert_response :success
  end

  test "new renders" do
    get new_acme_org_organization_url(ri: "jp", host: @host), headers: as_staff_headers(@staff, host: @host)

    assert_response :success
  end

  test "edit renders" do
    get edit_acme_org_organization_url(@organization_public_id, ri: "jp", host: @host),
        headers: as_staff_headers(@staff, host: @host)

    assert_response :success
  end

  test "create redirects" do
    post acme_org_organizations_url(ri: "jp", host: @host), headers: as_staff_headers(@staff, host: @host)

    assert_response :see_other
    assert_redirected_to acme_org_organizations_url(ri: "jp", host: @host)
  end

  test "update redirects" do
    patch acme_org_organization_url(@organization_public_id, ri: "jp", host: @host),
          headers: as_staff_headers(@staff, host: @host)

    assert_response :see_other
    assert_redirected_to acme_org_organization_url(@organization_public_id, ri: "jp", host: @host)
  end
end
