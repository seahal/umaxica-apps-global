# typed: false
# frozen_string_literal: true

require "test_helper"

class StaticAssetsEndpointsTest < ActionDispatch::IntegrationTest
  ROBOTS_SURFACES = [
    {
      host: ENV.fetch("PRIVATE_ACME_CORPORATE_URL", "www.com.localhost"),
      controller: "acme/com/robots",
    },
    {
      host: ENV.fetch("PRIVATE_ACME_STAFF_URL", "www.org.localhost"),
      controller: "acme/org/robots",
    },
    {
      host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost"),
      controller: "base/com/robots",
    },
    {
      host: ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost"),
      controller: "base/org/robots",
    },
    {
      host: ENV.fetch("PUBLIC_CORE_SERVICE_URL", "core.app.localhost"),
      controller: "core/app/robots",
    },
    {
      host: ENV.fetch("PUBLIC_CORE_CORPORATE_URL", "core.com.localhost"),
      controller: "core/com/robots",
    },
    {
      host: ENV.fetch("PUBLIC_CORE_STAFF_URL", "core.org.localhost"),
      controller: "core/org/robots",
    },
    {
      host: ENV.fetch("PUBLIC_PALM_SERVICE_URL"),
      controller: "palm/app/robots",
    },
  ].freeze

  SITEMAP_SURFACES = [
    {
      host: ENV.fetch("PRIVATE_ACME_CORPORATE_URL", "www.com.localhost"),
      controller: "acme/com/sitemaps",
    },
    {
      host: ENV.fetch("PRIVATE_ACME_STAFF_URL", "www.org.localhost"),
      controller: "acme/org/sitemaps",
    },
    {
      host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost"),
      controller: "base/com/sitemaps",
    },
    {
      host: ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost"),
      controller: "base/org/sitemaps",
    },
    {
      host: ENV.fetch("PUBLIC_PALM_SERVICE_URL"),
      controller: "palm/app/sitemaps",
    },
  ].freeze

  test "robots.txt is served on every configured surface" do
    ROBOTS_SURFACES.each do |surface|
      host! surface[:host]

      get "/robots.txt"

      assert_response :success
      assert_equal "text/plain", response.media_type
      assert_includes response.body, "User-agent:"

      assert_equal "index", @request.params[:action]
      assert_equal surface[:controller], @request.params[:controller]
    end
  end

  test "sitemap.xml is served on every surface that provides a template" do
    SITEMAP_SURFACES.each do |surface|
      host! surface[:host]

      get "/sitemap.xml"

      assert_response :success
      assert_equal "application/xml", response.media_type
      assert_includes response.body, "<urlset"

      assert_equal "show", @request.params[:action]
      assert_equal surface[:controller], @request.params[:controller]
    end
  end

  test "robots and sitemap responses set long cache headers" do
    host! ENV.fetch("PUBLIC_PALM_SERVICE_URL")

    get "/sitemap.xml"

    cache_control = response.headers["Cache-Control"]

    assert_not_nil cache_control
    assert_match(/public/, cache_control)
    assert_match(/max-age=300/, cache_control)
    assert_match(/s-maxage=600/, cache_control)
    assert_equal "600", response.headers["Surrogate-Control"][("max-age=".size)..]
  end
end
