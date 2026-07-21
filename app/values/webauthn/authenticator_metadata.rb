# typed: false
# frozen_string_literal: true

module Webauthn
  # Maps a verified registration's AuthenticationContext to the display-only
  # authenticator metadata columns shared by all passkey tables. Everything
  # here is self-reported by the client (attestation: "none") - it supports
  # credential inventory display and nothing else. Name resolution failure is
  # expected for unknown AAGUIDs and never fails the ceremony.
  class AuthenticatorMetadata
    COLUMNS = %i(
      aaguid transports backup_eligible backup_state authenticator_attachment provider_name metadata_source
    ).freeze

    # Restricts an untrusted hash (ceremony candidate or decoded result claim)
    # to exactly the metadata columns, so commit paths never mass-assign
    # anything beyond them.
    def self.permit(hash)
      return {} if hash.blank?

      symbolized = hash.symbolize_keys
      COLUMNS.index_with { |column| symbolized[column] }
    end

    def self.attributes_from(context)
      resolution = AuthenticatorNameResolver.resolve(context.aaguid)

      {
        aaguid: context.aaguid,
        transports: context.transports,
        backup_eligible: context.backup_eligible,
        backup_state: context.backup_state,
        authenticator_attachment: context.authenticator_attachment,
        provider_name: resolution&.name,
        metadata_source: resolution&.source,
      }
    end
  end
end
