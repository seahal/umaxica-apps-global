# typed: false
# frozen_string_literal: true

require "test_helper"

class DocsHelpNewsRevisionsTest < ActionDispatch::IntegrationTest
  SURFACES = [
    { host: ENV.fetch("DOCS_SERVICE_URL"), path_prefix: "/api/v0/entries/example" },
    { host: ENV.fetch("DOCS_CORPORATE_URL"), path_prefix: "/api/v0/entries/example" },
    { host: ENV.fetch("DOCS_STAFF_URL"), path_prefix: "/api/v0/entries/example" },
    { host: ENV.fetch("HELP_SERVICE_URL"), path_prefix: "/api/v0/entries/example" },
    { host: ENV.fetch("HELP_CORPORATE_URL"), path_prefix: "/api/v0/entries/example" },
    { host: ENV.fetch("HELP_STAFF_URL"), path_prefix: "/api/v0/entries/example" },
    { host: ENV.fetch("NEWS_SERVICE_URL"), path_prefix: "/api/v0/entries/example" },
    { host: ENV.fetch("NEWS_CORPORATE_URL"), path_prefix: "/api/v0/entries/example" },
    { host: ENV.fetch("NEWS_STAFF_URL"), path_prefix: "/api/v0/entries/example" },
  ].freeze

  test "revision endpoints return empty collections and objects for every content surface" do
    SURFACES.each do |surface|
      host! surface[:host]

      get "#{surface[:path_prefix]}/revisions"

      assert_response :success
      assert_equal [], response.parsed_body

      get "#{surface[:path_prefix]}/revisions/1"

      assert_response :success
      assert_equal({}, response.parsed_body)
    end
  end
end
