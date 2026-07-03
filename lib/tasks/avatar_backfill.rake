# frozen_string_literal: true

namespace :avatar_backfill do
  desc "Dry-run audit legacy avatars.client_id rows before binding backfill"
  task audit_legacy_client_bindings: :environment do
    path = ENV.fetch("REPORT", "tmp/avatar_backfill/legacy_client_binding_audit.json")
    result = AvatarBackfill::AuditLegacyClientBindings.call(output_path: path)
    puts JSON.pretty_generate(result.summary)
    puts "Report written to #{path}"
  end

  desc "Backfill unambiguous legacy avatars.client_id bindings. Defaults to dry-run; set APPLY=1 to mutate."
  task legacy_client_bindings: :environment do
    apply = ENV["APPLY"] == "1"
    path = ENV.fetch("REPORT", "tmp/avatar_backfill/legacy_client_binding_backfill.json")
    result = AvatarBackfill::BackfillLegacyClientBindings.call(apply: apply, output_path: path)
    puts JSON.pretty_generate(result.summary)
    puts "Report written to #{path}"
  end
end
