# typed: false
# frozen_string_literal: true

require "test_helper"

class ReadOnlySurfacesTest < ActionDispatch::IntegrationTest
  STATIC_SURFACES = [
    ["base_app_root_url", "BASE_SERVICE_URL", "base.app.localhost", "Base services are available"],
    ["base_com_root_url", "BASE_CORPORATE_URL", "base.com.localhost", "Base services are available"],
    ["base_org_root_url", "BASE_STAFF_URL", "base.org.localhost", "Base services are available"],
    ["palm_app_root_url", "PALM_SERVICE_URL", "palm.app.localhost", "Palm API is available"],
  ].freeze

  CONTENT_SURFACES = [
    ["help_app_root_url", "HELP_SERVICE_URL", "help.app.localhost", "Help API is available"],
    ["help_com_root_url", "HELP_CORPORATE_URL", "help.com.localhost", "Help API is available"],
    ["help_org_root_url", "HELP_STAFF_URL", "help.org.localhost", "Help API is available"],
    ["docs_app_root_url", "DOCS_SERVICE_URL", "docs.app.localhost", "Docs API is available"],
    ["docs_com_root_url", "DOCS_CORPORATE_URL", "docs.com.localhost", "Docs API is available"],
    ["docs_org_root_url", "DOCS_STAFF_URL", "docs.org.localhost", "Docs API is available"],
    ["news_app_root_url", "NEWS_SERVICE_URL", "news.app.localhost", "News API is available"],
    ["news_com_root_url", "NEWS_CORPORATE_URL", "news.com.localhost", "News API is available"],
    ["news_org_root_url", "NEWS_STAFF_URL", "news.org.localhost", "News API is available"],
  ].freeze

  test "static base and palm roots respond without auth redirects" do
    STATIC_SURFACES.each do |helper, env_key, fallback, expected|
      host = ENV.fetch(env_key, fallback)
      host! host
      get public_send(helper, ri: "jp", host: host)

      assert_response :success
      assert_includes response.body, expected
      assert_empty response.cookies
    end
  end

  test "content roots respond as thin availability endpoints" do
    CONTENT_SURFACES.each do |helper, env_key, fallback, expected|
      host! ENV.fetch(env_key, fallback)
      get public_send(helper, ri: "jp", host: ENV.fetch(env_key, fallback))

      assert_response :success
      assert_includes response.body, expected
      assert_empty response.cookies
    end
  end

  test "content api show rejects unpublished entries and old rails article routes are unavailable" do
    model = DocsAppContentEntry
    published = create_content_entry(model, slug: "visible-entry", title: "Visible Entry", locale: "test-show")
    create_content_entry(
      model,
      slug: "future-entry",
      title: "Future Entry",
      locale: "test-show",
      published_at: 1.day.from_now,
    )

    host! ENV.fetch("DOCS_SERVICE_URL", "docs.app.localhost")
    get docs_app_api_v0_entry_url(id: published.slug, locale: published.locale)

    assert_response :success
    assert_equal "visible-entry", response.parsed_body.fetch("entry").fetch("slug")

    get docs_app_api_v0_entry_url(id: "future-entry", locale: published.locale)

    assert_response :not_found

    get "/entries/#{published.slug}", params: { locale: published.locale }

    assert_response :not_found

    get "/edge/v0/entries/#{published.slug}", params: { locale: published.locale }

    assert_response :not_found
  end

  private

  def create_content_entry(model, slug:, title:, locale: "jp", status: "published", published_at: 1.hour.ago)
    model.create!(
      slug: slug,
      locale: locale,
      title: title,
      summary: "#{title} summary",
      body: "#{title} body",
      status: status,
      published_at: published_at,
    )
  end
end
