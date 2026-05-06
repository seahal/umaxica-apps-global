# typed: false
# frozen_string_literal: true

require "test_helper"

class Apex::App::Edge::V0::CookieControllerTest < ActionDispatch::IntegrationTest
  include PreferenceJwtHelper

  setup do
    @host = ENV.fetch("APEX_SERVICE_URL", "www.app.localhost")
    host! @host
  end

  test "GET show returns 200 with boolean show_banner" do
    get apex_app_edge_v0_cookie_path, as: :json

    assert_response :ok
    assert_includes [true, false], response.parsed_body["show_banner"]
  end

  test "PATCH update returns 200 with boolean show_banner and sets preference_consented cookie" do
    preference = AppPreference.create!(status_id: AppPreferenceStatus::NOTHING)
    AppPreferenceCookie.create!(
      preference: preference,
      targetable: false,
      performant: false,
      functional: false,
      consented: false,
      consented_at: nil,
    )
    token = encode_preference_jwt(
      preferences: { "consented" => false },
      host: @host,
      public_id: preference.public_id,
    )
    cookies[Preference::CookieName.access] = token

    with_preference_jwt_keys(host: @host) do
      patch apex_app_edge_v0_cookie_path,
            params: { consented: true },
            headers: json_headers(with_csrf: true),
            as: :json
    end

    assert_response :ok
    assert_includes [true, false], response.parsed_body["show_banner"]
    assert_includes response.headers["Set-Cookie"].to_s, "preference_consented="
  end

  test "PATCH update without CSRF token returns 422" do
    with_forgery_protection do
      patch apex_app_edge_v0_cookie_path,
            params: { consented: true },
            headers: json_headers(with_csrf: false),
            as: :json
    end

    assert_response :unprocessable_content
  end

  private

  def json_headers(with_csrf:)
    headers = { "Host" => @host, "Accept" => "application/json" }
    if with_csrf
      cookies["csrf_token"] = csrf_token
      headers["X-CSRF-Token"] = csrf_token
    end
    headers
  end

  def csrf_token
    @csrf_token ||= "test_csrf_token"
  end

  def with_forgery_protection
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection = original
  end
end
