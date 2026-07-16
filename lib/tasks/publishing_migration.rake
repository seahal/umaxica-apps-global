# frozen_string_literal: true

namespace :publishing do
  namespace :migration do
    desc "Read-only audit of legacy zenith content tables before the publishing DB cutover"
    task audit: :environment do
      path = ENV.fetch("REPORT", "tmp/publishing_migration_audit.json")
      result = PublishingMigrationAudit.call(output_path: path)
      puts JSON.pretty_generate(result.summary)
      puts "Report written to #{path}"
    end

    desc "Import lean content entries into the publishing DB (dry-run unless APPLY=1)"
    task import_lean_entries: :environment do
      apply = ENV["APPLY"] == "1"
      path = ENV.fetch("REPORT", "tmp/publishing_migration_import_lean_entries.json")
      result = PublishingMigrationImportLeanEntries.call(apply:, output_path: path)
      puts JSON.pretty_generate(result.summary)
      puts "Report written to #{path}"
    end
  end

  desc "Read-only parity check between the legacy lean tables and the publishing DB for SURFACE=docs|news|help AUDIENCE=app|com|org"
  task shadow_read: :environment do
    surface = ENV.fetch("SURFACE")
    audience = ENV.fetch("AUDIENCE")
    locale = ENV.fetch("LOCALE", "ja")
    result = PublishingShadowReadComparison.call(audience:, surface:, locale:)
    puts JSON.pretty_generate(result.summary)
  end
end
