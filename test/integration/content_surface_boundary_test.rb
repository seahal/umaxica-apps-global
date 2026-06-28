# typed: false
# frozen_string_literal: true

require "test_helper"

class ContentSurfaceBoundaryTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  SURFACE_HOSTS = {
    "docs" => ENV.fetch("PRIVATE_DOCS_SERVICE_URL", ENV.fetch("PRIVATE_DOCS_SERVICE_URL", "docs.app.localhost")),
    "help" => ENV.fetch("PRIVATE_HELP_SERVICE_URL", ENV.fetch("PRIVATE_HELP_SERVICE_URL", "help.app.localhost")),
    "news" => ENV.fetch("PRIVATE_NEWS_SERVICE_URL", ENV.fetch("PRIVATE_NEWS_SERVICE_URL", "news.app.localhost")),
  }.freeze

  test "docs help and news entries remain public read-only json surfaces" do
    SURFACE_HOSTS.each_value do |host|
      host! host

      get "/api/v0/entries"

      assert_response :success
      assert_equal({ "entries" => [] }, response.parsed_body)
      assert_empty response_set_cookie_lines

      get "/api/v0/entries/example/revisions"

      assert_response :success
      assert_equal [], response.parsed_body
      assert_empty response_set_cookie_lines

      assert_mutation_verbs_rejected(host, "/api/v0/entries")
      assert_mutation_verbs_rejected(host, "/api/v0/entries/example/revisions")
    end
  end

  test "docs help and news do not expose rp or provider endpoints" do
    SURFACE_HOSTS.each_value do |host|
      %w(/auth /auth/callback /authorize /token /userinfo /jwks /oauth/authorize /oauth/token /oauth/userinfo
         /oauth/jwks).each do |path|
        assert_raises(ActionController::RoutingError) do
          Rails.application.routes.recognize_path("http://#{host}#{path}", method: :get)
        end
      end

      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{host}/oauth/token", method: :post)
      end
    end
  end

  private

  def assert_mutation_verbs_rejected(host, path)
    %i(post patch put delete).each do |method|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{host}#{path}", method: method)
      end
    end
  end
end
