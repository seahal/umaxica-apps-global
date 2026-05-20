# frozen_string_literal: true

class AddStatusIdToAdmins < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      change_table(:operators, bulk: true) do |t|
        t.string(:status_id, limit: 255, default: "NEYO", null: false)
      end

      add_index(:operators, :status_id)
      add_foreign_key(:operators, :admin_identity_statuses, column: :status_id, primary_key: :id)
    end
  end

  def down
    remove_foreign_key(:operators, :admin_identity_statuses)
    remove_index(:operators, :status_id)
    change_table(:operators, bulk: true) do |t|
      t.remove(:status_id)
    end
  end
end
