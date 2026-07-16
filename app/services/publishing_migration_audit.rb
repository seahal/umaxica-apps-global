# typed: false
# frozen_string_literal: true

require "json"

# Read-only audit of the legacy content storage in the app/com/org zenith
# databases, run before the publishing DB cutover. It only issues SELECT
# statements; it never writes, migrates, or repairs anything.
class PublishingMigrationAudit < ApplicationService
  Result =
    Data.define(:summary, :details) do
      def to_h = { summary: summary, details: details }

      def to_json(*) = JSON.pretty_generate(to_h)
    end

  SURFACES = %w(app com org).freeze

  LEAN_TABLES = %w(docs_content_entries news_content_entries help_content_entries).freeze
  LEAN_MIGRATION_VERSIONS = %w(20260613000001).freeze

  CMS_FAMILIES = %w(docs news info help).freeze
  CMS_TABLE_SUFFIXES = %w(
    posts
    post_slugs
    post_revisions
    post_versions
    post_publications
    media_files
    media_usages
    categories
    tags
    post_revision_categories
    post_revision_tags
    post_version_categories
    post_version_tags
  ).freeze
  CMS_MIGRATION_VERSIONS = {
    "app" => "20260711010000",
    "com" => "20260711010001",
    "org" => "20260711010002",
  }.freeze

  def initialize(output_path: nil)
    super()
    @output_path = output_path
  end

  def call
    details = SURFACES.index_with { |surface| audit_surface(surface) }
    result = Result.new(summary: build_summary(details), details: details)
    write_report(result) if output_path.present?
    result
  end

  private

  attr_reader :output_path

  def record_class_for(surface)
    case surface
    when "app" then AppRpRecord
    when "com" then ComRpRecord
    when "org" then OrgRpRecord
    else raise ArgumentError, "unknown surface: #{surface.inspect}"
    end
  end

  def audit_surface(surface)
    record_class_for(surface).connection_pool.with_connection do |connection|
      {
        database: connection.pool.db_config.name,
        lean_tables: LEAN_TABLES.index_with { |table| audit_lean_table(connection, table) },
        cms_tables: audit_cms_tables(connection, surface),
        schema_migrations: audit_schema_migrations(connection, surface),
      }
    end
  rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::NoDatabaseError => e
    { connection_error: "#{e.class}: #{e.message}" }
  end

  def audit_lean_table(connection, table)
    return { exists: false } unless connection.table_exists?(table)

    quoted = connection.quote_table_name(table)
    {
      exists: true,
      row_count: select_value(connection, "SELECT COUNT(*) FROM #{quoted}").to_i,
      status_counts: select_pairs(connection, "SELECT status, COUNT(*) FROM #{quoted} GROUP BY status"),
      locale_counts: select_pairs(connection, "SELECT locale, COUNT(*) FROM #{quoted} GROUP BY locale"),
      duplicate_slug_count: select_value(connection, <<~SQL.squish).to_i,
        SELECT COUNT(*) FROM (
          SELECT slug, locale FROM #{quoted} GROUP BY slug, locale HAVING COUNT(*) > 1
        ) duplicated
      SQL
      null_body_count: select_value(connection, "SELECT COUNT(*) FROM #{quoted} WHERE body IS NULL").to_i,
      latest_updated_at: select_value(connection, "SELECT MAX(updated_at) FROM #{quoted}")&.to_s,
    }
  end

  def audit_cms_tables(connection, surface)
    CMS_FAMILIES.to_h do |family|
      tables =
        CMS_TABLE_SUFFIXES.to_h { |suffix|
          table = "#{surface}_#{family}_#{suffix}"
          if connection.table_exists?(table)
            [suffix, select_value(connection, "SELECT COUNT(*) FROM #{connection.quote_table_name(table)}").to_i]
          else
            [suffix, nil]
          end
        }
      [family, { tables_present: tables.values.count { |count| !count.nil? }, row_counts: tables }]
    end
  end

  def audit_schema_migrations(connection, surface)
    versions = LEAN_MIGRATION_VERSIONS + [CMS_MIGRATION_VERSIONS.fetch(surface)]
    return versions.index_with { nil } unless connection.table_exists?("schema_migrations")

    recorded =
      select_values(connection, <<~SQL.squish)
        SELECT version FROM schema_migrations
        WHERE version IN (#{versions.map { |version| connection.quote(version) }.join(", ")})
      SQL
    versions.index_with { |version| recorded.include?(version) }
  end

  def build_summary(details)
    surfaces = details.reject { |_, detail| detail.key?(:connection_error) }
    {
      audited_at: Time.current.iso8601,
      surfaces_audited: surfaces.keys,
      surfaces_unreachable: (details.keys - surfaces.keys),
      lean_total_rows: surfaces.values.sum { |detail|
        detail[:lean_tables].values.sum { |table| table[:row_count].to_i }
      },
      cms_tables_present: surfaces.values.sum { |detail|
        detail[:cms_tables].values.sum { |family| family[:tables_present] }
      },
      cms_total_rows: surfaces.values.sum { |detail|
        detail[:cms_tables].values.sum { |family| family[:row_counts].values.compact.sum }
      },
    }
  end

  def select_value(connection, sql)
    connection.select_value(sql)
  end

  def select_values(connection, sql)
    connection.select_values(sql)
  end

  def select_pairs(connection, sql)
    connection.select_rows(sql).to_h { |key, count| [key.to_s, count.to_i] }
  end

  def write_report(result)
    path = Rails.root.join(output_path)
    FileUtils.mkdir_p(path.dirname)
    File.write(path, result.to_json)
  end
end
