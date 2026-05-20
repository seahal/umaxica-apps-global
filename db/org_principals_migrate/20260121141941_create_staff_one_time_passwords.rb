# frozen_string_literal: true

class CreateStaffOneTimePasswords < ActiveRecord::Migration[8.2]
  def change
    create_table(:staff_one_time_passwords) do |t|
      t.references(:staff, null: false, foreign_key: true, type: :bigint)
      t.string(:private_key, limit: 1024, null: false, default: "")
      t.datetime(:last_otp_at, null: false, default: -> { "'-infinity'" })
      t.string(:public_id, limit: 21)
      t.string(:title, limit: 32)
      t.string(:staff_one_time_password_status_id, null: false, default: "NEYO")

      t.timestamps
    end

    add_index(:staff_one_time_passwords, :public_id, unique: true)
    add_index(:staff_one_time_passwords, :staff_one_time_password_status_id)
    add_foreign_key(
      :staff_one_time_passwords, :staff_one_time_password_statuses,
      column: :staff_one_time_password_status_id, primary_key: :id, validate: false,
    )
  end
end
