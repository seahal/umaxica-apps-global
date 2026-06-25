# typed: false
# frozen_string_literal: true

require "test_helper"

module Sign::App::Settings
  class ApplesControllerTest < ActionDispatch::IntegrationTest
    fixtures :clients, :client_statuses, :client_apple_identity_statuses

    setup do
      host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
      @user = clients(:one)
      @headers = as_user_headers(@user, host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"))
    end

    test "show is read only" do
      get sign_app_settings_apple_url(ri: "jp"), headers: @headers

      assert_response :success
      assert_select "a[href=?]", sign_app_settings_path(ri: "jp")
      assert_select "a[href=?]", edit_sign_app_settings_apple_path(ri: "jp")
      assert_select "form[action=?]", sign_app_settings_apple_path(ri: "jp"), count: 0
    end

    test "show redirects when not logged in" do
      get sign_app_settings_apple_url(ri: "jp")

      assert_response :redirect
      uri = URI.parse(jump_rt_url_from_location(response.location))
      query = Rack::Utils.parse_nested_query(uri.query.to_s)

      assert_equal ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"), uri.host
      assert_equal "/oauth/authorize", uri.path
      assert_equal "sign-rp", query["client_id"]
    end

    test "edit redirects to verification when step-up is missing" do
      get edit_sign_app_settings_apple_url(ri: "jp"), headers: @headers

      assert_response :redirect
      assert_match %r{/verification}, response.location
    end

    test "edit renders mutation controls when step-up is satisfied" do
      token = ClientToken.find_by!(public_id: @headers["X-TEST-SESSION-PUBLIC-ID"])
      mark_token_step_up_satisfied_for_test(token, scope: SocialAuth::SOCIAL_LINK_SCOPE)

      get edit_sign_app_settings_apple_url(ri: "jp"), headers: @headers

      assert_response :success
      assert_select "form[action=?]", sign_app_settings_apple_path(ri: "jp"), count: 1
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
      assert_select "a[href=?]", edit_sign_app_settings_apple_path(ri: "jp")
    end

    test "settings route uses update and destroy" do
      route = Rails.application.routes.recognize_path(
        "http://#{ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")}/settings/apple",
        method: :patch,
      )

      assert_equal "sign/app/settings/apples", route[:controller]
      assert_equal "update", route[:action]

      route = Rails.application.routes.recognize_path(
        "http://#{ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")}/settings/apple",
        method: :delete,
      )

      assert_equal "sign/app/settings/apples", route[:controller]
      assert_equal "destroy", route[:action]
    end
  end
end
