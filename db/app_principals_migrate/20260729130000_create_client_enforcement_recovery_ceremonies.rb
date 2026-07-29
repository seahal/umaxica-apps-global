# frozen_string_literal: true

class CreateClientEnforcementRecoveryCeremonies < ActiveRecord::Migration[8.2]
  def change
    create_table :client_enforcement_recovery_ceremonies do |t|
      t.string :public_id, limit: 21, null: false
      t.references :client, null: false, foreign_key: true
      t.integer :status_id, null: false, default: 1
      t.binary :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.datetime :revoked_at
      t.binary :ip_digest
      t.binary :user_agent_digest
      t.timestamps
    end

    add_index :client_enforcement_recovery_ceremonies, :public_id, unique: true
    add_index :client_enforcement_recovery_ceremonies, :token_digest, unique: true
    add_index :client_enforcement_recovery_ceremonies, %i(client_id status_id expires_at)
  end
end
