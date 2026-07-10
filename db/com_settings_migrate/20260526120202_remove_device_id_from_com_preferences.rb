# typed: false
# frozen_string_literal: true

class RemoveDeviceIdFromComPreferences < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    remove_index :com_preferences, :device_id, if_exists: true, algorithm: :concurrently
    remove_index :com_preferences, :device_id_digest, if_exists: true, algorithm: :concurrently
    safety_assured { remove_column :com_preferences, :device_id, :string } if column_exists?(:com_preferences, :device_id)
    if column_exists?(:com_preferences, :device_id_digest)
      safety_assured { remove_column :com_preferences, :device_id_digest, :string }
    end
  end

  def down
    add_column :com_preferences, :device_id, :string unless column_exists?(:com_preferences, :device_id)
    add_column :com_preferences, :device_id_digest, :string unless column_exists?(:com_preferences, :device_id_digest)
    add_index :com_preferences, :device_id, algorithm: :concurrently, if_not_exists: true
    add_index :com_preferences, :device_id_digest, algorithm: :concurrently, if_not_exists: true
  end
end
