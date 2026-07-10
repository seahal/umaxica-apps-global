# frozen_string_literal: true

class CreateOrganizationEntraConnections < ActiveRecord::Migration[8.2]
  def change
    create_table(:organization_entra_connections, id: :bigserial) do |t|
      t.string(:public_id, null: false, limit: 21)
      t.bigint(:organization_id, null: false)
      t.string(:entra_tenant_id, null: false, limit: 36)
      t.string(:entra_client_id, null: false, limit: 255)
      t.text(:entra_client_secret, null: false)
      t.bigint(:status_id, null: false, default: 0)
      t.datetime(:last_used_at)
      t.datetime(:revoked_at)
      t.timestamps null: false

      t.index(:public_id, unique: true)
      t.index(%i(organization_id entra_tenant_id), unique: true,
               name: "idx_org_entra_connections_on_org_and_tenant")
      t.index(%i(entra_tenant_id entra_client_id), unique: true,
               name: "idx_org_entra_connections_on_tenant_and_client")
      t.index(:status_id)
    end

    add_foreign_key(:organization_entra_connections, :organization_entra_connection_states,
                    column: :status_id, validate: false)
  end
end
