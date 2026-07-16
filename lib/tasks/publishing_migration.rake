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
  end
end
