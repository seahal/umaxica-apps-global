# frozen_string_literal: true

require "test_helper"

class PublishingMigrationImportLeanEntriesTest < ActiveSupport::TestCase
  test "dry run does not write anything" do
    DocsAppContentEntry.create!(
      slug: "import-dry-run", locale: "ja", title: "T", summary: "S", body: "hello",
      status: "published", published_at: Time.current,
    )

    result = PublishingMigrationImportLeanEntries.call

    assert_equal "dry_run", result.summary[:mode]
    assert_equal 0, Publishing::Entry.count
  end

  test "imports a published row into an entry/revision/version/publication chain" do
    DocsAppContentEntry.create!(
      slug: "import-published", locale: "ja", title: "T", summary: "S", body: "hello",
      status: "published", published_at: Time.current,
    )

    result = PublishingMigrationImportLeanEntries.call(apply: true)

    assert_equal 0, result.summary[:errors]
    assert_operator result.summary[:imported_published], :>=, 1

    edition = Publishing::Edition.find_by(audience: "app", surface: "docs", locale: "ja")
    entry = edition.entry_slugs.canonical.find_by(slug: "import-published").entry

    assert_equal 1, entry.revisions.count
    assert_equal 1, entry.versions.count
    assert_equal 1, entry.publications.count
    assert_equal({ "text" => "hello" }, entry.current_revision.body)
  end

  test "draft rows create a revision but no version or publication" do
    DocsAppContentEntry.create!(
      slug: "import-draft", locale: "ja", title: "T", summary: "S", body: "hello",
      status: "draft", published_at: nil,
    )

    PublishingMigrationImportLeanEntries.call(apply: true)

    edition = Publishing::Edition.find_by(audience: "app", surface: "docs", locale: "ja")
    entry = edition.entry_slugs.canonical.find_by(slug: "import-draft").entry

    assert_equal 1, entry.revisions.count
    assert_equal 0, entry.versions.count
    assert_equal 0, entry.publications.count
  end

  test "re-running with unchanged content is idempotent and does not error" do
    DocsAppContentEntry.create!(
      slug: "import-idempotent", locale: "ja", title: "T", summary: "S", body: "hello",
      status: "published", published_at: Time.current,
    )

    PublishingMigrationImportLeanEntries.call(apply: true)
    second = PublishingMigrationImportLeanEntries.call(apply: true)

    assert_equal 0, second.summary[:errors]

    edition = Publishing::Edition.find_by(audience: "app", surface: "docs", locale: "ja")
    entry = edition.entry_slugs.canonical.find_by(slug: "import-idempotent").entry

    assert_equal 1, entry.revisions.count
    assert_equal 1, entry.versions.count
    assert_equal 1, entry.publications.count
  end
end
