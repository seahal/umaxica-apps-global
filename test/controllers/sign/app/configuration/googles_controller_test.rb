# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign::App::Configuration
  class GooglesControllerTest < ActionDispatch::IntegrationTest
    fixtures :clients, :client_statuses, :client_social_google_statuses

    setup do
      host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
      @user = clients(:one)
      @headers = { "X-TEST-CURRENT-USER" => @user.id }.freeze
    end

    test "should get show when logged in" do
      get sign_app_configuration_google_url(ri: "jp"), headers: @headers

      assert_response :success
    end

    test "should show up link on show page" do
      get sign_app_configuration_google_url(ri: "jp"), headers: @headers

      assert_response :success
      assert_select "a[href=?]", sign_app_configuration_path(ri: "jp")
    end

    test "should redirect show when not logged in" do
      get sign_app_configuration_google_url(ri: "jp")

      assert_response :redirect
      assert_match %r{\Ahttps://id\.umaxica\.app/sign/in/new\?ri=jp(?:&pt=.*)?\z},
                   jump_rt_url_from_location(response.location)
    end

    test "show treats revoked google identity as unlinked" do
      ClientSocialGoogle.create!(
        user: @user,
        uid: "revoked-google-config",
        provider: "google_app",
        token: "token",
        expires_at: 1.hour.from_now.to_i,
        user_social_google_status: client_social_google_statuses(:revoked),
      )

      get sign_app_configuration_google_url(ri: "jp"), headers: @headers

      assert_response :success
      assert_select "form[action=?]", sign_app_social_authentication_path(provider: "google_app"), count: 0
      assert_select "form[action*=?]", "/social/auth/google_app/continue", count: 1
    end
  end
end
