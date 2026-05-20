# frozen_string_literal: true

class AddStatusIdToClients < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      change_table(:clients, bulk: true) do |t|
        t.string(:status_id, limit: 255, default: "NEYO", null: false)
      end

      add_index(:clients, :status_id)
      add_foreign_key(:clients, :client_identity_statuses, column: :status_id, primary_key: :id)
    end
  end

  def down
    remove_foreign_key(:clients, :client_identity_statuses)
    remove_index(:clients, :status_id)
    change_table(:clients, bulk: true) do |t|
      t.remove(:status_id)
    end
  end
end
