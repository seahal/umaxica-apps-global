# frozen_string_literal: true

class CreateStaffIdentityTelephones < ActiveRecord::Migration[8.0]
  def change
    create_table(:staff_identity_telephones) do |t|
      t.references(:staff, type: :bigint, foreign_key: true)
      t.string(:number)

      t.timestamps
    end
  end
end
