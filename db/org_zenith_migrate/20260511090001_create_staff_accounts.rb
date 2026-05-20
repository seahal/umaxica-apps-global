# frozen_string_literal: true

class CreateStaffAccounts < ActiveRecord::Migration[8.2]
  def change
    create_table :staff_accounts do |t|
      t.string :public_id, null: false, default: ""
      t.bigint :staff_id, null: false
      t.timestamps

      t.index :public_id, unique: true
      t.index :staff_id, unique: true
    end
  end
end
