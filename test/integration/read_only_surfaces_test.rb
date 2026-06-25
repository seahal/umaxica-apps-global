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

  CONTENT_API_SURFACES = [
    ["help_app_api_v0_entry_url", "HELP_SERVICE_URL", "help.app.localhost", HelpAppContentEntry, "help", "app"],
    ["help_com_api_v0_entry_url", "HELP_CORPORATE_URL", "help.com.localhost", HelpComContentEntry, "help", "com"],
    ["help_org_api_v0_entry_url", "HELP_STAFF_URL", "help.org.localhost", HelpOrgContentEntry, "help", "org"],
    ["docs_app_api_v0_entry_url", "DOCS_SERVICE_URL", "docs.app.localhost", DocsAppContentEntry, "docs", "app"],
    ["docs_com_api_v0_entry_url", "DOCS_CORPORATE_URL", "docs.com.localhost", DocsComContentEntry, "docs", "com"],
    ["docs_org_api_v0_entry_url", "DOCS_STAFF_URL", "docs.org.localhost", DocsOrgContentEntry, "docs", "org"],
    ["news_app_api_v0_entry_url", "NEWS_SERVICE_URL", "news.app.localhost", NewsAppContentEntry, "news", "app"],
    ["news_com_api_v0_entry_url", "NEWS_CORPORATE_URL", "news.com.localhost", NewsComContentEntry, "news", "com"],
    ["news_org_api_v0_entry_url", "NEWS_STAFF_URL", "news.org.localhost", NewsOrgContentEntry, "news", "org"],
  ].freeze

  test "static base and palm roots respond without auth redirects" do
    STATIC_SURFACES.each do |helper, env_key, fallback, expected|
      host = ENV.fetch(env_key, fallback)
      host! host
      get public_send(helper, ri: "jp", host: host)

      assert_response :success
      assert_includes response.body, expected
    end
  end

  test "content roots respond as thin availability endpoints" do
    CONTENT_SURFACES.each do |helper, env_key, fallback, expected|
      host! ENV.fetch(env_key, fallback)
      get public_send(helper, ri: "jp", host: ENV.fetch(env_key, fallback))

      assert_response :success
      assert_includes response.body, expected
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
    get docs_app_api_v0_entry_url(slug: published.slug, locale: published.locale)

    assert_response :success
    assert_equal "visible-entry", response.parsed_body.fetch("entry").fetch("slug")

    get docs_app_api_v0_entry_url(slug: "future-entry", locale: published.locale)

    assert_response :not_found

    get "/entries/#{published.slug}", params: { locale: published.locale }

    assert_response :not_found

    get "/edge/v0/entries/#{published.slug}", params: { locale: published.locale }

    assert_response :not_found
  end

  test "content api show resolves locale from ri and rejects draft or archived entries" do
    published = create_content_entry(
      DocsAppContentEntry,
      slug: "locale-visible-entry",
      title: "Locale Visible Entry",
      locale: "ja",
    )
    create_content_entry(
      DocsAppContentEntry,
      slug: "locale-draft-entry",
      title: "Locale Draft Entry",
      locale: "ja",
      status: "draft",
    )
    create_content_entry(
      DocsAppContentEntry,
      slug: "locale-archived-entry",
      title: "Locale Archived Entry",
      locale: "ja",
      status: "archived",
    )

    host! ENV.fetch("DOCS_SERVICE_URL", "docs.app.localhost")

    get docs_app_api_v0_entry_url(slug: published.slug, ri: "jp")

    assert_response :success
    assert_equal published.slug, response.parsed_body.fetch("entry").fetch("slug")

    get docs_app_api_v0_entry_url(slug: "locale-draft-entry", ri: "jp")

    assert_response :not_found

    get docs_app_api_v0_entry_url(slug: "locale-archived-entry", ri: "jp")

    assert_response :not_found
  end

  test "content api show falls back safely for invalid ri values" do
    published = create_content_entry(
      DocsAppContentEntry,
      slug: "fallback-visible-entry",
      title: "Fallback Visible Entry",
      locale: I18n.locale.to_s,
    )
    english = create_content_entry(
      DocsAppContentEntry,
      slug: "fallback-english-entry",
      title: "Fallback English Entry",
      locale: "en",
    )

    host! ENV.fetch("DOCS_SERVICE_URL", "docs.app.localhost")

    get docs_app_api_v0_entry_url(slug: published.slug, ri: "zz")

    assert_response :success
    assert_equal published.slug, response.parsed_body.fetch("entry").fetch("slug")

    get docs_app_api_v0_entry_url(slug: english.slug, ri: "us")

    assert_response :success
    assert_equal english.slug, response.parsed_body.fetch("entry").fetch("slug")
  end

  test "content api index and show serialize published content with the expected namespace" do
    CONTENT_API_SURFACES.each do |helper, env_key, fallback, model, namespace, surface|
      create_content_entry(
        model, slug: "#{surface}-older-entry", title: "Older Entry", locale: "test-api",
               published_at: 2.hours.ago,
      )
      newer = create_content_entry(
        model, slug: "#{surface}-newer-entry", title: "Newer Entry", locale: "test-api",
      )
      create_content_entry(model, slug: "#{surface}-other-locale", title: "Other Locale", locale: "jp")

      host = ENV.fetch(env_key, fallback)
      host! host

      get public_send(helper, slug: newer.slug, locale: "test-api", host: host),
          headers: { "Host" => host, "Accept" => "application/json" },
          as: :json

      assert_response :success
      entry = response.parsed_body.fetch("entry")

      assert_equal newer.slug, entry.fetch("slug")
      assert_equal namespace, entry.fetch("namespace")
      assert_equal surface, entry.fetch("surface")
      assert_equal "Newer Entry", entry.fetch("title")

      get public_send(helper, slug: "#{surface}-future-entry", locale: "test-api", host: host),
          headers: { "Host" => host, "Accept" => "application/json" },
          as: :json

      assert_response :not_found

      get "/api/v0/entries",
          params: { locale: "test-api" },
          headers: { "Host" => host, "Accept" => "application/json" },
          as: :json

      assert_response :success
      entries = response.parsed_body.fetch("entries")

      assert_equal [newer.slug, "#{surface}-older-entry"], entries.map { |e| e.fetch("slug") }
      assert_equal namespace, entries.first.fetch("namespace")
      assert_equal surface, entries.first.fetch("surface")
      assert_equal "Newer Entry", entries.first.fetch("title")
    end
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
