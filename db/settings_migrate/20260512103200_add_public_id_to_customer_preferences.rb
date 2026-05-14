# frozen_string_literal: true

class AddPublicIdToCustomerPreferences < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_column :customer_preferences, :public_id, :string, limit: 21, if_not_exists: true
    add_index :customer_preferences, :public_id, unique: true, algorithm: :concurrently, if_not_exists: true
  end
end
