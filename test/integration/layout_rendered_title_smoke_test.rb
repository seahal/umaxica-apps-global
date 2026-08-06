# typed: false
# frozen_string_literal: true

require "test_helper"

class LayoutRenderedTitleSmokeTest < ActionDispatch::IntegrationTest
  test "canonical layouts render the expected title site suffix" do
    cases = [
      {
        host: ENV.fetch("PUBLIC_AUTH_SERVICE_URL", "auth.app.localhost"),
        path: -> { auth_app_sign_in_path(ri: "jp") },
        title_site: "#{ENV.fetch("BRAND_NAME")} (app) Auth",
      },
      {
        host: ENV.fetch("PUBLIC_AUTH_CORPORATE_URL", "auth.com.localhost"),
        path: -> { auth_com_sign_in_path(ri: "jp") },
        title_site: "#{ENV.fetch("BRAND_NAME")} (com) Auth",
      },
      {
        host: ENV.fetch("PUBLIC_AUTH_STAFF_URL", "auth.org.localhost"),
        path: -> { auth_org_sign_in_path(ri: "jp") },
        title_site: "#{ENV.fetch("BRAND_NAME")} (org) Auth",
      },
      {
        host: ENV.fetch("PUBLIC_BASE_SERVICE_URL", "base.app.localhost"),
        path: -> { base_app_root_path(ri: "jp") },
        title_site: "Base App",
      },
      {
        host: ENV.fetch("PUBLIC_BASE_CORPORATE_URL", "base.com.localhost"),
        path: -> { base_com_root_path(ri: "jp") },
        title_site: "Base Com",
      },
      {
        host: ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost"),
        path: -> { base_org_root_path(ri: "jp") },
        title_site: "Base Org",
      },
      {
        host: ENV.fetch("PUBLIC_CORE_SERVICE_URL", "core.app.localhost"),
        path: -> { new_core_app_sign_out_path(ri: "jp") },
        title_site: "#{ENV.fetch("BRAND_NAME")} (app) Core",
      },
      {
        host: ENV.fetch("PUBLIC_CORE_CORPORATE_URL", "core.com.localhost"),
        path: -> { new_core_com_sign_out_path(ri: "jp") },
        title_site: "#{ENV.fetch("BRAND_NAME")} (com) Core",
      },
      {
        host: ENV.fetch("PUBLIC_CORE_STAFF_URL", "core.org.localhost"),
        path: -> { new_core_org_sign_out_path(ri: "jp") },
        title_site: "#{ENV.fetch("BRAND_NAME")} (org) Core",
      },
      {
        host: ENV.fetch("PUBLIC_SIDE_SERVICE_URL", "side.app.localhost"),
        path: -> { new_side_app_sign_out_path(ri: "jp") },
        title_site: "#{ENV.fetch("BRAND_NAME")} (app) Side",
      },
      {
        host: ENV.fetch("PUBLIC_SIDE_CORPORATE_URL", "side.com.localhost"),
        path: -> { new_side_com_sign_out_path(ri: "jp") },
        title_site: "#{ENV.fetch("BRAND_NAME")} (com) Side",
      },
      {
        host: ENV.fetch("PUBLIC_SIDE_STAFF_URL", "side.org.localhost"),
        path: -> { new_side_org_sign_out_path(ri: "jp") },
        title_site: "#{ENV.fetch("BRAND_NAME")} (org) Side",
      },
      {
        host: ENV.fetch("PUBLIC_PALM_SERVICE_URL", "palm.app.localhost"),
        path: -> { palm_app_sign_out_path(ri: "jp") },
        title_site: "#{ENV.fetch("BRAND_NAME")} (app) Palm",
      },
    ]

    cases.each do |entry|
      host! entry.fetch(:host)
      get instance_exec(&entry.fetch(:path))

      if response.redirect?
        location = URI.parse(response.location)

        assert_predicate location.host, :present?
      elsif response.not_found?
        assert_response :not_found
      else
        assert_response :success
        assert_select "title", /#{Regexp.escape(entry.fetch(:title_site))}/
      end
    end
  end
end
