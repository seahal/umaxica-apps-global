# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign::App::Settings
  class ApplesControllerTest < ActionDispatch::IntegrationTest
    fixtures :clients, :client_statuses, :client_apple_identity_statuses

    setup do
      host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
      @user = clients(:one)
      @headers = { "X-TEST-CURRENT-USER" => @user.id }.freeze
    end

    test "should get show when logged in" do
      get sign_app_settings_apple_url(ri: "jp"), headers: @headers

      assert_response :success
    end

    test "should show up link on show page" do
      get sign_app_settings_apple_url(ri: "jp"), headers: @headers

      assert_response :success
      assert_select "a[href=?]", sign_app_settings_path(ri: "jp")
      assert_select "form[action=?][method=post]", sign_app_social_apple_connection_path(ri: "jp", intent: "link"),
                    count: 1
    end

    test "should redirect show when not logged in" do
      get sign_app_settings_apple_url(ri: "jp")

      assert_response :redirect
      uri = URI.parse(jump_rt_url_from_location(response.location))
      query = Rack::Utils.parse_nested_query(uri.query.to_s)

      assert_equal ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"), uri.host
      assert_equal "/oauth/authorize", uri.path
      assert_equal "sign-rp", query["client_id"]
    end

    test "show treats revoked apple identity as unlinked" do
      ClientAppleIdentity.create!(
        user: @user,
        uid: "revoked-apple-config",
        provider: "apple",
        token: "token",
        expires_at: 1.hour.from_now.to_i,
        user_apple_identity_status: client_apple_identity_statuses(:revoked),
      )

      get sign_app_settings_apple_url(ri: "jp"), headers: @headers

      assert_response :success
      assert_select "form[action=?]", sign_app_social_apple_disconnection_path(ri: "jp"), count: 0
      assert_select "form[action=?]", sign_app_social_apple_connection_path(ri: "jp", intent: "link"), count: 1
    end

    test "show posts apple unlink to sign authority" do
      ClientAppleIdentity.create!(
        user: @user,
        uid: "active-apple-config",
        provider: "apple",
        token: "token",
        expires_at: 1.hour.from_now.to_i,
        user_apple_identity_status: client_apple_identity_statuses(:active),
      )

      get sign_app_settings_apple_url(ri: "jp"), headers: @headers

      assert_response :success
      assert_select "form[action=?]", sign_app_social_apple_disconnection_path(ri: "jp"), count: 1
    end
  end
end
