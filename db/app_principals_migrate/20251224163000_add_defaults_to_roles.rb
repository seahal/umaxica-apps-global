# frozen_string_literal: true

class AddDefaultsToRoles < ActiveRecord::Migration[8.2]
  def change
    reversible do |dir|
      dir.up do
        change_column_default(:roles, :description, from: nil, to: "")
        up_only { execute("UPDATE roles SET description = '' WHERE description IS NULL") }
      end
      dir.down do
        change_column_default(:roles, :description, from: "", to: nil)
      end
    end
  end
end
