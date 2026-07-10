# frozen_string_literal: true

class CreateOperatorEntraIdentities < ActiveRecord::Migration[8.2]
  def change
    create_table(:operator_entra_identities, id: :bigserial) do |t|
      t.string(:public_id, null: false, limit: 21)
      t.bigint(:operator_id, null: false)
      t.bigint(:connection_id, null: false)
      t.string(:entra_tenant_id, null: false, limit: 36)
      t.string(:entra_object_id, null: false, limit: 36)
      t.string(:evidence_issuer, limit: 512)
      t.string(:evidence_subject, limit: 512)
      t.bigint(:status_id, null: false, default: 0)
      t.datetime(:last_authenticated_at)
      t.timestamps null: false

      t.index(:public_id, unique: true)
      t.index(%i(entra_tenant_id entra_object_id), unique: true,
               name: "idx_operator_entra_identities_on_tid_and_oid")
      t.index(:operator_id, unique: true)
      t.index(:connection_id)
      t.index(:status_id)
    end

    add_foreign_key(:operator_entra_identities, :operator_entra_identity_states,
                    column: :status_id, validate: false)
    add_foreign_key(:operator_entra_identities, :organization_entra_connections,
                    column: :connection_id, validate: false)
  end
end
