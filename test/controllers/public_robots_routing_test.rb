# typed: false
# frozen_string_literal: true

require "test_helper"

class PublicRobotsRoutingTest < ActionDispatch::IntegrationTest
  test "acme surfaces define public file helpers" do
    assert_public_file_helpers(
      robots: %i(acme_com_robots_path acme_app_robots_path acme_org_robots_path),
      sitemap: %i(acme_com_sitemap_path acme_app_sitemap_path acme_org_sitemap_path),
    )
  end

  test "sign surfaces define public file helpers" do
    assert_public_file_helpers(
      robots: %i(sign_com_robots_path sign_app_robots_path sign_org_robots_path),
      sitemap: %i(sign_com_sitemap_path sign_app_sitemap_path sign_org_sitemap_path),
    )
  end

  test "new base palm and content surfaces define robots helpers" do
    assert_public_file_helpers(
      robots: %i(
        base_app_robots_path base_com_robots_path base_org_robots_path
        palm_app_robots_path palm_com_robots_path palm_org_robots_path
        help_app_robots_path help_com_robots_path help_org_robots_path
        docs_app_robots_path docs_com_robots_path docs_org_robots_path
        news_app_robots_path news_com_robots_path news_org_robots_path
      ),
      sitemap: [],
    )
  end

  test "public file endpoints respond without redirect" do
    endpoints = [
      [method(:base_app_robots_url), ENV["BASE_SERVICE_URL"] || "base.app.localhost", "robots"],
      [method(:base_com_robots_url), ENV["BASE_CORPORATE_URL"] || "base.com.localhost", "robots"],
      [method(:base_org_robots_url), ENV["BASE_STAFF_URL"] || "base.org.localhost", "robots"],
      [method(:palm_app_robots_url), ENV["PALM_SERVICE_URL"] || "palm.app.localhost", "robots"],
      [method(:palm_com_robots_url), ENV["PALM_CORPORATE_URL"] || "palm.com.localhost", "robots"],
      [method(:palm_org_robots_url), ENV["PALM_STAFF_URL"] || "palm.org.localhost", "robots"],
      [method(:help_app_robots_url), ENV["HELP_SERVICE_URL"] || "help.app.localhost", "robots"],
      [method(:help_com_robots_url), ENV["HELP_CORPORATE_URL"] || "help.com.localhost", "robots"],
      [method(:help_org_robots_url), ENV["HELP_STAFF_URL"] || "help.org.localhost", "robots"],
      [method(:docs_app_robots_url), ENV["DOCS_SERVICE_URL"] || "docs.app.localhost", "robots"],
      [method(:docs_com_robots_url), ENV["DOCS_CORPORATE_URL"] || "docs.com.localhost", "robots"],
      [method(:docs_org_robots_url), ENV["DOCS_STAFF_URL"] || "docs.org.localhost", "robots"],
      [method(:news_app_robots_url), ENV["NEWS_SERVICE_URL"] || "news.app.localhost", "robots"],
      [method(:news_com_robots_url), ENV["NEWS_CORPORATE_URL"] || "news.com.localhost", "robots"],
      [method(:news_org_robots_url), ENV["NEWS_STAFF_URL"] || "news.org.localhost", "robots"],
      [method(:acme_com_robots_url), ENV["ACME_CORPORATE_URL"] || "www.com.localhost", "robots"],
      [method(:acme_app_robots_url), ENV["ACME_SERVICE_URL"] || "www.app.localhost", "robots"],
      [method(:acme_org_robots_url), ENV["ACME_STAFF_URL"] || "www.org.localhost", "robots"],
      [method(:sign_com_robots_url), ENV["ID_CORPORATE_URL"] || "id.com.localhost", "robots"],
      [method(:sign_app_robots_url), ENV["ID_SERVICE_URL"] || "id.app.localhost", "robots"],
      [method(:sign_org_robots_url), ENV["ID_STAFF_URL"] || "id.org.localhost", "robots"],
      [method(:acme_com_sitemap_url), ENV["ACME_CORPORATE_URL"] || "www.com.localhost", "sitemap"],
      [method(:acme_app_sitemap_url), ENV["ACME_SERVICE_URL"] || "www.app.localhost", "sitemap"],
      [method(:acme_org_sitemap_url), ENV["ACME_STAFF_URL"] || "www.org.localhost", "sitemap"],
      [method(:sign_com_sitemap_url), ENV["ID_CORPORATE_URL"] || "id.com.localhost", "sitemap"],
      [method(:sign_app_sitemap_url), ENV["ID_SERVICE_URL"] || "id.app.localhost", "sitemap"],
      [method(:sign_org_sitemap_url), ENV["ID_STAFF_URL"] || "id.org.localhost", "sitemap"],
    ]

    endpoints.each do |helper, host, kind|
      host! host
      get helper.call(ri: "jp"), headers: browser_headers

      assert_response :success
      assert_not_predicate response, :redirect?
      if kind == "robots"
        assert_equal "text/plain; charset=utf-8", response.content_type
        assert_equal "User-agent: *\nDisallow:\n", response.body
      else
        assert_equal "application/xml; charset=utf-8", response.content_type
      end
    end
  end

  private

  def assert_public_file_helpers(robots:, sitemap:)
    robots.each do |helper|
      assert_respond_to self, helper
      assert_equal "/robots.txt", public_send(helper)
    end

    sitemap.each do |helper|
      assert_respond_to self, helper
      assert_equal "/sitemap.xml", public_send(helper)
    end
  end
end
