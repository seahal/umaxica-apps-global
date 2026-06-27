# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::Org::Organizations::MembershipsControllerTest < ActionDispatch::IntegrationTest
  fixtures :operators, :operator_statuses

  setup do
    @host = ENV.fetch("BASE_STAFF_URL", "www.org.localhost")
    @staff = operators(:one)
    @organization_public_id = "test-org-public-id"
  end

  test "unauthenticated cannot access memberships" do
    get base_org_organization_memberships_url(@organization_public_id, ri: "jp", host: @host),
        headers: host_headers(@host)

    assert_response :redirect
  end

  test "index returns empty json" do
    get base_org_organization_memberships_url(@organization_public_id, ri: "jp", host: @host),
        headers: as_staff_headers(@staff, host: @host), as: :json

    assert_response :success
    assert_equal [], response.parsed_body
  end

  test "new renders plain text" do
    get new_base_org_organization_membership_url(@organization_public_id, ri: "jp", host: @host),
        headers: as_staff_headers(@staff, host: @host)

    assert_response :success
    assert_equal "New Membership", response.body
  end

  test "edit renders plain text" do
    get edit_base_org_organization_membership_url(@organization_public_id, "member-id", ri: "jp", host: @host),
        headers: as_staff_headers(@staff, host: @host)

    assert_response :success
    assert_equal "Edit Membership", response.body
  end

  test "create returns unprocessable content" do
    post base_org_organization_memberships_url(@organization_public_id, ri: "jp", host: @host),
         headers: as_staff_headers(@staff, host: @host)

    assert_response :unprocessable_content
  end

  test "update returns unprocessable content" do
    patch base_org_organization_membership_url(@organization_public_id, "member-id", ri: "jp", host: @host),
          headers: as_staff_headers(@staff, host: @host)

    assert_response :unprocessable_content
  end

  test "destroy returns no content" do
    delete base_org_organization_membership_url(@organization_public_id, "member-id", ri: "jp", host: @host),
           headers: as_staff_headers(@staff, host: @host)

    assert_response :no_content
  end
end
