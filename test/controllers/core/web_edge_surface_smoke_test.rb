# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class CoreWebEdgeSurfaceSmokeTest < ActionDispatch::IntegrationTest
  SURFACES = [
    {
      host: ENV.fetch("PUBLIC_CORE_SERVICE_URL"),
      cookie_path: "/web/v1/cookie",
      theme_path: "/web/v0/theme",
      edge_cookie_path: "/edge/v0/cookie",
      edge_dbsc_path: "/edge/v0/dbsc",
    },
    {
      host: ENV.fetch("PUBLIC_CORE_CORPORATE_URL"),
      cookie_path: "/web/v1/cookie",
      theme_path: "/web/v0/theme",
      edge_cookie_path: "/edge/v0/cookie",
      edge_dbsc_path: "/edge/v0/dbsc",
    },
    {
      host: ENV.fetch("PUBLIC_CORE_STAFF_URL"),
      cookie_path: "/web/v1/cookie",
      theme_path: "/web/v0/theme",
      edge_cookie_path: "/edge/v0/cookie",
      edge_dbsc_path: "/edge/v0/dbsc",
    },
  ].freeze

  test "core web and edge compatibility endpoints are executable on every surface" do
    SURFACES.each do |surface|
      host = surface.fetch(:host)
      host! host

      get "https://#{host}#{surface.fetch(:cookie_path)}", params: { ri: "jp" }

      assert_response :success
      assert_equal "application/json", response.media_type

      patch "https://#{host}#{surface.fetch(:cookie_path)}", params: { ri: "jp", value: "1" }, as: :json

      assert_response :unauthorized
      assert_equal "missing_preference_access_token", response.parsed_body.fetch("error")

      get "https://#{host}#{surface.fetch(:theme_path)}", params: { ri: "jp" }

      assert_response :success
      assert_equal "application/json", response.media_type

      patch "https://#{host}#{surface.fetch(:theme_path)}", params: { ri: "jp", value: "dark" }, as: :json

      assert_response :success
      assert_equal "application/json", response.media_type

      get "https://#{host}#{surface.fetch(:edge_cookie_path)}", params: { ri: "jp" }

      assert_response :success
      assert_equal "application/json", response.media_type

      patch "https://#{host}#{surface.fetch(:edge_cookie_path)}", params: { ri: "jp", value: "1" }, as: :json

      assert_response :success
      assert_equal "application/json", response.media_type

      post "https://#{host}#{surface.fetch(:edge_dbsc_path)}", params: { ri: "jp" }, as: :json

      assert_response :unprocessable_content
      assert_equal "missing_proof", response.parsed_body.fetch("error_code")
    end
  end
end
