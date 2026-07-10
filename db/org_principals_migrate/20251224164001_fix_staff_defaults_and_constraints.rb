# frozen_string_literal: true

class FixStaffDefaultsAndConstraints < ActiveRecord::Migration[8.2]
  def change
    reversible do |dir|
      dir.up do
        change_table(:role_assignments, bulk: true) do |t|
          t.change_default(:staff_id, from: nil, to: "00000000-0000-0000-0000-000000000000")
          t.change_default(:user_id, from: nil, to: "00000000-0000-0000-0000-000000000000")
        end
      end
      dir.down do
        change_table(:role_assignments, bulk: true) do |t|
          t.change_default(:staff_id, from: "00000000-0000-0000-0000-000000000000", to: nil)
          t.change_default(:user_id, from: "00000000-0000-0000-0000-000000000000", to: nil)
        end
      end
    end
  end
end
