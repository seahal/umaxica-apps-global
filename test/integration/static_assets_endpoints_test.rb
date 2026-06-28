# typed: false
# frozen_string_literal: true

require "test_helper"

class StaticAssetsEndpointsTest < ActionDispatch::IntegrationTest
  ROBOTS_SURFACES = [
    {
      host: ENV.fetch("ACME_CORPORATE_URL"),
      controller: "acme/com/robots",
    },
    {
      host: ENV.fetch("ACME_STAFF_URL"),
      controller: "acme/org/robots",
    },
    {
      host: ENV.fetch("BASE_CORPORATE_URL"),
      controller: "base/com/robots",
    },
    {
      host: ENV.fetch("BASE_STAFF_URL"),
      controller: "base/org/robots",
    },
    {
      host: ENV.fetch("CORE_SERVICE_URL"),
      controller: "core/app/robots",
    },
    {
      host: ENV.fetch("CORE_CORPORATE_URL"),
      controller: "core/com/robots",
    },
    {
      host: ENV.fetch("CORE_STAFF_URL"),
      controller: "core/org/robots",
    },
    {
      host: ENV.fetch("PALM_SERVICE_URL"),
      controller: "palm/app/robots",
    },
  ].freeze

  SITEMAP_SURFACES = [
    {
      host: ENV.fetch("ACME_CORPORATE_URL"),
      controller: "acme/com/sitemaps",
    },
    {
      host: ENV.fetch("ACME_STAFF_URL"),
      controller: "acme/org/sitemaps",
    },
    {
      host: ENV.fetch("BASE_CORPORATE_URL"),
      controller: "base/com/sitemaps",
    },
    {
      host: ENV.fetch("BASE_STAFF_URL"),
      controller: "base/org/sitemaps",
    },
    {
      host: ENV.fetch("PALM_SERVICE_URL"),
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
    host! ENV.fetch("PALM_SERVICE_URL")

    get "/sitemap.xml"

    cache_control = response.headers["Cache-Control"]

    assert_not_nil cache_control
    assert_match(/public/, cache_control)
    assert_match(/max-age=300/, cache_control)
    assert_match(/s-maxage=600/, cache_control)
    assert_equal "600", response.headers["Surrogate-Control"][("max-age=".size)..]
  end
end
