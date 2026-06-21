# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::Com::OrganizationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ACME_CORPORATE_URL", "www.com.localhost")
    @visitor = create_verified_visitor_with_email(email_address: "com-org@example.com")
    @organization_public_id = "test-org-public-id"
  end

  test "unauthenticated cannot access organizations" do
    get acme_com_organizations_url(ri: "jp", host: @host), headers: host_headers(@host)

    assert_response :redirect
  end

  test "index renders" do
    get acme_com_organizations_url(ri: "jp", host: @host), headers: as_visitor_headers(@visitor, host: @host)

    assert_response :success
  end

  test "show renders" do
    get acme_com_organization_url(@organization_public_id, ri: "jp", host: @host),
        headers: as_visitor_headers(@visitor, host: @host)

    assert_response :success
  end

  test "new renders" do
    get new_acme_com_organization_url(ri: "jp", host: @host), headers: as_visitor_headers(@visitor, host: @host)

    assert_response :success
  end

  test "edit renders" do
    get edit_acme_com_organization_url(@organization_public_id, ri: "jp", host: @host),
        headers: as_visitor_headers(@visitor, host: @host)

    assert_response :success
  end

  test "create redirects" do
    post acme_com_organizations_url(ri: "jp", host: @host), headers: as_visitor_headers(@visitor, host: @host)

    assert_response :see_other
    assert_redirected_to acme_com_organizations_url(ri: "jp", host: @host)
  end

  test "update redirects" do
    patch acme_com_organization_url(@organization_public_id, ri: "jp", host: @host),
          headers: as_visitor_headers(@visitor, host: @host)

    assert_response :see_other
    assert_redirected_to acme_com_organization_url(@organization_public_id, ri: "jp", host: @host)
  end
end
