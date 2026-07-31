# frozen_string_literal: true

class RemovePersistedAppleProviderTokens < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      if foreign_key_exists?(:client_apple_notification_events, :client_apple_identities)
        remove_foreign_key(:client_apple_notification_events, :client_apple_identities)
      end
      remove_column(:client_apple_notification_events, :client_apple_identity_id) if
        column_exists?(:client_apple_notification_events, :client_apple_identity_id)
      drop_table(:client_apple_identity_credentials, if_exists: true)
      drop_table(:client_apple_credential_revocations, if_exists: true)
      drop_table(:client_apple_identities, if_exists: true)
      drop_table(:client_google_identities, if_exists: true)
      drop_table(:client_apple_identity_statuses, if_exists: true)
      drop_table(:client_google_identity_statuses, if_exists: true)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "raw provider tokens must not be restored"
  end
end
