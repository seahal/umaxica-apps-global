# typed: false
# frozen_string_literal: true

require "digest"
require "json"

# Imports the lean content-entry tables (docs/news/help x app/com/org) into the
# central publishing DB. Dry-run by default; only writes when apply: true.
# Idempotent: re-running with the same source rows updates the same
# Publishing::Entry rather than duplicating it (matched by edition + slug).
# Published rows get an EntryVersion + Publication; draft rows stop at the
# current revision. See adr/publishing-db-content-authority.md.
class PublishingMigrationImportLeanEntries < ApplicationService
  Result =
    Data.define(:summary, :details) do
      def to_h = { summary: summary, details: details }

      def to_json(*) = JSON.pretty_generate(to_h)
    end

  SOURCES = {
    "app" => { record_class: "AppRpRecord" },
    "com" => { record_class: "ComRpRecord" },
    "org" => { record_class: "OrgRpRecord" },
  }.freeze
  SURFACE_TABLES = {
    "docs" => "docs_content_entries",
    "news" => "news_content_entries",
    "help" => "help_content_entries",
  }.freeze
  SCHEMA_VERSION = 1

  def initialize(apply: false, output_path: nil)
    super()
    @apply = apply
    @output_path = output_path
  end

  def call
    details = []
    SOURCES.each_key do |audience|
      SURFACE_TABLES.each_key do |surface|
        details.concat(import_surface(audience, surface))
      end
    end
    result = Result.new(summary: build_summary(details), details: details)
    write_report(result) if output_path.present?
    result
  end

  private

  attr_reader :apply, :output_path

  def apply? = apply

  def import_surface(audience, surface)
    record_class_for(audience).connection_pool.with_connection do |connection|
      table = SURFACE_TABLES.fetch(surface)
      return [] unless connection.table_exists?(table)

      connection.select_all("SELECT * FROM #{connection.quote_table_name(table)} ORDER BY id").to_a.map { |row|
        import_row(audience:, surface:, table:, row:)
      }
    end
  end

  def import_row(audience:, surface:, table:, row:)
    edition = find_or_build_edition(audience:, surface:, locale: row.fetch("locale"))
    digest = Digest::SHA256.hexdigest(row.fetch("body").to_s)
    outcome = apply? ? persist_row(edition:, row:, digest:) : "dry_run"

    {
      source_table: table,
      source_id: row.fetch("id"),
      audience: audience,
      surface: surface,
      slug: row.fetch("slug"),
      locale: row.fetch("locale"),
      status: row.fetch("status"),
      content_digest: digest,
      outcome: outcome,
    }
  rescue StandardError => e
    { source_table: table, source_id: row["id"], outcome: "error", error: "#{e.class}: #{e.message}" }
  end

  def persist_row(edition:, row:, digest:)
    Publishing::Entry.transaction do
      entry = find_or_build_entry(edition:, row:)
      revision = existing_or_new_revision(entry:, row:, digest:)

      if row.fetch("status") == "published"
        version = existing_or_new_version(entry:, revision:, row:, digest:)
        ensure_publication(entry:, version:, row:)
        "imported_published"
      else
        "imported_draft"
      end
    end
  end

  def existing_or_new_revision(entry:, row:, digest:)
    current = entry.current_revision
    return current if current && current.content_digest == digest

    revision = build_revision(entry:, row:, digest:)
    entry.update!(current_revision: revision)
    revision
  end

  def existing_or_new_version(entry:, revision:, row:, digest:)
    entry.versions.find_by(content_digest: digest) || build_version(entry:, revision:, row:, digest:)
  end

  def find_or_build_edition(audience:, surface:, locale:)
    Publishing::Edition.find_or_create_by!(audience:, surface:, locale:)
  end

  def find_or_build_entry(edition:, row:)
    existing =
      Publishing::EntrySlug
        .joins(:entry)
        .includes(:entry)
        .find_by(edition:, slug: row.fetch("slug"), publishing_entries: { locale: row.fetch("locale") })
        &.entry
    return existing if existing

    entry = Publishing::Entry.create!(edition:, locale: row.fetch("locale"))
    Publishing::EntrySlug.create!(
      entry:, edition:, locale: row.fetch("locale"), slug: row.fetch("slug"),
      state: "canonical", canonicalized_at: Time.current,
    )
    entry
  end

  def build_revision(entry:, row:, digest:)
    next_sequence = (entry.revisions.maximum(:sequence) || 0) + 1
    Publishing::EntryRevision.create!(
      entry:, locale: row.fetch("locale"), title: row.fetch("title"), summary: row["summary"],
      body: { "text" => row.fetch("body") }, schema_version: SCHEMA_VERSION, content_digest: digest,
      sequence: next_sequence,
    )
  end

  def build_version(entry:, revision:, row:, digest:)
    next_sequence = (entry.versions.maximum(:sequence) || 0) + 1
    Publishing::EntryVersion.create!(
      entry:, entry_revision: revision, locale: row.fetch("locale"), title: row.fetch("title"),
      summary: row["summary"], body: { "text" => row.fetch("body") }, schema_version: SCHEMA_VERSION,
      content_digest: digest, sequence: next_sequence,
    )
  end

  def ensure_publication(entry:, version:, row:)
    return if entry.publications.exists?(entry_version: version)

    Publishing::Publication.create!(
      entry:, entry_version: version, effective_from: row["published_at"] || Time.current,
    )
  end

  def record_class_for(audience)
    case audience
    when "app" then AppRpRecord
    when "com" then ComRpRecord
    when "org" then OrgRpRecord
    else raise ArgumentError, "unknown audience: #{audience.inspect}"
    end
  end

  def build_summary(details)
    {
      imported_at: Time.current.iso8601,
      mode: apply? ? "apply" : "dry_run",
      total_rows: details.size,
      imported_published: details.count { |d| d[:outcome] == "imported_published" },
      imported_draft: details.count { |d| d[:outcome] == "imported_draft" },
      dry_run: details.count { |d| d[:outcome] == "dry_run" },
      errors: details.count { |d| d[:outcome] == "error" },
    }
  end

  def write_report(result)
    path = Rails.root.join(output_path)
    FileUtils.mkdir_p(path.dirname)
    File.write(path, result.to_json)
  end
end
