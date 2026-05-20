# frozen_string_literal: true

class CreateComSignalTables < ActiveRecord::Migration[8.2]
  def change
    create_table :visitor_notifications do |t|
      t.string :public_id, null: false, default: ""
      t.bigint :visitor_id, null: false
      t.timestamps
      t.index :public_id, unique: true
      t.index :visitor_id
    end
  end
end
