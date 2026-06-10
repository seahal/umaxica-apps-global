# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign::App::Settings
  class GooglesControllerTest < ActionDispatch::IntegrationTest
    fixtures :clients, :client_statuses, :client_google_identity_statuses

    setup do
      host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
      @user = clients(:one)
      @headers = { "X-TEST-CURRENT-USER" => @user.id }.freeze
    end

    test "should get show when logged in" do
      get sign_app_settings_google_url(ri: "jp"), headers: @headers

      assert_response :success
    end

    test "should show up link on show page" do
      get sign_app_settings_google_url(ri: "jp"), headers: @headers

      assert_response :success
      assert_select "a[href=?]", sign_app_settings_path(ri: "jp")
    end

    test "should redirect show when not logged in" do
      get sign_app_settings_google_url(ri: "jp")

      assert_response :redirect
      assert_match %r{\Ahttps://id\.umaxica\.app/sign/in/entrance\?ri=jp(?:&pt=.*)?\z},
                   jump_rt_url_from_location(response.location)
    end

    test "show treats revoked google identity as unlinked" do
      ClientGoogleIdentity.create!(
        user: @user,
        uid: "revoked-google-config",
        provider: "google_app",
        token: "token",
        expires_at: 1.hour.from_now.to_i,
        user_google_identity_status: client_google_identity_statuses(:revoked),
      )

      get sign_app_settings_google_url(ri: "jp"), headers: @headers

      assert_response :success
      assert_select "form[action=?]", sign_app_social_google_disconnection_attempt_path(ri: "jp"), count: 0
      assert_select "form[action=?]", sign_app_social_google_connection_attempt_path(ri: "jp", intent: "link"), count: 1
    end

    test "show posts google unlink to sign authority" do
      ClientGoogleIdentity.create!(
        user: @user,
        uid: "active-google-config",
        provider: "google_app",
        token: "token",
        expires_at: 1.hour.from_now.to_i,
        user_google_identity_status: client_google_identity_statuses(:active),
      )

      get sign_app_settings_google_url(ri: "jp"), headers: @headers

      assert_response :success
      assert_select "form[action=?]", sign_app_social_google_disconnection_attempt_path(ri: "jp"), count: 1
    end
  end
end
