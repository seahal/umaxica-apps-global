# frozen_string_literal: true

namespace :external_authentication do
  namespace :identity_migration do
    cutover_confirmation =
      lambda do
        next if ENV.fetch("EXTERNAL_AUTHENTICATION_IDENTITY_CUTOVER") == "confirm-one-way-copy"

        raise RuntimeError, <<~MESSAGE
          Refusing to copy external identities. Set EXTERNAL_AUTHENTICATION_IDENTITY_CUTOVER=confirm-one-way-copy
          only after the approved production preflight, backup, dry run, and write-window checks complete.
        MESSAGE
      end

    desc "Read-only preflight for the legacy social identity copy"
    task preflight: :environment do
      report = ExternalAuthenticationLegacyIdentityCopy.preflight!
      puts "preflight_ok apple=#{report.apple_count} google=#{report.google_count}"
    end

    desc "Copy legacy social identities once; requires explicit operator confirmation"
    task copy: :environment do
      cutover_confirmation.call
      report = ExternalAuthenticationLegacyIdentityCopy.call
      puts "copy_ok apple=#{report.apple_count} google=#{report.google_count} copied=#{report.copied_count}"
    end

    desc "Verify the copied social identity bindings without changing data"
    task verify: :environment do
      report = ExternalAuthenticationLegacyIdentityCopy.verify!
      puts "verify_ok apple=#{report.apple_count} google=#{report.google_count}"
    end
  end
end
