# frozen_string_literal: true

class CreateNotificationTables < ActiveRecord::Migration[8.2]
  def change
    create_table :user_notifications do |t|
      t.string :public_id, null: false, default: ""
      t.bigint :user_id, null: false
      t.timestamps
      t.index :public_id, unique: true
      t.index :user_id
    end

    create_table :staff_notifications do |t|
      t.string :public_id, null: false, default: ""
      t.bigint :staff_id, null: false
      t.timestamps
      t.index :public_id, unique: true
      t.index :staff_id
    end

    create_table :member_notifications do |t|
      t.string :public_id, null: false, default: ""
      t.bigint :user_notification_id, null: false
      t.timestamps
      t.index :public_id, unique: true
      t.index :user_notification_id
    end

    create_table :operator_notifications do |t|
      t.string :public_id, null: false, default: ""
      t.bigint :staff_notification_id, null: false
      t.timestamps
      t.index :public_id, unique: true
      t.index :staff_notification_id
    end

    add_foreign_key :member_notifications, :user_notifications, column: :user_notification_id, on_delete: :cascade, validate: false
    add_foreign_key :operator_notifications, :staff_notifications, column: :staff_notification_id, on_delete: :cascade, validate: false
  end
end
