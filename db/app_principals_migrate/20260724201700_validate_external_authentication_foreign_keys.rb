# frozen_string_literal: true

class ValidateExternalAuthenticationForeignKeys < ActiveRecord::Migration[8.2]
  def change
    validate_foreign_key(:client_apple_credential_revocations, :clients)
    validate_foreign_key(:client_external_identities, :clients)
    validate_foreign_key(:client_apple_identity_credentials, :client_external_identities)
    validate_foreign_key(:client_apple_notification_events, :client_external_identities)
  end
end
