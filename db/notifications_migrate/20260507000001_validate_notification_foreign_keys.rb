# frozen_string_literal: true

class ValidateNotificationForeignKeys < ActiveRecord::Migration[8.2]
  def change
    validate_foreign_key :member_notifications, :user_notifications, column: :user_notification_id
    validate_foreign_key :operator_notifications, :staff_notifications, column: :staff_notification_id
  end
end
