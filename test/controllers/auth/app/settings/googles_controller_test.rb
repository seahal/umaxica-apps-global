# typed: false
# frozen_string_literal: true

require "test_helper"

module Auth::App::Settings
  class GooglesControllerTest < ActionDispatch::IntegrationTest
    fixtures :clients, :client_statuses, :client_google_identity_statuses

    setup do
      host! ENV.fetch("ID_SERVICE_URL", "id.app.localhost")
      @user = clients(:one)
      @headers = as_user_headers(@user, host: ENV.fetch("ID_SERVICE_URL", "id.app.localhost"))
    end

    test "show is read only" do
      get auth_app_settings_google_url(ri: "jp"), headers: @headers

      assert_response :success
      assert_select "a[href=?]", auth_app_settings_path(ri: "jp")
      assert_select "a[href=?]", edit_auth_app_settings_google_path(ri: "jp")
      assert_select "form[action=?]", auth_app_settings_google_path(ri: "jp"), count: 0
    end

    test "show redirects when not logged in" do
      get auth_app_settings_google_url(ri: "jp")

      assert_response :redirect
      uri = URI.parse(jump_rt_url_from_location(response.location))
      query = Rack::Utils.parse_nested_query(uri.query.to_s)

      assert_equal ENV.fetch("ACME_SERVICE_URL", "www.app.localhost"), uri.host
      assert_equal "/oauth/authorize", uri.path
      assert_equal "sign-rp", query["client_id"]
    end

    test "edit redirects to verification when step-up is missing" do
      get edit_auth_app_settings_google_url(ri: "jp"), headers: @headers

      assert_response :redirect
      assert_match %r{/verification}, response.location
    end

    test "verification accepts google edit return target for social link step-up" do
      get edit_auth_app_settings_google_url(ri: "jp"), headers: @headers

      assert_response :redirect
      verification_location = response.location

      get verification_location, headers: @headers

      assert_response :success
      assert_equal "/verification", URI.parse(verification_location).path
    end

    test "edit renders mutation controls when step-up is satisfied" do
      token = ClientToken.find_by!(public_id: @headers["X-TEST-SESSION-PUBLIC-ID"])
      mark_token_step_up_satisfied_for_test(token, scope: SocialAuth::SOCIAL_LINK_SCOPE)

      get edit_auth_app_settings_google_url(ri: "jp"), headers: @headers

      assert_response :success
      assert_select "form[action=?]", auth_app_settings_google_path(ri: "jp"), count: 1
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

      get auth_app_settings_google_url(ri: "jp"), headers: @headers

      assert_response :success
      assert_select "a[href=?]", edit_auth_app_settings_google_path(ri: "jp")
    end

    test "settings route uses create and destroy" do
      route = Rails.application.routes.recognize_path(
        "http://#{ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")}/settings/google",
        method: :post,
      )

      assert_equal "sign/app/settings/googles", route[:controller]
      assert_equal "create", route[:action]

      route = Rails.application.routes.recognize_path(
        "http://#{ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")}/settings/google",
        method: :delete,
      )

      assert_equal "sign/app/settings/googles", route[:controller]
      assert_equal "destroy", route[:action]

      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path(
          "http://#{ENV.fetch("SIGN_SERVICE_URL", "id.app.localhost")}/settings/google",
          method: :patch,
        )
      end
    end
  end
end
