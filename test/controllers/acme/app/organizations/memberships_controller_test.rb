# typed: false
# frozen_string_literal: true

require "test_helper"

class Acme::App::Organizations::MembershipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("ACME_SERVICE_URL", "www.app.localhost")
    @user = Client.create!(status_id: ClientStatus::ACTIVE, visibility_id: ClientVisibility::USER)
    @token = ClientToken.create!(user: @user, user_token_kind_id: ClientTokenKind::BROWSER_WEB)
    @organization_public_id = "test-org-public-id"
  end

  test "unauthenticated cannot access memberships" do
    get acme_app_organization_memberships_url(@organization_public_id, ri: "jp", host: @host),
        headers: host_headers(@host)

    assert_response :redirect
  end

  test "index returns empty json" do
    get acme_app_organization_memberships_url(@organization_public_id, ri: "jp", host: @host),
        headers: as_user_headers(@user, host: @host), as: :json

    assert_response :success
    assert_equal [], response.parsed_body
  end

  test "new renders plain text" do
    get new_acme_app_organization_membership_url(@organization_public_id, ri: "jp", host: @host),
        headers: as_user_headers(@user, host: @host)

    assert_response :success
    assert_equal "New Membership", response.body
  end

  test "edit renders plain text" do
    get edit_acme_app_organization_membership_url(@organization_public_id, "member-id", ri: "jp", host: @host),
        headers: as_user_headers(@user, host: @host)

    assert_response :success
    assert_equal "Edit Membership", response.body
  end

  test "create returns unprocessable content" do
    post acme_app_organization_memberships_url(@organization_public_id, ri: "jp", host: @host),
         headers: as_user_headers(@user, host: @host)

    assert_response :unprocessable_content
  end

  test "update returns unprocessable content" do
    patch acme_app_organization_membership_url(@organization_public_id, "member-id", ri: "jp", host: @host),
          headers: as_user_headers(@user, host: @host)

    assert_response :unprocessable_content
  end

  test "destroy returns no content" do
    delete acme_app_organization_membership_url(@organization_public_id, "member-id", ri: "jp", host: @host),
           headers: as_user_headers(@user, host: @host)

    assert_response :no_content
  end
end
