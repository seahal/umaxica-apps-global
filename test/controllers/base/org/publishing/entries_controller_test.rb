# frozen_string_literal: true

require "test_helper"

class Base::Org::Publishing::EntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_BASE_STAFF_URL", "base.org.localhost")
    host! @host
  end

  test "unauthenticated index succeeds and lists only the cell across locales" do
    ja_entry = publishing_draft(audience: "app", surface: "docs", slug: "ja-guide", title: "JA Guide")
    en_entry = publishing_draft(audience: "app", surface: "docs", slug: "en-guide", title: "EN Guide", locale: "en")
    other_audience = publishing_draft(audience: "com", surface: "docs", slug: "com-guide", title: "COM Guide")
    other_surface = publishing_draft(audience: "app", surface: "news", slug: "news-guide", title: "News Guide")

    get base_org_publishing_docs_app_entries_path

    assert_response :success
    assert_equal "base/org/publishing/docs/app/entries/index", inertia_component
    public_ids = inertia_props.fetch("entries").map { |row| row.fetch("public_id") }

    assert_includes public_ids, ja_entry.public_id
    assert_includes public_ids, en_entry.public_id
    assert_not_includes public_ids, other_audience.public_id
    assert_not_includes public_ids, other_surface.public_id
    locales = inertia_props.fetch("entries").map { |row| row.fetch("locale") }

    assert_includes locales, "ja"
    assert_includes locales, "en"
  end

  test "empty index renders" do
    get base_org_publishing_help_org_entries_path

    assert_response :success
    assert_equal [], inertia_props.fetch("entries")
  end

  test "show renders the cell entry and 404s for other cells or unknown ids" do
    entry = publishing_draft(audience: "app", surface: "docs", slug: "shown", title: "Shown")
    foreign = publishing_draft(audience: "com", surface: "docs", slug: "foreign", title: "Foreign")

    get base_org_publishing_docs_app_entry_path(entry.public_id)

    assert_response :success
    assert_equal "base/org/publishing/docs/app/entries/show", inertia_component
    shown = inertia_props.fetch("entry")

    assert_equal entry.public_id, shown.fetch("public_id")
    assert_equal "docs", shown.fetch("surface")
    assert_equal "app", shown.fetch("audience")
    assert_equal "Shown", shown.fetch("title")
    assert_not shown.key?("id")

    get base_org_publishing_docs_app_entry_path(foreign.public_id)

    assert_response :not_found

    get base_org_publishing_docs_app_entry_path("does-not-exist-publicid")

    assert_response :not_found

    get base_org_publishing_docs_app_entry_path(entry.id)

    assert_response :not_found
  end

  test "edit renders current revision values and 404s for another cell" do
    entry = publishing_draft(audience: "app", surface: "docs", slug: "editable", title: "Editable")
    foreign = publishing_draft(audience: "com", surface: "docs", slug: "other", title: "Other")

    get edit_base_org_publishing_docs_app_entry_path(entry.public_id)

    assert_response :success
    form = inertia_props.fetch("form")

    assert_equal "Editable", form.fetch("title")
    assert_includes form.fetch("body"), "Editable body"
    assert_equal "patch", form.fetch("method")
    assert_equal base_org_publishing_docs_app_entry_path(entry.public_id), form.fetch("action")

    get edit_base_org_publishing_docs_app_entry_path(foreign.public_id)

    assert_response :not_found
  end

  test "successful update creates a new revision and preserves taxonomy and media" do
    category = publishing_category_vocabulary(audience: "app", surface: "docs")
    term = publishing_term(vocabulary: category, locale: "ja", slug: "guide", name: "ガイド")
    entry = publishing_draft(audience: "app", surface: "docs", slug: "updated", title: "Original")
    previous = entry.current_revision
    create_single_assignment(entry_revision: previous, vocabulary: category, taxonomy_term: term, locale: "ja")
    media_file = publishing_media_file
    publishing_revision_media_usage(revision: previous, media_file:)

    patch base_org_publishing_docs_app_entry_path(entry.public_id),
          params: {
            entry: {
              title: "Revised",
              summary: "New summary",
              body: { "text" => "New body" }.to_json,
              lock_version: entry.lock_version,
            },
          }

    assert_redirected_to base_org_publishing_docs_app_entry_path(entry.public_id)
    assert_equal 303, response.status
    entry.reload

    assert_not_equal previous.id, entry.current_revision_id
    assert_equal 2, entry.current_revision.sequence
    assert_equal "Revised", entry.current_revision.title
    assert_equal "New summary", entry.current_revision.summary
    assert_equal({ "text" => "New body" }, entry.current_revision.body)
    previous.reload

    assert_equal "Original", previous.title
    assert_equal term.id, entry.current_revision.single_taxonomy_assignments.sole.taxonomy_term_id
    assert_equal media_file.id, entry.current_revision.media_usages.sole.media_file_id
  end

  test "malformed body json returns 422 and does not create a revision" do
    entry = publishing_draft(audience: "app", surface: "docs", slug: "invalid-json", title: "Keep")
    current = entry.current_revision

    patch base_org_publishing_docs_app_entry_path(entry.public_id),
          params: {
            entry: {
              title: "Keep",
              summary: "Keep summary",
              body: "{not-json",
              lock_version: entry.lock_version,
            },
          }

    assert_response :unprocessable_content
    assert_equal "base/org/publishing/docs/app/entries/edit", inertia_component
    assert_equal "must be valid JSON", inertia_props.fetch("errors").fetch("body")
    assert_equal current, entry.reload.current_revision
    assert_equal 1, entry.revisions.count
  end

  test "blank title returns 422 without a partial revision" do
    entry = publishing_draft(audience: "app", surface: "docs", slug: "blank-title", title: "Keep")

    patch base_org_publishing_docs_app_entry_path(entry.public_id),
          params: {
            entry: {
              title: "",
              summary: "x",
              body: { "text" => "x" }.to_json,
              lock_version: entry.lock_version,
            },
          }

    assert_response :unprocessable_content
    assert_equal 1, entry.revisions.count
  end

  test "update under docs/app does not mutate a docs/com entry" do
    app_entry = publishing_draft(audience: "app", surface: "docs", slug: "app-one", title: "App")
    com_entry = publishing_draft(audience: "com", surface: "docs", slug: "com-one", title: "Com")
    com_revision = com_entry.current_revision

    patch base_org_publishing_docs_app_entry_path(com_entry.public_id),
          params: {
            entry: {
              title: "Hijack",
              summary: "no",
              body: { "text" => "no" }.to_json,
              lock_version: com_entry.lock_version,
            },
          }

    assert_response :not_found
    assert_equal com_revision, com_entry.reload.current_revision
    assert_equal 1, app_entry.revisions.count
  end
end
