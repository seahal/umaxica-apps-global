# frozen_string_literal: true

class ValidateEntraForeignKeys < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  FOREIGN_KEYS = [
    [:organization_entra_connections, :organization_entra_connection_states, :status_id],
    [:operator_entra_identities, :operator_entra_identity_states, :status_id],
    [:operator_entra_identities, :organization_entra_connections, :connection_id],
  ].freeze

  def up
    FOREIGN_KEYS.each do |from_table, to_table, column|
      next unless foreign_key_exists?(from_table, to_table, column: column)

      validate_foreign_key(from_table, to_table, column: column)
    end
  end

  def down
    # NOT VALID -> VALID is not meaningfully reversible; intentionally a no-op.
  end
end
