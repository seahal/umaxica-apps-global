# typed: false
# frozen_string_literal: true

require "test_helper"

class DocsSurfacePublishingCutoverTest < ActionDispatch::IntegrationTest
  test "reads from the legacy lean table when the surface flag is not set" do
    DocsAppContentEntry.create!(
      slug: "cutover-legacy", locale: "ja", title: "Legacy", summary: "S", body: "legacy body",
      status: "published", published_at: 1.hour.ago,
    )
    host! "docs.app.localhost"

    get "/api/v0/entries/cutover-legacy", params: { locale: "ja" }, as: :json

    assert_response :success
    assert_equal "legacy body", response.parsed_body.fetch("entry").fetch("body")
  end

  test "reads from the publishing DB when PUBLISHING_READ_SURFACES includes docs" do
    edition = Publishing::Edition.find_or_create_by!(audience: "app", surface: "docs", locale: "ja")
    entry = Publishing::Entry.create!(edition:, locale: "ja")
    Publishing::EntrySlug.create!(entry:, edition:, locale: "ja", slug: "cutover-publishing", state: "canonical", canonicalized_at: Time.current)
    digest = "9" * 64
    revision =
      Publishing::EntryRevision.create!(
        entry:, locale: "ja", title: "Publishing", summary: "S", body: { "text" => "publishing body" },
        schema_version: 1, content_digest: digest, sequence: 1,
      )
    entry.update!(current_revision: revision)
    version =
      Publishing::EntryVersion.create!(
        entry:, entry_revision: revision, locale: "ja", title: "Publishing", summary: "S",
        body: { "text" => "publishing body" }, schema_version: 1, content_digest: digest, sequence: 1,
      )
    Publishing::Publication.create!(entry:, entry_version: version, effective_from: 1.hour.ago)
    host! "docs.app.localhost"

    with_publishing_read_surfaces("docs") do
      get "/api/v0/entries/cutover-publishing", params: { locale: "ja" }, as: :json
    end

    assert_response :success
    assert_equal "publishing body", response.parsed_body.fetch("entry").fetch("body")
  end

  private

  def with_publishing_read_surfaces(value)
    original = ENV.fetch("PUBLISHING_READ_SURFACES", nil)
    ENV["PUBLISHING_READ_SURFACES"] = value
    yield
  ensure
    ENV["PUBLISHING_READ_SURFACES"] = original
  end
end
