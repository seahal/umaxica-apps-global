# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class InfoApiStubTest < ActionDispatch::IntegrationTest
  SURFACES = [
    ["PRIVATE_INFO_SERVICE_URL", "info.app.localhost", "app"],
    ["PRIVATE_INFO_CORPORATE_URL", "info.com.localhost", "com"],
    ["PRIVATE_INFO_STAFF_URL", "info.org.localhost", "org"],
  ].freeze

  test "info api stub routes respond with sample json on every host" do
    SURFACES.each do |env_key, fallback_host, namespace|
      host = ENV.fetch(env_key, fallback_host)
      host! host

      get "/api/v0/entries", headers: { "Host" => host, "Accept" => "application/json" }, as: :json

      assert_response :success
      assert_equal "application/json", response.media_type

      parsed = response.parsed_body

      assert_equal "info", parsed.fetch("surface")
      assert_equal namespace, parsed.fetch("namespace")
      assert_equal host, parsed.fetch("host")
      assert parsed.fetch("sample")
      assert_equal %w(terms privacy), parsed.fetch("entries").map { |entry| entry.fetch("slug") }

      get "/api/v0/entries/terms", headers: { "Host" => host, "Accept" => "application/json" }, as: :json

      assert_response :success
      parsed = response.parsed_body

      assert_equal "terms", parsed.fetch("entry").fetch("slug")
      assert_equal "info", parsed.fetch("surface")
      assert_equal namespace, parsed.fetch("namespace")
      assert_equal host, parsed.fetch("host")
      assert parsed.fetch("sample")

      get "/api/v0/entries/privacy", headers: { "Host" => host, "Accept" => "application/json" }, as: :json

      assert_response :success
      parsed = response.parsed_body

      assert_equal "privacy", parsed.fetch("entry").fetch("slug")
      assert_equal "info", parsed.fetch("surface")
      assert_equal namespace, parsed.fetch("namespace")
      assert_equal host, parsed.fetch("host")
      assert parsed.fetch("sample")
    end
  end

  test "info api stub accepts unknown slugs without redirecting to sign in" do
    host = ENV.fetch("PRIVATE_INFO_SERVICE_URL")
    host! host

    get "/api/v0/entries/anything", headers: { "Host" => host, "Accept" => "application/json" }, as: :json

    assert_response :success
    assert_equal "anything", response.parsed_body.fetch("entry").fetch("slug")
    assert_equal "application/json", response.media_type
  end
end
