# frozen_string_literal: true

class ValidateClientForeignKeyOnAppleNotificationEvents < ActiveRecord::Migration[8.2]
  def change
    validate_foreign_key(:client_apple_notification_events, :clients)
  end
end
