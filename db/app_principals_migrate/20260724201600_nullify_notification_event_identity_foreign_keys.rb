# frozen_string_literal: true

class NullifyNotificationEventIdentityForeignKeys < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    replace_foreign_key(:client_external_identity_id, :client_external_identities)
    replace_foreign_key(:client_id, :clients)
    replace_foreign_key(:client_apple_identity_id, :client_apple_identities)
  end

  def down
    replace_foreign_key(:client_external_identity_id, :client_external_identities, on_delete: nil)
    replace_foreign_key(:client_id, :clients, on_delete: nil)
    replace_foreign_key(:client_apple_identity_id, :client_apple_identities, on_delete: nil)
  end

  private

  def replace_foreign_key(column, to_table, on_delete: :nullify)
    remove_foreign_key(:client_apple_notification_events, column: column)
    add_foreign_key(
      :client_apple_notification_events,
      to_table,
      column: column,
      on_delete: on_delete,
      validate: false,
    )
    validate_foreign_key(:client_apple_notification_events, column: column)
  end
end
