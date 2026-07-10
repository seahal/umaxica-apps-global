# frozen_string_literal: true

class CreateDivisions < ActiveRecord::Migration[8.2]
  def change
    create_table(:divisions) do |t|
      t.string(:division_status_id, null: false, limit: 255)
      t.bigint(:parent_id)

      t.timestamps
    end

    add_index(:divisions, :division_status_id)
    add_index(:divisions, :parent_id)
    add_index(:divisions, [:parent_id, :division_status_id], unique: true, name: "index_divisions_unique")

    add_foreign_key(:divisions, :division_statuses, validate: false)
  end
end
