# frozen_string_literal: true

class AddLockVersionToUsersAndClients < ActiveRecord::Migration[8.2]
  def change
    %i(users clients).each do |table_name|
      add_column(table_name, :lock_version, :integer, null: false, default: 0)
    end
  end
end
