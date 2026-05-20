# frozen_string_literal: true

class CreateUserAccounts < ActiveRecord::Migration[8.2]
  def change
    create_table :user_accounts do |t|
      t.string :public_id, null: false, default: ""
      t.bigint :user_id, null: false
      t.timestamps

      t.index :public_id, unique: true
      t.index :user_id, unique: true
    end
  end
end
