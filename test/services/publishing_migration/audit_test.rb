# frozen_string_literal: true

require "test_helper"

module PublishingMigration
  class AuditTest < ActiveSupport::TestCase
    test "audits lean tables, cms tables, and schema migrations for every surface" do
      DocsAppContentEntry.create!(
        slug: "publishing-audit-sample",
        locale: "ja",
        title: "audit sample",
        summary: "audit sample summary",
        body: "audit sample body",
        status: "published",
        published_at: Time.current,
      )

      result = Audit.call

      assert_equal %w(app com org), result.details.keys
      assert_equal %w(app com org), result.summary[:surfaces_audited]
      assert_empty result.summary[:surfaces_unreachable]

      app_detail = result.details.fetch("app")
      docs = app_detail.fetch(:lean_tables).fetch("docs_content_entries")

      assert docs[:exists]
      assert_operator docs[:row_count], :>=, 1
      assert_operator docs[:status_counts].fetch("published"), :>=, 1
      assert_equal 0, docs[:duplicate_slug_count]

      app_docs_cms = app_detail.fetch(:cms_tables).fetch("docs")

      assert_equal 13, app_docs_cms[:tables_present]
      assert_equal 13, app_docs_cms[:row_counts].size

      migrations = app_detail.fetch(:schema_migrations)

      assert_includes migrations.keys, "20260613000001"
      assert_includes migrations.keys, "20260711010000"

      assert_operator result.summary[:lean_total_rows], :>=, 1
      assert_equal 156, result.summary[:cms_tables_present]
    end

    test "writes a json report when an output path is given" do
      path = "tmp/test_publishing_migration_audit.json"
      absolute = Rails.root.join(path)
      FileUtils.rm_f(absolute)

      Audit.call(output_path: path)

      parsed = JSON.parse(File.read(absolute))

      assert parsed.key?("summary")
      assert parsed.key?("details")
    ensure
      FileUtils.rm_f(absolute)
    end
  end
end
