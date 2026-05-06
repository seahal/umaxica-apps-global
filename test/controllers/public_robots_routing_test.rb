# typed: false
# frozen_string_literal: true

require "test_helper"

class PublicRobotsRoutingTest < ActionDispatch::IntegrationTest
  test "apex surfaces define public file helpers" do
    assert_public_file_helpers(
      robots: %i(apex_com_robots_path apex_app_robots_path apex_org_robots_path),
      sitemap: %i(apex_com_sitemap_path apex_app_sitemap_path apex_org_sitemap_path),
    )
  end

  test "sign surfaces define public file helpers" do
    assert_public_file_helpers(
      robots: %i(sign_com_robots_path sign_app_robots_path sign_org_robots_path),
      sitemap: %i(sign_com_sitemap_path sign_app_sitemap_path sign_org_sitemap_path),
    )
  end

  test "public file endpoints respond without redirect" do
    endpoints = [
      [method(:apex_com_robots_url), ENV["APEX_CORPORATE_URL"] || "www.com.localhost", "robots"],
      [method(:apex_app_robots_url), ENV["APEX_SERVICE_URL"] || "www.app.localhost", "robots"],
      [method(:apex_org_robots_url), ENV["APEX_STAFF_URL"] || "www.org.localhost", "robots"],
      [method(:sign_com_robots_url), ENV["ID_CORPORATE_URL"] || "id.com.localhost", "robots"],
      [method(:sign_app_robots_url), ENV["ID_SERVICE_URL"] || "id.app.localhost", "robots"],
      [method(:sign_org_robots_url), ENV["ID_STAFF_URL"] || "id.org.localhost", "robots"],
      [method(:apex_com_sitemap_url), ENV["APEX_CORPORATE_URL"] || "www.com.localhost", "sitemap"],
      [method(:apex_app_sitemap_url), ENV["APEX_SERVICE_URL"] || "www.app.localhost", "sitemap"],
      [method(:apex_org_sitemap_url), ENV["APEX_STAFF_URL"] || "www.org.localhost", "sitemap"],
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
