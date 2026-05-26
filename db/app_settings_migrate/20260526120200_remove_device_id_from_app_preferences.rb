# typed: false
# frozen_string_literal: true

class RemoveDeviceIdFromAppPreferences < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    remove_index :app_preferences, :device_id, if_exists: true, algorithm: :concurrently
    remove_index :app_preferences, :device_id_digest, if_exists: true, algorithm: :concurrently
    safety_assured { remove_column :app_preferences, :device_id, :string } if column_exists?(:app_preferences, :device_id)
    if column_exists?(:app_preferences, :device_id_digest)
      safety_assured { remove_column :app_preferences, :device_id_digest, :string }
    end
  end

  def down
    add_column :app_preferences, :device_id, :string unless column_exists?(:app_preferences, :device_id)
    add_column :app_preferences, :device_id_digest, :string unless column_exists?(:app_preferences, :device_id_digest)
    add_index :app_preferences, :device_id, algorithm: :concurrently, if_not_exists: true
    add_index :app_preferences, :device_id_digest, algorithm: :concurrently, if_not_exists: true
  end
end
