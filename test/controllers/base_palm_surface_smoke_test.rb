# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class BasePalmSurfaceSmokeTest < ActionDispatch::IntegrationTest
  test "base app public endpoints respond on the control-plane surface" do
    host = Rails.configuration.x.boot_config.fetch(:hosts).base_service.host
    host! host

    get "/?ri=jp", headers: { "Host" => host }

    # The gateway root canonicalizes to the regional root instead of serving a page.
    assert_response :moved_permanently
    assert_equal "https://jp.umaxica.app/", response.location

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

  test "base public host family canonicalizes to its regional roots" do
    [
      [ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost"), "https://jp.umaxica.app/"],
      [ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost"), "https://jp.umaxica.com/"],
      [ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost"), "https://jp.umaxica.org/"],
    ].each do |host, expected_location|
      host! host

      get "/?ri=jp", headers: { "Host" => host }

      assert_response :moved_permanently
      assert_equal expected_location, response.location
    end
  end

  test "palm app public endpoints and bearer profile api respond on the native surface" do
    host = ENV.fetch("PUBLIC_PALM_SERVICE_URL")
    host! host

    get "/?ri=jp", headers: { "Host" => host }

    assert_response :success
    assert_homepage_html(
      component: "palm/app/roots/index",
      heading: "Palm App",
      message: I18n.t("palm.app.roots.message"),
    )

    get "/health", headers: { "Host" => host }

    assert_response :success

    get "/api/v0/profile", headers: json_headers

    assert_response :unauthorized
    assert_equal "urn:umaxica:problem:authentication-required", response.parsed_body.fetch("type")
  end

  private

  # The landing is an Inertia page now, so its content lives in the page object props and the
  # header and footer are the React surface layout's, not the document's.
  def assert_homepage_html(component:, heading:, message:)
    assert_equal "text/html", response.media_type
    assert_includes response.body, "<!DOCTYPE html>"
    assert_equal component, inertia_component
    assert_equal heading, inertia_props.fetch("heading")
    assert_equal message, inertia_props.fetch("description")
    assert_select "body header", count: 0
    assert_select "body footer", count: 0
  end

  def json_headers
    {
      "Accept" => "application/json",
      "Content-Type" => "application/json",
      "Client-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    }
  end
end
