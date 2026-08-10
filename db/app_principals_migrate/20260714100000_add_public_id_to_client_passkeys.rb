# frozen_string_literal: true

class AddPublicIdToClientPasskeys < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_column :client_passkeys, :public_id, :string, limit: 21
    add_index :client_passkeys, :public_id, unique: true, algorithm: :concurrently
  end
end
