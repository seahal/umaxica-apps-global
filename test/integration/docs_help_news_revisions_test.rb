# typed: false
# frozen_string_literal: true

require "test_helper"
require "helpers/global_test_support"

class DocsHelpNewsRevisionsTest < ActionDispatch::IntegrationTest
  SURFACES = [
    { host: ENV.fetch("PRIVATE_DOCS_SERVICE_URL", ENV.fetch("PRIVATE_DOCS_SERVICE_URL", "docs.app.localhost")),
      path_prefix: "/api/v0/entries/example", },
    { host: ENV.fetch("PRIVATE_DOCS_CORPORATE_URL", ENV.fetch("PRIVATE_DOCS_CORPORATE_URL", "docs.com.localhost")),
      path_prefix: "/api/v0/entries/example", },
    { host: ENV.fetch("PRIVATE_DOCS_STAFF_URL", ENV.fetch("PRIVATE_DOCS_STAFF_URL", "docs.org.localhost")),
      path_prefix: "/api/v0/entries/example", },
    { host: ENV.fetch("PRIVATE_HELP_SERVICE_URL", ENV.fetch("PRIVATE_HELP_SERVICE_URL", "help.app.localhost")),
      path_prefix: "/api/v0/entries/example", },
    { host: ENV.fetch("PRIVATE_HELP_CORPORATE_URL", ENV.fetch("PRIVATE_HELP_CORPORATE_URL", "help.com.localhost")),
      path_prefix: "/api/v0/entries/example", },
    { host: ENV.fetch("PRIVATE_HELP_STAFF_URL", ENV.fetch("PRIVATE_HELP_STAFF_URL", "help.org.localhost")),
      path_prefix: "/api/v0/entries/example", },
    { host: ENV.fetch("PRIVATE_NEWS_SERVICE_URL", ENV.fetch("PRIVATE_NEWS_SERVICE_URL", "news.app.localhost")),
      path_prefix: "/api/v0/entries/example", },
    { host: ENV.fetch("PRIVATE_NEWS_CORPORATE_URL", ENV.fetch("PRIVATE_NEWS_CORPORATE_URL", "news.com.localhost")),
      path_prefix: "/api/v0/entries/example", },
    { host: ENV.fetch("PRIVATE_NEWS_STAFF_URL", ENV.fetch("PRIVATE_NEWS_STAFF_URL", "news.org.localhost")),
      path_prefix: "/api/v0/entries/example", },
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
