# frozen_string_literal: true

class AddPublicIdToUserPreferences < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_column :user_preferences, :public_id, :string, limit: 21, if_not_exists: true
    add_index :user_preferences, :public_id, unique: true, algorithm: :concurrently, if_not_exists: true
  end
end
