# frozen_string_literal: true

class CreateClientAccounts < ActiveRecord::Migration[8.2]
  def change
    create_table :client_accounts do |t|
      t.string :public_id, null: false, default: ""
      t.bigint :customer_id, null: false
      t.timestamps

      t.index :public_id, unique: true
      t.index :customer_id, unique: true
    end
  end
end
