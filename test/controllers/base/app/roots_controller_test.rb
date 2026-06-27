# typed: false
# frozen_string_literal: true

require "test_helper"

class Base::App::RootsControllerTest < ActionDispatch::IntegrationTest
  fixtures :clients, :client_statuses

  test "renders a thin landing page" do
    host! ENV.fetch("BASE_SERVICE_URL", "www.app.localhost")
    get base_app_root_url(ri: "jp")

    assert_response :success
    assert_select "title", "Base App"
    assert_select "h1", text: "Base App"
    assert_select "main p", text: /Thin landing endpoint/
  end

  test "auth authorize preserves app sign up and sign in screen hints" do
    host! ENV.fetch("BASE_SERVICE_URL", "www.app.localhost")

    get base_app_oidc_authorization_url(ri: "jp", screen_hint: "signup")

    assert_response :redirect
    signup_uri = URI.parse(jump_rt_url_from_location(response.location))
    signup_query = Rack::Utils.parse_nested_query(signup_uri.query)

    assert_equal "signup", signup_query["screen_hint"]
    assert_equal "/dashboard?ri=jp", session[:oidc_pt]

    get base_app_oidc_authorization_url(ri: "jp", screen_hint: "signin")

    assert_response :redirect
    signin_uri = URI.parse(jump_rt_url_from_location(response.location))
    signin_query = Rack::Utils.parse_nested_query(signin_uri.query)

    assert_equal "signin", signin_query["screen_hint"]
    assert_equal "/dashboard?ri=jp", session[:oidc_pt]
  end

  test "creates preference cookies on root" do
    host! ENV.fetch("BASE_SERVICE_URL", "www.app.localhost")

    assert_difference("AppPreference.count", 1) do
      get base_app_root_url(ri: "jp")
    end

    assert_response :success
    assert_predicate cookies[PreferenceCookieName.access(surface: :app)], :present?
    assert_predicate cookies[PreferenceCookieName.refresh(surface: :app)], :present?
  end

  test "creates preference cookies on root when optional URL preferences are present" do
    host! ENV.fetch("BASE_SERVICE_URL", "www.app.localhost")

    assert_difference("AppPreference.count", 1) do
      get base_app_root_url(ct: "dr", lx: "en", ri: "us", tz: "asia/tokyo")
    end

    assert_response :success
    assert_predicate cookies[PreferenceCookieName.access(surface: :app)], :present?
    assert_predicate cookies[PreferenceCookieName.refresh(surface: :app)], :present?
  end

  test "redirects to dashboard when logged in" do
    host! ENV.fetch("BASE_SERVICE_URL", "www.app.localhost")
    user = clients(:one)

    get base_app_root_url(ri: "jp"),
        headers: as_user_headers(user, host: ENV.fetch("BASE_SERVICE_URL", "www.app.localhost"))

    assert_response :redirect
    assert_redirected_to base_app_dashboard_url(ri: "jp", host: ENV.fetch("BASE_SERVICE_URL", "www.app.localhost"))
  end
end
