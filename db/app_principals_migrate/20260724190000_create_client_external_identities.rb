# frozen_string_literal: true

class CreateClientExternalIdentities < ActiveRecord::Migration[8.2]
  def up
    create_table(:client_external_identities) do |t|
      t.references(:client, null: false, foreign_key: false)
      t.string(:provider, limit: 16, null: false)
      t.string(:issuer, null: false)
      t.text(:subject, null: false)
      t.string(:audience, null: false)
      t.string(:state, limit: 32, null: false, default: "active")
      t.string(:verification_authority, null: false)
      t.datetime(:verified_at, null: false)
      t.datetime(:last_authenticated_at)
      t.timestamps

      t.index(%i(issuer subject), unique: true, name: "idx_client_external_identities_issuer_subject")
      t.index(%i(client_id provider), unique: true, name: "idx_client_external_identities_client_provider")
      t.index(:state)
      t.check_constraint("provider IN ('apple', 'google')", name: "chk_client_external_identities_provider")
      t.check_constraint(
        "state IN ('active', 'consent_revoked', 'account_deleted')",
        name: "chk_client_external_identities_state",
      )
    end

    safety_assured do
      execute("ALTER TABLE client_external_identities SET UNLOGGED")
    end
    add_foreign_key(:client_external_identities, :clients, validate: false)
  end

  def down
    remove_column(:client_external_identities, :last_provider_event_at) if
      column_exists?(:client_external_identities, :last_provider_event_at)
    drop_table(:client_external_identities)
  end
end
