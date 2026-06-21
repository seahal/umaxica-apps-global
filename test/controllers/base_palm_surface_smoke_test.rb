# typed: false
# frozen_string_literal: true

require "test_helper"

class BasePalmSurfaceSmokeTest < ActionDispatch::IntegrationTest
  test "base app public endpoints respond on the control-plane surface" do
    host = ENV.fetch("BASE_SERVICE_URL", "base.app.localhost")
    host! host

    get "/", headers: { "Host" => host }

    assert_response :success
    assert_homepage_html title: "Base App", message: I18n.t("base.app.roots.message")

    get "/health", headers: { "Host" => host }

    assert_response :success

    get "/robots.txt", headers: { "Host" => host }

    assert_response :success
    assert_not_empty response.body

    get "/sitemap.xml", headers: { "Host" => host }

    assert_response :success
    assert_not_empty response.body

    post "/csp-violation-report", headers: { "Host" => host }

    assert_response :success
  end

  test "base public host family renders standalone homepages" do
    [
      [ENV.fetch("BASE_SERVICE_URL", "base.app.localhost"), "Base App", "base.app.roots.message"],
      [ENV.fetch("BASE_CORPORATE_URL", "base.com.localhost"), "Base Com", "base.com.roots.message"],
      [ENV.fetch("BASE_STAFF_URL", "base.org.localhost"), "Base Org", "base.org.roots.message"],
    ].each do |host, title, key|
      host! host

      get "/?ri=jp", headers: { "Host" => host }

      assert_response :success
      assert_homepage_html title: title, message: I18n.t(key)
    end
  end

  test "palm app public endpoints and bearer profile api respond on the native surface" do
    host = ENV.fetch("PALM_SERVICE_URL", "palm.app.localhost")
    host! host

    get "/?ri=jp", headers: { "Host" => host }

    assert_response :success
    assert_homepage_html(
      title: "Palm App",
      message: I18n.t("palm.app.roots.message"),
    )

    get "/health", headers: { "Host" => host }

    assert_response :success

    get "/api/v0/profile", headers: json_headers

    assert_response :unauthorized
    assert_equal "authentication_required", response.parsed_body.dig("error", "code")
  end

  private

  def assert_homepage_html(title:, message:)
    assert_equal "text/html", response.media_type
    assert_includes response.body, "<!doctype html>"
    assert_select "html body main section h1", text: title
    assert_select "html body main section p", text: message
    assert_select "header", count: 0
    assert_select "footer", count: 0
  end

  def json_headers
    {
      "Accept" => "application/json",
      "Content-Type" => "application/json",
      "Client-Agent" => AuthHelpers::MODERN_USER_AGENT,
    }
  end
end
