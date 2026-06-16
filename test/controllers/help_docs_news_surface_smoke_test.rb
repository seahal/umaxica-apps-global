# typed: false
# frozen_string_literal: true

require "test_helper"

class HelpDocsNewsSurfaceSmokeTest < ActionDispatch::IntegrationTest
  SURFACES = [
    {
      host_env: "HELP_SERVICE_URL",
      host_fallback: "help.app.localhost",
      label: "Help",
      root_path: "/",
      health_path: "/health",
      entries_index_path: "/api/v0/entries",
      entry_model: HelpAppContentEntry,
      expected_body: "Help API is available",
    },
    {
      host_env: "DOCS_SERVICE_URL",
      host_fallback: "docs.app.localhost",
      label: "Docs",
      root_path: "/",
      health_path: "/health",
      entries_index_path: "/api/v0/entries",
      entry_model: DocsAppContentEntry,
      expected_body: "Docs API is available",
    },
    {
      host_env: "NEWS_SERVICE_URL",
      host_fallback: "news.app.localhost",
      label: "News",
      root_path: "/",
      health_path: "/health",
      entries_index_path: "/api/v0/entries",
      entry_model: NewsAppContentEntry,
      expected_body: "News API is available",
    },
  ].freeze

  test "help docs and news app surfaces respond on their public read-only endpoints" do
    SURFACES.each do |surface|
      host = ENV.fetch(surface.fetch(:host_env), surface.fetch(:host_fallback))
      host! host

      get surface.fetch(:root_path), headers: { "Host" => host }

      assert_response :success, surface.fetch(:label)
      assert_includes response.body, surface.fetch(:expected_body), surface.fetch(:label)

      get surface.fetch(:health_path), headers: { "Host" => host }

      assert_response :success, surface.fetch(:label)
      assert_not_empty response.body, surface.fetch(:label)

      published = create_content_entry(surface.fetch(:entry_model), surface.fetch(:label).downcase)

      get surface.fetch(:entries_index_path),
          params: { locale: "test-smoke" },
          headers: { "Host" => host, "Accept" => "application/json" },
          as: :json

      assert_response :success, surface.fetch(:label)
      entry = response.parsed_body.fetch("entries").first

      assert_equal published.slug, entry.fetch("slug"), surface.fetch(:label)
      assert_equal surface.fetch(:label).downcase, entry.fetch("namespace"), surface.fetch(:label)
      assert_equal "app", entry.fetch("surface"), surface.fetch(:label)

      get "#{surface.fetch(:entries_index_path)}/#{published.slug}",
          params: { locale: "test-smoke" },
          headers: { "Host" => host, "Accept" => "application/json" },
          as: :json

      assert_response :success, surface.fetch(:label)
      assert_equal published.slug, response.parsed_body.fetch("entry").fetch("slug"), surface.fetch(:label)
    end
  end

  private

  def create_content_entry(model, namespace)
    model.create!(
      slug: "#{namespace}-surface-smoke",
      locale: "test-smoke",
      title: "#{namespace.titleize} Surface Smoke",
      summary: "#{namespace.titleize} summary",
      body: "#{namespace.titleize} body",
      status: "published",
      published_at: 1.minute.ago,
    )
  end
end
