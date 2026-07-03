# frozen_string_literal: true

class CreateClientWithdrawalCeremonies < ActiveRecord::Migration[8.1]
  def change
    create_table :client_withdrawal_ceremonies do |t|
      t.string :public_id, limit: 21, null: false
      t.references :client, null: false, foreign_key: true
      t.string :purpose, null: false
      t.integer :status_id, null: false, default: 1
      t.binary :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.datetime :revoked_at
      t.binary :ip_digest
      t.binary :user_agent_digest
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end

    add_index :client_withdrawal_ceremonies, :public_id, unique: true
    add_index :client_withdrawal_ceremonies, :token_digest, unique: true
    add_index :client_withdrawal_ceremonies, :expires_at
    add_index :client_withdrawal_ceremonies, %i(client_id status_id expires_at)
  end
end
