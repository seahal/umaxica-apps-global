# frozen_string_literal: true

class ReplaceEntraClientSecretsWithCertificateReferences < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      add_column(:organization_entra_connections, :entra_credential_key, :string)
      execute(<<~SQL.squish)
        UPDATE organization_entra_connections
        SET entra_credential_key = 'ENTRA_CERTIFICATE_' || id
      SQL
      change_column_null(:organization_entra_connections, :entra_credential_key, false)
      remove_column(:organization_entra_connections, :entra_client_secret)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "discarded Entra client secrets cannot be restored"
  end
end
