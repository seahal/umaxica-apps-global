# frozen_string_literal: true

class AddClientForeignKeyToAppleNotificationEvents < ActiveRecord::Migration[8.2]
  def change
    add_foreign_key(:client_apple_notification_events, :clients, validate: false)
  end
end
