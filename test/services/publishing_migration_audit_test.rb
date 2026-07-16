# frozen_string_literal: true

require "test_helper"

class PublishingMigrationAuditTest < ActiveSupport::TestCase
  test "confirms the legacy lean and CMS tables are gone for every surface" do
    result = PublishingMigrationAudit.call

    assert_equal %w(app com org), result.details.keys
    assert_equal %w(app com org), result.summary[:surfaces_audited]
    assert_empty result.summary[:surfaces_unreachable]

    app_detail = result.details.fetch("app")
    docs = app_detail.fetch(:lean_tables).fetch("docs_content_entries")

    assert_not docs[:exists]

    app_docs_cms = app_detail.fetch(:cms_tables).fetch("docs")

    assert_equal 0, app_docs_cms[:tables_present]

    assert_equal 0, result.summary[:lean_total_rows]
    assert_equal 0, result.summary[:cms_tables_present]
  end

  test "writes a json report when an output path is given" do
    path = "tmp/test_publishing_migration_audit.json"
    absolute = Rails.root.join(path)
    FileUtils.rm_f(absolute)

    PublishingMigrationAudit.call(output_path: path)

    parsed = JSON.parse(File.read(absolute))

    assert parsed.key?("summary")
    assert parsed.key?("details")
  ensure
    FileUtils.rm_f(absolute)
  end
end
