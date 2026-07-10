# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class BasePalmSurfaceSmokeTest < ActionDispatch::IntegrationTest
  test "base app public endpoints respond on the control-plane surface" do
    host = Rails.configuration.x.boot_config.fetch(:hosts).base_service.host
    host! host

    get "/?ri=jp", headers: { "Host" => host }

    assert_response :success
    assert_homepage_html title: "Base App", message: I18n.t("landing.thin_endpoint")

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
      [ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost"), "Base App", "base.app.roots.message"],
      [ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost"), "Base Com", "base.com.roots.message"],
      [ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost"), "Base Org", "base.org.roots.message"],
    ].each do |host, title, _key|
      host! host

      get "/?ri=jp", headers: { "Host" => host }

      assert_response :success
      assert_homepage_html title: title, message: I18n.t("landing.thin_endpoint")
    end
  end

  test "palm app public endpoints and bearer profile api respond on the native surface" do
    host = ENV.fetch("PUBLIC_PALM_SERVICE_URL")
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
      "Client-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    }
  end
end
