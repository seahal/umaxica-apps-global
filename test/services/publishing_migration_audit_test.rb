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

  test "rejects an unknown surface" do
    error =
      assert_raises(ArgumentError) do
        PublishingMigrationAudit.new.send(:record_class_for, "unknown")
      end

    assert_equal 'unknown surface: "unknown"', error.message
  end

  test "reports an unavailable surface without aborting the audit" do
    service = PublishingMigrationAudit.new
    unavailable = -> { raise ActiveRecord::ConnectionNotEstablished, "offline" }

    AppRpRecord.stub(:connection_pool, unavailable) do
      result = service.send(:audit_surface, "app")

      assert_match "ActiveRecord::ConnectionNotEstablished", result.fetch(:connection_error)
      assert_match "offline", result.fetch(:connection_error)
    end
  end

  test "audits existing lean and CMS tables through read-only queries" do
    latest_updated_at = Time.zone.parse("2026-07-19 12:00:00")
    connection = Object.new
    connection.define_singleton_method(:table_exists?) { |_table| true }
    connection.define_singleton_method(:quote_table_name) { |table| "\"#{table}\"" }
    connection.define_singleton_method(:select_value) do |sql|
      sql.include?("MAX(updated_at)") ? latest_updated_at : 2
    end
    connection.define_singleton_method(:select_rows) { |_sql| [["published", 2]] }
    service = PublishingMigrationAudit.new

    lean = service.send(:audit_lean_table, connection, "docs_content_entries")
    cms = service.send(:audit_cms_tables, connection, "app")

    assert lean[:exists]
    assert_equal 2, lean[:row_count]
    assert_equal({ "published" => 2 }, lean[:status_counts])
    assert_equal latest_updated_at.to_s, lean[:latest_updated_at]
    assert_equal PublishingMigrationAudit::CMS_TABLE_SUFFIXES.length,
                 cms.fetch("docs").fetch(:tables_present)
  end
end
