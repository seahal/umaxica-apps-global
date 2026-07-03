# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceWebCsrfTest < ActionDispatch::IntegrationTest
  test "app web preference PATCH endpoints reject missing CSRF token" do
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    host!(ENV.fetch("PUBLIC_BASE_SERVICE_URL"))

    patch(base_app_web_v0_theme_path, params: { theme: "dark" }, headers: { "Accept" => "application/json" }, as: :json)

    assert_response :unprocessable_content

    patch(
      base_app_web_v0_cookie_path, params: { consented: true }, headers: { "Accept" => "application/json" },
                                   as: :json,
    )

    assert_response :unprocessable_content
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  test "com web preference PATCH endpoints reject missing CSRF token" do
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    host!(ENV.fetch("PUBLIC_BASE_CORPORATE_URL"))

    patch(base_com_web_v0_theme_path, params: { theme: "dark" }, headers: { "Accept" => "application/json" }, as: :json)

    assert_response :unprocessable_content

    patch(
      base_com_web_v0_cookie_path, params: { consented: true }, headers: { "Accept" => "application/json" },
                                   as: :json,
    )

    assert_response :unprocessable_content
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  test "org web preference PATCH endpoints reject missing CSRF token" do
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    host!(ENV.fetch("PUBLIC_BASE_STAFF_URL"))

    patch(base_org_web_v0_theme_path, params: { theme: "dark" }, headers: { "Accept" => "application/json" }, as: :json)

    assert_response :unprocessable_content

    patch(
      base_org_web_v0_cookie_path, params: { consented: true }, headers: { "Accept" => "application/json" },
                                   as: :json,
    )

    assert_response :unprocessable_content
  ensure
    ActionController::Base.allow_forgery_protection = original
  end
end
