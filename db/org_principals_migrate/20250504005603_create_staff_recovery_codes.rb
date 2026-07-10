# frozen_string_literal: true

class CreateStaffRecoveryCodes < ActiveRecord::Migration[8.0]
  def change
    create_table(:staff_recovery_codes) do |t|
      t.references(:staff, type: :bigint, null: false, foreign_key: true)
      t.string(:recovery_code_digest)
      t.date(:expires_in)
      t.timestamps
    end
  end
end
